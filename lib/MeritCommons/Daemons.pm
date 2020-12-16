package MeritCommons::Daemons;

# this file includes all daemons fork()'d during the startup() routine

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use POSIX qw(mkfifo nice :sys_wait_h);
use Socket;
use IO::Handle;
use MeritCommons::Infra::FlockVPN;
use Time::HiRes;

use Mojo::Base -base;

has [qw/app iface fvpn/];

# specified in "kill order".
has kinds => sub { return [map { "meritcommons-$_" } qw/publisher notifier system-agent/] };

has services => sub {
    return {
        'meritcommons-publisher' => \&_meritcommons_publisher,
        'meritcommons-notifier' => \&_meritcommons_notifier,
        'meritcommons-system-agent' => \&_meritcommons_system_agent,
    };
};

sub start {
    my ($self, $kind, $run_as_user, $run_as_uid, $nofork) = @_;
    
    unless ($kind) {
        $self->puke("can't call start without specifying 'kind' of daemon e.g. meritcommons-notifier, meritcommons-publisher");
        return;
    }

    if (my $svc_sub = $self->services->{$kind}) {
        if ($nofork) {
            # the subref handles the fork(), it is also responsible for returning its PID.
            return $svc_sub->($self, $run_as_uid, $run_as_user);
        } else {
            # fork here.
            if (my $pid = fork) {
                local $SIG{CHLD} = "IGNORE";
                $self->pid_write($kind, $pid);
                return $pid;
            } else {
                $MeritCommons::is_manager_process = 0;
                $self->{"$kind-started"} = 1;
                $svc_sub->($self, $run_as_uid, $run_as_user);
            }
        }
    } else {
        $self->puke("do not know how to start daemon of kind '$kind'");
        return;
    }
}

sub stop_all {
    my ($self) = @_;
    
    my $stopped;
    foreach my $kind (@{$self->kinds}) {
        if ($self->{"$kind-started"}) {
            if (my $count = $self->stop($kind)) {
                $stopped += $count;
                delete $self->{"$kind-started"};
            }
        }
    }
    
    return $stopped;
}

sub stop {
    my ($self, $kind) = @_;
    
    unless ($kind) {
        $self->puke("can't call stop without specifying 'kind' of daemon e.g. notifier, publisher, system-agent");
        return;
    }
    
    if (my $pid = $self->pid($kind)) {
        kill 'QUIT', $pid;
        
        # be polite and give the process a fifth of a second to exit
        Time::HiRes::sleep(0.2);
        if ($kind eq 'meritcommons-publisher') {
            # cleanup is known to be different for the publisher and its watchdog.  we gotta kill them both.
            my ($pub_pid, $watchdog_pid) = ($self->check_running('meritcommons-publisher'), $self->check_running('meritcommons-pub-watchdog'));
            if ($pub_pid || $watchdog_pid) {
                kill 'KILL', $watchdog_pid, $pub_pid;
            }
            return 1; # publisher counts as 1 even though it's 2.
        } else {
            if (my $test_pid = $self->check_running($kind)) {
                # this should never happen, but just in case..
                if ($pid != $test_pid) {
                    $self->puke("$kind may have been restarted as $test_pid", 'warn');
                    kill 'KILL', $test_pid, $pid;
                    return 2;
                }
                
                # for relaxing times, make it kill -9 time.
                $self->puke("$kind still running as pid $pid", 'warn');
                kill 'KILL', $pid;
            }
        }
        
        return 1;
    }
    
    return 0;
}

sub check_running {
    my ($self, $kind) = @_;

    unless ($kind) {
        $self->puke("can't call check_running without specifying 'kind' of daemon e.g. notifier, publisher, system-agent");
        return;
    }    

    my $running_as;
    
    my @pids = `ps -ef | grep '$kind' | grep -v grep | awk {'print \$2'}`;
    foreach my $pid (@pids) {
        chomp($pid);
        $running_as = $pid if $pid != $$;
    }
    
    return $running_as;
}

sub pid {
    my ($self, $kind) = @_;
 
    unless ($kind) {
        $self->puke("can't call pid without specifying 'kind' of daemon to read the pid for e.g. notifier, publisher, system-agent");
        return;
    }   
 
    open my $fh, '<', "$ENV{MERITCOMMONS_HOME}/../var/log/$kind.pid";
    my $pid = <$fh>;
    close $fh;
    
    unless ($pid) {
        $pid = $self->check_running($kind);
        unless ($pid) {
            $self->puke("can't find PID for $kind in PID file or the process table");
        }
    }
    
    return $pid;
}

# writes pid to $kind.pid pidfile; returns PID written
sub pid_write {
    my ($self, $kind, $pid) = @_;
    
    unless ($kind) {
        $self->puke("can't call pid_write without specifying 'kind' of daemon to write the pid for e.g. notifier, publisher, system-agent");
        return;
    }
    
    $pid = $$ unless $pid;
    
    open my $fh, '>', "$ENV{MERITCOMMONS_HOME}/../var/log/$kind.pid";
    print $fh $pid;
    close $fh;
    
    return $pid;
}

# catch all error printer
sub puke {
    my ($self, $msg, $level) = @_;
    
    $level ||= "error";
    
    if ($ENV{MERITCOMMONS_DEBUG}) {
        print "[debug/daemons] $level - $msg\n";
    }
    
    $self->app->log->$level("daemons - $msg");
}

sub startup {
    my ($self) = @_;

    # get this from the app object so we know what to start the daemons as
    my ($run_as_user, $run_as_uid) = $self->app->running_as_user;

    # these are modular now!
    $MeritCommons::publisher_pid = $self->start('meritcommons-publisher', $run_as_user, $run_as_uid);
    $MeritCommons::notifier_pid = $self->start('meritcommons-notifier', $run_as_user, $run_as_uid);
    $MeritCommons::system_agent_pid = $self->start('meritcommons-system-agent', $run_as_user, $run_as_uid, 1);
}

##
## meritcommons-system-agent
##

sub _meritcommons_system_agent {
    my ($self, $run_as_uid, $run_as_user) = @_;
    
    # before we fork, let's set up bi-directional communication
    my ($agent, $not_agent);
    socketpair($agent, $not_agent, AF_UNIX, SOCK_STREAM, PF_UNSPEC) || die "socketpair: $!";

    $agent->autoflush(1);
    $not_agent->autoflush(1);

    if (my $pid = fork()) {

        # ignore sig chld, we know when these are gonna die.
        local $SIG{CHLD} = "IGNORE";

        # we're not the agent.
        close $agent;

        $self->app->helper(
            agent_write => sub {
                my ($self, $msg) = @_;
                print $not_agent $msg;
            }
        );

        $self->app->helper(
            agent_fh => sub {
                my ($self) = @_;
                return $not_agent;
            }
        );
        
        return $pid;
    } else {

        # Never send a human to do a machine's job.
        # we are the agent, so we can use $agent.
        close $not_agent;

        # we're also not the manager process.
        $MeritCommons::is_manager_process = 0;

        my $log = Mojo::Log->new(path => "$ENV{MERITCOMMONS_HOME}/log/system-agent.log");

        # rename our process for ps -ef views
        $0 = "meritcommons-system-agent";

        # now we switch the uid we run as
        $> = $run_as_uid;

        print "[debug] meritcommons-system-agent started, watching for events (pid: $$)\n" if $ENV{MERITCOMMONS_DEBUG};
        $log->info("meritcommons-system-agent started, watching for events (pid: $$)");

        # now let's set up the subscriber.
        my $zmq_sctx = zmq_init();
        my $zmq_subscriber = zmq_socket($zmq_sctx, ZMQ_SUB);

        # get the filehandle for polling the subscriber
        open my $zmq_subfh, '<&=', zmq_getsockopt($zmq_subscriber, ZMQ_FD);

        # subscribe to all configured publishers
        foreach my $publisher (@{ $self->app->publishers }) {
            next if $publisher =~ /ipc/;    # we don't want our own chatter.
            zmq_connect($zmq_subscriber, $publisher);
        }

        # so we can exit cleanly and expediently
        zmq_setsockopt($zmq_subscriber, ZMQ_LINGER, 0);

        # subscribe to SYSTEM messages
        zmq_setsockopt($zmq_subscriber, ZMQ_SUBSCRIBE, 'SYSTEM');

        # add the Socket and ZeroMQ bus to an IOLoop and watch them.
        my $loop = Mojo::IOLoop->new;

        # load this in our fork.
        require MeritCommons::SystemAgent;

        # instantiate a SystemAgent object with all of our goodies here
        my $sa = MeritCommons::SystemAgent->new(
            socket   => $agent,
            app      => $self->app,
            ioloop   => $loop,
            flockvpn => $self->fvpn,
            iface    => $self->iface,
            subfh    => $zmq_subfh,
        );

        $loop->reactor->io(
            $agent => sub {
                my $r = shift;

                # 64k message limit
                my $input;
                sysread($agent, $input, 65536);

                if ($input) {
                    $sa->handle($input);
                } else {
                    sleep 1;
                }
            }
        )->watch($agent, 1, 0);

        $loop->reactor->io(
            $zmq_subfh => sub {
                my ($reactor) = @_;

                while (zmq_getsockopt($zmq_subscriber, ZMQ_EVENTS) == ZMQ_POLLIN) {

                    # pull out the "address"
                    my $a_msg = zmq_msg_init();
                    zmq_msg_recv($a_msg, $zmq_subscriber);

                    # address at the beginning (should always be SYSTEM)
                    my $address = zmq_msg_data($a_msg);

                    # now the payload
                    my $c_msg = zmq_msg_init();
                    zmq_msg_recv($c_msg, $zmq_subscriber);

                    # just concat it
                    my $content = zmq_msg_data($c_msg);
                    $sa->handle($content);
                }
            }
        )->watch($zmq_subfh, 1, 0);

        local $SIG{INT} = local $SIG{TERM} = 'IGNORE';
        my $quit_received = 0;
        local $SIG{QUIT} = sub {

            # stop the IOLoop.
            $loop->stop if $loop->is_running;

            # say byebye
            print "[debug] meritcommons-system-agent knows when it's not wanted.  (pid: $$)\n" if $ENV{MERITCOMMONS_DEBUG};
            $log->info("meritcommons-system-agent shutting down. (pid: $$)") if $quit_received == 0;
            $quit_received++;

            # clean up ZMQ
            zmq_close($zmq_subscriber);
            zmq_ctx_destroy($zmq_sctx);

            exit 0;
        };

        $loop->start;

        # clean up ZMQ
        zmq_close($zmq_subscriber);
        zmq_ctx_destroy($zmq_sctx);

        print "[debug] meritcommons-system-agent exiting because ioloop stopped.  (pid: $$)\n" if $ENV{MERITCOMMONS_DEBUG};
        $log->info("meritcommons-system-agent shutting down; ioloop stopped. (pid: $$)") if $quit_received == 0;
        exit 0;
    }
}

##
## meritcommons-publisher
##

sub _meritcommons_publisher {
    my ($self, $run_as_uid, $run_as_user) = @_;
    
    # only spin off a publisher if we have this configured.
    if (scalar(@{ $self->app->publishers })) {
        
        my $log = Mojo::Log->new(path => "$ENV{MERITCOMMONS_HOME}/log/publisher.log");

        # now we switch the uid we run as
        $> = $run_as_uid;

        while (1) {
            if (my $worker_pid = fork()) {

                # rename our process for ps -ef views
                $0 = "meritcommons-pub-watchdog";

                # we want to know when our children die.
                local $SIG{CHLD} = "DEFAULT";
                print "[debug] meritcommons-pub-watchdog spawned publisher process $worker_pid (pid: $$)\n"
                  if $ENV{MERITCOMMONS_DEBUG};

                # prevent ctrl c's from affecting us, we only listen to QUIT.
                local $SIG{INT} = local $SIG{TERM} = 'IGNORE';

                local $SIG{QUIT} = sub {
                    print
                      "[debug] meritcommons-pub-watchdog shutting down running publisher and exiting: $worker_pid (pid: $$)\n"
                      if $ENV{MERITCOMMONS_DEBUG};
                    $log->info("[publisher] publisher watchdog shutting down. (pid: $$)");
                    kill("QUIT", $worker_pid);
                    exit;
                };

                waitpid($worker_pid, 0);
            } else {

                # rename our process for ps -ef views
                $0 = "meritcommons-publisher";

                # where to store our ZMQ handles..
                my @zmqh;

                # Prepare our context and publisher
                my $context = zmq_init();
                my $publisher = zmq_socket($context, ZMQ_PUB);

                # larger send buffer
                zmq_setsockopt($publisher, ZMQ_SNDBUF, 65536);

                my @publishers_on;
                my $ctx = zmq_init();
                foreach my $publish_to (@{ $self->app->publish_to }) {
                    my $pub = zmq_socket($ctx, ZMQ_PUB);

                    if ($publish_to =~ /^epgm/) {
                        zmq_setsockopt($publisher, ZMQ_SNDBUF, 65536);
                        zmq_setsockopt($publisher, ZMQ_RATE,   10240);
                    } elsif ($publish_to =~ /^tcp/) {
                        zmq_setsockopt($publisher, ZMQ_SNDBUF, 65536);
                    }

                    my $errno = zmq_bind($pub, $publish_to);
                    if ($errno == 0) {

                        # these publishers are all set and initialized
                        push(@publishers_on, $publish_to);
                        push(@zmqh, { pub => $pub });
                    } else {
                        $log->error("error running zmq_bind to $publish_to: $!, " . zmq_strerror($errno));
                    }
                }

                print "[debug] meritcommons-publisher started on " . join(', ', @publishers_on) . " (pid: $$)\n"
                  if $ENV{MERITCOMMONS_DEBUG};
                $log->info("meritcommons-publisher started on " . join(', ', @publishers_on) . " (pid: $$)");

                # make it so this process has a higher priority.
                nice(-500);

                # prevent ctrl c's from affecting us, we only listen to QUIT.
                local $SIG{INT} = local $SIG{TERM} = 'IGNORE';

                my $quit_received = 0;
                local $SIG{QUIT} = sub {
                    print "[debug] meritcommons-publisher knows when it's not wanted.  (pid: $$)\n"
                      if $ENV{MERITCOMMONS_DEBUG};
                    foreach my $h (@zmqh) {
                        zmq_setsockopt($h->{pub}, ZMQ_LINGER, 0);
                        zmq_close($h->{pub});
                    }

                    zmq_term($ctx);

                    $log->info("[publisher] publisher shutting down. (pid: $$)") if $quit_received == 0;
                    $quit_received++;
                    exit 0;
                };

                local $SIG{ABRT} = sub {
                    $log->fatal("got SIGABRT, I am not long for this world... $!, $$");
                    die "Caught SIGABRT and killed myself.\n";
                };

                while (1) {
                    last unless -p $MeritCommons::publisher_fifo_path;

                    open my $pub_fh, '<', $MeritCommons::publisher_fifo_path
                      or sleep 1 && exit;

                    while (my $line = <$pub_fh>) {
                        if ($line eq "die.\n") {
                            print
                              "[debug] meritcommons-publisher knows when it's not wanted.  Shutting down... (pid: $$)\n"
                              if $ENV{MERITCOMMONS_DEBUG};
                            exit;
                        }

                        my ($stream_id, $content_id) = $line =~ /^([\w-]+)\s+(.+)$/;

                        # send to all the publishers we have...
                        foreach my $publisher (map { $_->{pub} } @zmqh) {
                            zmq_msg_send($stream_id, $publisher, ZMQ_SNDMORE);
                            zmq_msg_send($content_id, $publisher);
                        }
                    }
                    close $pub_fh;
                }

                exit 0;
            }
        }
    }
}

##
## meritcommons-notifier
##

sub _meritcommons_notifier {
    my ($self, $run_as_uid, $run_as_user) = @_;        

    my $log = Mojo::Log->new(path => "$ENV{MERITCOMMONS_HOME}/log/notifier.log");

    # Prevent ctrl-c's from affecting us, only listen to SIGQUIT
    local $SIG{INT} = local $SIG{TERM} = 'IGNORE';

    my $quit_received = 0;
    local $SIG{QUIT} = sub {
        print "[debug] meritcommons-notifier knows when it's not wanted.  (pid: $$)\n" if $ENV{MERITCOMMONS_DEBUG};
        $log->info("meritcommons-notifier shutting down. (pid: $$)") if $quit_received == 0;
        $quit_received++;
        exit 0;
    };

    # rename our process for ps -ef views
    $0 = "meritcommons-notifier";

    # now we switch the uid we run as
    $> = $run_as_uid;

    print "[debug] meritcommons-notifier started, watching for notifications (pid: $$)\n" if $ENV{MERITCOMMONS_DEBUG};
    $log->info("meritcommons-notifier started, watching for notifications (pid: $$)");

    # make it so this process has a lower priority.
    nice(1000);

    require MeritCommons::Notifier;

    # reconnect to the database (we closed the socket above)
    while (1) {
        my $i = 0;
        last unless -p $MeritCommons::notifier_fifo_path;

        open my $notifier_fh, '<', $MeritCommons::notifier_fifo_path
          or sleep 1 && exit;
        while (my $line = <$notifier_fh>) {
            $i++;
            if ($line eq "die.\n") {
                print "[debug] meritcommons-notifier knows when it's not wanted.  Shutting down... (pid: $$)\n"
                  if $ENV{MERITCOMMONS_DEBUG};
                exit;
            } else {
                eval {
                    my $notifier = MeritCommons::Notifier->new($self->app, $line);
                    $notifier->send_notifications;
                };
                if (my $error = $@) {
                    $log->error("[notifier] ugly ugly stuff happened: $error INPUT '$line'");
                }
            }
        }

        print "[fifo debug] $i notifier events processed\n" if $i && $ENV{MERITCOMMONS_FIFO_DEBUG};
        close($notifier_fh);
    }

    exit 0;    
}

1;
