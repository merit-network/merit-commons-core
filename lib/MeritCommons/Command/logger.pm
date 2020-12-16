#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::logger;

use Mojo::IOLoop;
use Mojo::Base 'Mojolicious::Command';
use File::Find;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Mojo::EventEmitter;
use Getopt::Long 'GetOptions';
use IO::Handle;
use Class::Accessor;
use POSIX qw/tzset strftime/;
use Date::Parse qw/str2time/;
use File::Path qw/make_path/;
use Log::Syslog::Fast ':all';

our @ISA;
push(@ISA, 'Mojo::EventEmitter');
push(@ISA, 'Class::Accessor');

has description => "Write live log data from the flock to log files!\n";
has usage       => "Usage: $0 logger (options)\n";

has hint => <<EOF;

These options are available for logger:
    -e, --noelb             Filter out "ELB-HealthChecker/1.0" messages
    -d, --daemonize         Daemonize the process
    -s, --stop              Stop an already daemonized logger
    -z, --timezone          What timezone to write the logs as

EOF

__PACKAGE__->mk_accessors(qw/handles basedir/);

sub run {
    my ($self, @args) = @_;

    my ($noelb, $daemonize, $stop, $timezone, $basedir);

    GetOptions(
        "e|noelb"      => \$noelb,
        "d|daemonize"  => \$daemonize,
        "s|stop"       => \$stop,
        "z|timezone=s" => \$timezone,
        "b|basedir=s"  => \$basedir,
    );

    $self->{basedir} = $basedir ? $basedir : "/usr/local/meritcommons/var/log";

    my $logger_running_as;

    # detect if another instance of ourself is running.
    my @other_pids = `ps -ef | grep 'meritcommons_logger' | grep -v grep | awk {'print \$2'}`;
    if (scalar(@other_pids) >= 1) {
        foreach my $op (@other_pids) {
            chomp($op);
            $logger_running_as = $op if $op != $$;
        }
    }

    $self->{pid_file} = "$ENV{MERITCOMMONS_HOME}/log/logger.pid";

    if ($stop) {
        my $pf_pid;
        if (open my $pf, '<', $self->{pid_file}) {
            $pf_pid = <$pf>;
            close $pf;
        }

        # we don't need this any more, it'll only confuse us.
        unlink($self->{pid_file});

        if ($pf_pid || $logger_running_as) {
            if ($pf_pid == $logger_running_as) {
                print "MeritCommons Logger stopped (PID: $pf_pid)\n";
                kill(2, $pf_pid);
                exit 0;
            } else {
                if ($logger_running_as) {
                    print "MeritCommons Logger stopped (PID: $logger_running_as); (NO PID FILE)\n";
                    kill(2, $logger_running_as);
                    exit 0;
                }
            }
        }
        print "MeritCommons Logger is not running.\n";
        exit 0;
    }

    if ($daemonize) {

        # see if we're already running
        if ($logger_running_as) {
            die "[fatal]: MeritCommons Logger already running as $logger_running_as; try --stop first.\n";
        } else {
            if (my $pid = fork()) {
                local $SIG{CHLD} = "IGNORE";
                open my $pf, '>', $self->{pid_file};
                print $pf "$pid";
                close $pf;
                print "MeritCommons Logger started (PID: $pid)\n";
                exit 0;
            } else {
                $0 = "meritcommons_logger";
            }
        }
    }

    if ($timezone) {
        $ENV{TZ} = $timezone;
        tzset;
    }

    # store our log file handles here
    $self->{handles} = {};

    # what time did we start running?
    $self->{start_time} = time;

    # now let's set up the subscriber.
    $self->{zmq_sctx} = zmq_init();
    $self->{zmq_subscriber} = zmq_socket($self->{zmq_sctx}, ZMQ_SUB);

    # get the filehandle for polling the subscriber
    open my $fh, '<&=', zmq_getsockopt($self->{zmq_subscriber}, ZMQ_FD);
    $self->{zmq_subfh} = $fh;

    # subscribe to all configured publishers
    foreach my $publisher (@{ $self->app->publishers }) {
        zmq_connect($self->{zmq_subscriber}, $publisher);
    }

    # subscribe to SYSTEM messages
    zmq_setsockopt($self->{zmq_subscriber}, ZMQ_SUBSCRIBE, 'LOG');

    local $SIG{INT} = sub {
        $self->shutdown;
        exit();
    };

    my $loop = Mojo::IOLoop->new;

    $loop->reactor->io(
        $self->{zmq_subfh} => sub {
            my ($reactor) = @_;

            while (zmq_getsockopt($self->{zmq_subscriber}, ZMQ_EVENTS) == ZMQ_POLLIN) {

                # pull out the "address"
                my $a_msg = zmq_msg_init();
                zmq_msg_recv($a_msg, $self->{zmq_subscriber});

                # address at the beginning (should always be SYSTEM)
                my $address = zmq_msg_data($a_msg);

                # now the payload
                my $c_msg = zmq_msg_init();
                zmq_msg_recv($c_msg, $self->{zmq_subscriber});

                # just concat it
                my $content = zmq_msg_data($c_msg);

                if ($noelb) {
                    unless ($content =~ /ELB-HealthChecker\/1.0/) {
                        $self->process_log($content);
                    }
                } else {
                    $self->process_log($content);
                }
            }
        }
    )->watch($self->{zmq_subfh}, 1, 0);

    $loop->start;
}

sub process_log {
    my ($self, $content) = @_;

    # get instance + trim up the front
    my ($log_type, $instance);
    ($log_type, $instance, $content) = split(/\s+/, $content, 3);

    # extract time.
    my ($utc_time_string) = $content =~ /\[(\d*\/\w{3}\/[^\]]+)\]/;
    my $unix_timestamp = str2time($utc_time_string);
    my $local_time_string = strftime("%d/%b/%Y:%H:%M:%S %z", localtime($unix_timestamp));

    $content =~ s/\Q$utc_time_string\E/$local_time_string/g;

    # determine where we're gonna put this...
    foreach my $handle ($self->get_handles($log_type, $instance, $unix_timestamp)) {
        print $handle "$content\n";
    }

    # do we have syslog configured, if so, distribute this to the syslog targets?
    if (my $hr = $self->app->config->{syslog}) {
        if (my $targets = $hr->{$log_type}) {
            for (my $i = 0 ; $i < scalar @$targets ; $i++) {
                my $logger;

                # get the cached logger or make a new one!
                unless ($logger =
                    ref $self->{sysloggers}->{$log_type} eq "ARRAY" && $self->{sysloggers}->{$log_type}->[$i]) {
                    $logger = $self->{sysloggers}->{$log_type}->[$i] =
                      Log::Syslog::Fast->new(LOG_UDP, $targets->[$i], 514, LOG_LOCAL1, LOG_NOTICE,
                        $self->app->config->{front_door_host}, $log_type);
                }

                $logger->send($content, $unix_timestamp);
            }
        }
    }
}

sub get_handles {
    my ($self, $log_type, $instance_id, $unix_timestamp) = @_;

    # set up directory hierarchy
    my @tc = localtime($unix_timestamp);
    my $basedir = $self->basedir . sprintf("/%d/%02d", $tc[5] + 1900, $tc[4] + 1);
    make_path($basedir);

    # change log_type to something reasonable
    if ($log_type eq "ACCESS_LOG") {
        $log_type = "access";
    } elsif ($log_type eq "AUTH_LOG") {
        $log_type = "auth";
    }

    # close old handles... (with a lucky lottery 4 in 100 chance)
    unless (int(rand(100) % 23)) {
        foreach my $file_name (keys %{ $self->handles }) {
            if ($self->handles->{$file_name}->{open_time} < (time - (3600 * 24))) {
                $self->handles->{$file_name}->{handle}->close();
                delete $self->handles->{$file_name};
            }
        }
    }

    my @handles;
    foreach my $kind ('flock', $instance_id) {
        my $file_name = sprintf("%s/%s_%s.log", $basedir, $kind, $log_type);
        if (my $h = $self->handles->{$file_name}->{handle}) {
            if ($h->opened) {
                push(@handles, $h);
                next;
            }
        }
        open my $h, '>>', $file_name;
        $self->handles->{$file_name}->{handle}    = $h;
        $self->handles->{$file_name}->{open_time} = time;

        $h->autoflush(1);
        push(@handles, $h);
    }

    return @handles;
}

sub uptime {
    return time - shift->{start_time};
}

sub shutdown {
    my ($self) = @_;

    # clean up ZMQ
    zmq_setsockopt($self->{zmq_subscriber}, ZMQ_LINGER, 0);
    zmq_close($self->{zmq_subscriber});
    zmq_ctx_destroy($self->{zmq_sctx});

    $self->{shutdown} = 1;
    exit();
}

sub DESTROY {
    my ($self) = @_;
}

1;
