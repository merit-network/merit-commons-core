#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::minion_mp;

use Mojo::Base 'Mojolicious::Command';

use POSIX qw/WNOHANG/;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::IOLoop;
use Minion::Job;

has description => "Multi-process Minion Worker\n";
has usage       => <<EOF;
Usage: $0 minion_mp [OPTIONS]

Please note: minion_mp can only be run along side an already started MeritCommons 
application server.

These options are available for minion_mp:
    -d, --daemonize         Daemonize minion_mp
    -s, --stop              Stop an already daemonized minion_mp
    -j, --jobs              How many Minion jobs to dispatch and run in parallel.
    -m, --mode              What mode to run minion_mp in (e.g. development, 
                            production)

EOF

no strict 'refs';
no warnings;

sub run {
    my ($self, @args) = @_;

    # check the config file in 2 places, defaulting to 5 workers.
    my $jobs = ref($self->app->config->{minion}) eq "HASH" ? $self->app->config->{minion}->{mp_workers} : 
        $self->app->config('minion_mp_workers') ? $self->app->config('minion_mp_workers') : 5;

    # pull these in...
    my ($daemonize, $stop, $mode, $quiet);

    GetOptionsFromArray(
        \@args,
        "j|jobs=s"    => \$jobs,
        "d|daemonize" => \$daemonize,
        "s|stop"      => \$stop,
        "q|quiet"     => \$quiet,
    );

    my $minion_mp_running_as;

    # detect if another instance of ourself is running.
    my @other_pids = `ps -ef | grep 'async_master' | grep -v grep | awk {'print \$2'}`;
    if (scalar(@other_pids) >= 1) {
        foreach my $op (@other_pids) {
            chomp($op);
            $minion_mp_running_as = $op if $op != $$;
        }
    }

    $self->{pid_file} = "$ENV{MERITCOMMONS_HOME}/log/minion_mp.pid";

    if ($stop) {
        my $pf_pid;
        if (open my $pf, '<', $self->{pid_file}) {
            $pf_pid = <$pf>;
            close $pf;
        }

        # we don't need this any more, it'll only confuse us.
        unlink($self->{pid_file});

        if ($pf_pid || $minion_mp_running_as) {
            if ($pf_pid == $minion_mp_running_as) {
                print "MeritCommons Async Job Processor stopped (PID: $pf_pid)\n" unless $quiet;
                kill(2, $pf_pid);
                exit 0;
            } else {
                if ($minion_mp_running_as) {
                    print "MeritCommons Async Job Processor stopped (PID: $minion_mp_running_as); (NO PID FILE)\n" unless $quiet;
                    kill(2, $minion_mp_running_as);
                    exit 0;
                }
            }
        }
        print "MeritCommons Async Job Processor is not running.\n" unless $quiet;
        exit 0;
    }

    if ($daemonize) {

        # see if we're already running
        if ($minion_mp_running_as) {
            die "[fatal]: minion_mp already running as $minion_mp_running_as; try --stop first.\n";
        } else {
            if (my $pid = fork()) {
                open my $pf, '>', $self->{pid_file};
                print $pf "$pid";
                close $pf;
                print "MeritCommons Async Job Processor started (Concurrency: $jobs; PID: $pid)\n" unless $quiet;
                exit 0;
            }
        }
    }

    $self->app->log->info("MeritCommons Async Job Processor $$ startup");

    local $SIG{INT} = local $SIG{TERM} = sub { $self->{finished}++ };

    my $app    = $self->app;
    my $minion = $app->minion;

    # set this to something more reasonable
    $minion->remove_after(3600);

    $self->{minion_mp_processes} = {};

    local $SIG{CHLD} = sub {
        while ((my $pid = waitpid -1, WNOHANG) > 0) {
            $self->{minion_mp_processes}->{$pid}->{done}        = 1;
            $self->{minion_mp_processes}->{$pid}->{exit_status} = $?;
        }
    };

    $0 = "async_master";

    while (!$self->{finished}) {
        if (($self->{next} // 0) <= time) {
            $self->{next} = time + $minion->remove_after;

            $app->log->debug('Checking worker registry and job queue.');
            $minion->repair;
        }

        if (scalar(keys %{ $self->{minion_mp_processes} }) < $jobs) {
            my $worker     = $minion->worker->register;
            my $start_time = Time::HiRes::time;
            my $job        = $worker->dequeue(0.5);

            if ($job) {
                if (my $pid = fork) {
                    $self->{minion_mp_processes}->{$pid}->{worker} = $worker;
                    $self->{minion_mp_processes}->{$pid}->{job}    = $job;
                    warn "[async_master] spawned new worker, $pid (" .
                      scalar(keys %{ $self->{minion_mp_processes} }) . " of $jobs processes running)\n"
                      if $ENV{MERITCOMMONS_DEBUG};
                } else {
                    local $SIG{CHLD};
                    $0 = "async_worker";
                    Mojo::IOLoop->reset;
                    $job->perform;

                    # never should have gotten here.
                    exit 0;
                }
            } else {
                $worker->unregister;
            }
        } else {
            warn "[async_master] not considering new work, " .
              scalar(keys %{ $self->{minion_mp_processes} }) . " of $jobs processes running.\n"
              if $ENV{MERITCOMMONS_DEBUG};
            warn "[async_master] worker pids currently out: " .
              join(', ', keys %{ $self->{minion_mp_processes} }) . "\n"
              if $ENV{MERITCOMMONS_DEBUG};
            $self->app->log->info("async_master not considering new work, " .
                  scalar(keys %{ $self->{minion_mp_processes} }) . " of $jobs processes running.");
            sleep 1;
        }

        # cleanup done jobs!
        foreach my $pid (keys %{ $self->{minion_mp_processes} }) {
            if ($self->{minion_mp_processes}->{$pid}->{done}) {
                my $process = delete $self->{minion_mp_processes}->{$pid};

                my $worker      = $process->{worker};
                my $job         = $process->{job};
                my $exit_status = $process->{exit_status};

                $self->app->log->debug(
                    "async_master reaping process $pid, for task '@{[$job->task]}', exit_status: $exit_status");
                $exit_status ? $job->fail('Non-zero exit status') : $job->finish;
                $worker->unregister;
            }
        }
    }

    warn "[async_master] MeritCommons Async Job Processor $$ exiting\n" if $ENV{MERITCOMMONS_DEBUG};
    $self->app->log->info("MeritCommons Async Job Processor $$ shutdown");
}

1;
