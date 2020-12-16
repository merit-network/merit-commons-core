#    MeritCommons Portal
#    Copyright 2014-2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::aws_flock_coordinator;

use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::IOLoop;
use Mojo::Base 'Mojolicious::Command';
use MeritCommons::Infra::FlockVPN;
use File::Find;
use Cwd 'abs_path';
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Storable qw(freeze thaw dclone);
use Mojo::EventEmitter;
use IO::Interface;
use IO::Socket::UNIX;
use WebService::Amazon::Route53;
use VM::EC2;
use Class::Accessor;
use Time::HiRes;
use Data::Dumper;
use Date::Parse;

our @ISA;
push(@ISA, 'Mojo::EventEmitter');
push(@ISA, 'Class::Accessor');

__PACKAGE__->mk_accessors(
    qw/
      ec2                 start_time          fvpn                    zmq_publisher
      zmq_subscriber      scale_state         running_instances       bootstrapping_instances
      scale_floor         state_change        previous_state_change   sock_path
      local_socket        ioloop              r53                     stopped
      log                 pid_file            zmq_sctx                zmq_pctx
      /
);

has description => "MeritCommons Flock (cluster) coordinator process for Amazon Web Services\n";
has usage       => "Usage: $0 aws_flock_coordinator (start|stop)\n";

sub run {
    my ($self, @args) = @_;

    unless ($args[0]) {
        die $self->usage;
    }

    my $coordinator_running_as;

    # detect if another instance of ourself is running.
    my @other_pids = `ps -ef | grep 'meritcommons aws_flock_coordinator' | grep -v grep | awk {'print \$2'}`;
    if (scalar(@other_pids) > 1) {
        foreach my $op (@other_pids) {
            chomp($op);
            $coordinator_running_as = $op if $op != $$;
        }
    }

    $self->{pid_file} = "$ENV{MERITCOMMONS_HOME}/../var/log/aws_flock_coordinator.pid";

    if ($args[0] =~ /^start$/i) {
        if ($coordinator_running_as) {
            die "[fatal]: coordinator already running as $coordinator_running_as; try 'stop' first.\n";
        } else {

            # daemonize right quick...
            if (my $pid = fork()) {
                local $SIG{CHLD} = "IGNORE";
                open my $pf, '>', $self->{pid_file};
                print $pf "$pid";
                close $pf;
                print "MeritCommons AWS Flock Coordinator started (AMI: @{[$self->app->config->{flock_aws_ami}]}; PID: $pid)\n";

                # make sure we don't run shutdown()
                $self->{shutdown} = 1;
                exit 0;
            }
        }
    } elsif ($args[0] =~ /^stop$/i) {
        my $pf_pid;
        if (open my $pf, '<', $self->{pid_file}) {
            $pf_pid = <$pf>;
            close $pf;
        }
        unlink($self->{pid_file});
        if ($pf_pid || $coordinator_running_as) {
            if ($pf_pid == $coordinator_running_as) {
                print "MeritCommons AWS Flock Coordinator stopped (AMI: @{[$self->app->config->{flock_aws_ami}]}; PID: $pf_pid)\n";
                kill(2, $pf_pid);

                # make sure we don't run shutdown()
                $self->{shutdown} = 1;
                exit 0;
            } else {
                if ($coordinator_running_as) {
                    print "MeritCommons AWS Flock Coordinator stopped (PID: $coordinator_running_as); (NO PID FILE)\n";
                    kill(2, $coordinator_running_as);

                    # make sure we don't run shutdown()
                    $self->{shutdown} = 1;
                    exit 0;
                } else {
                    print "MeritCommons AWS Flock Coordinator is not running.\n";
                    $self->{shutdown} = 1;
                    exit 0;
                }
            }
        }
        print "MeritCommons AWS Flock Coordinator is not running.\n";
        $self->{shutdown} = 1;
        exit 0;
    } elsif ($args[0] =~ /^restart$/i) {

        # stop copypasta minus exits + reports
        my $pf_pid;
        if (open my $pf, '<', $self->{pid_file}) {
            $pf_pid = <$pf>;
            close $pf;
        }
        if ($pf_pid || $coordinator_running_as) {
            if ($pf_pid == $coordinator_running_as) {
                kill(2, $pf_pid);

                # make sure we don't run shutdown()
                $self->{shutdown} = 1;
            } else {
                kill(2, $coordinator_running_as);
            }
        }

        # start copypasta
        # daemonize right quick...
        if (my $pid = fork()) {
            local $SIG{CHLD} = "IGNORE";
            open my $pf, '>', $self->{pid_file};
            print $pf "$pid";
            close $pf;
            print "MeritCommons AWS Flock Coordinator restarted (PID: $pid)\n";

            # make sure we don't run shutdown()
            $self->{shutdown} = 1;
            exit 0;
        }
    }

    # log, since we're going to daemonize
    $self->{log} = Mojo::Log->new(path => "$ENV{MERITCOMMONS_HOME}/../var/log/aws_flock_coordinator.log", level => 'info');

    # clear old socket
    if (-e $self->app->config->{flock_coordinator_socket_path}) {
        unlink($self->app->config->{flock_coordinator_socket_path});
    }

    # Please make sure you've set EC2_ACCESS_KEY and EC2_SECRET_KEY accordingly in your environment.
    $self->{ec2} = VM::EC2->new(-region => $self->app->config('flock_aws_region'),);

    $self->{r53} = WebService::Amazon::Route53->new(
        id  => $ENV{EC2_ACCESS_KEY},
        key => $ENV{EC2_SECRET_KEY},
    );

    # what time did we start running?
    $self->{start_time} = time;

    # these are empty hashrefs at startup
    $self->{running_instances}       = {};
    $self->{bootstrapping_instances} = {};

    # unless adjusted, the floor is 0.
    $self->{scale_floor} = 0;

    if ($self->app->config('flock_coordinator')) {
        if ($self->app->config('flock_vpn')) {

            #
            # FLOCKVPN SETUP
            #

            $self->{fvpn} = MeritCommons::Infra::FlockVPN->new($self->app);

            $self->{fvpn}->start_supernode();

            my $iface = $self->{fvpn}->start_edge();

            if ($iface) {

                # start dhcp..
                warn "[debug] starting dhcpd on $iface\n" if $ENV{MERITCOMMONS_DEBUG};
                $self->{fvpn}->start_dhcpd;
            }
            $self->{fvpn}->setup_routes;

            local $SIG{INT} = sub {
                $self->shutdown;
                exit();
            };

            #
            # FLOCK HANDLERS
            #

            $self->on(NODE_HELLO                    => \&_NODE_HELLO);
            $self->on(NODE_BOOTSTRAP                => \&_NODE_BOOTSTRAP);
            $self->on(NODE_LOAD                     => \&_NODE_LOAD);
            $self->on(NODE_CPU                      => \&_NODE_CPU);
            $self->on(NODE_PONG                     => \&_NODE_PONG);
            $self->on(NODE_WEBSOCKET_CLIENTS        => \&_NODE_WEBSOCKET_CLIENTS);
            $self->on(NODE_ESTABLISHED_HTTP_SOCKETS => \&_NODE_ESTABLISHED_HTTP_SOCKETS);

            #
            # COMMAND HANDLERS
            #

            $self->on(start      => \&_start);
            $self->on(stop       => \&_stop);
            $self->on(status     => \&_status);
            $self->on(update     => \&_update);
            $self->on(watch_file => \&_watch_file);

            #
            # EVENT HANDLERS
            #

            $self->on(state_change_complete => \&_state_change_complete);

            #
            # ZMQ SETUP
            #

            # maybe collapse the following several lines into this and move this setup elsewhere
            #my $sps = MeritCommons::Infra::SysPubSub->new($self, sub {
            #    my ($self, $content) = @_;
            #    $self->handle_system_messages($content);
            #});

            # set up publisher
            $self->{zmq_pctx} = zmq_init();
            $self->{zmq_publisher} = zmq_socket($self->{zmq_pctx}, ZMQ_PUB);

            # add all configured destinations
            foreach my $publish_to (@{ $self->app->publish_to }) {
                next if $publish_to =~ /ipc/;    # we don't want our own chatter.
                zmq_bind($self->{zmq_publisher}, $publish_to);
            }

            # increase the send buffer size of the publisher
            zmq_setsockopt($self->{zmq_publisher}, ZMQ_SNDBUF, 65536);

            # now let's set up the subscriber.
            $self->{zmq_sctx} = zmq_init();
            $self->{zmq_subscriber} = zmq_socket($self->{zmq_sctx}, ZMQ_SUB);

            # get the filehandle for polling the subscriber
            open my $fh, '<&=', zmq_getsockopt($self->{zmq_subscriber}, ZMQ_FD);
            $self->{zmq_subfh} = $fh;

            # subscribe to all configured publishers
            foreach my $publisher (@{ $self->app->publishers }) {
                next if $publisher =~ /ipc/;    # we don't want our own chatter.
                zmq_connect($self->{zmq_subscriber}, $publisher);
            }

            # subscribe to SYSTEM messages
            zmq_setsockopt($self->{zmq_subscriber}, ZMQ_SUBSCRIBE, 'SYSTEM');

            # subscribe to STATS messages
            zmq_setsockopt($self->{zmq_subscriber}, ZMQ_SUBSCRIBE, 'STATS');

            $self->{ioloop} = Mojo::IOLoop->new;

            $self->ioloop->reactor->io(
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

                        # send for dispatch...
                        $self->handle_system_message($content);
                    }
                }
            )->watch($self->{zmq_subfh}, 1, 0);

            #
            # LISTEN TO OUR UNIX SOCKET (it knows what it's talking about)
            #

            if (my $sock_path = $self->app->config('flock_coordinator_socket_path')) {
                $self->{local_socket} = IO::Socket::UNIX->new(
                    Type   => SOCK_STREAM,
                    Local  => $sock_path,
                    Listen => 1,
                );

                unless ($self->{local_socket}) {
                    $self->log->fatal("can't listen for incoming commands on $sock_path: $!");
                    die "[fatal]: can't listen for incoming commands on $sock_path: $!\n";
                }

                $self->ioloop->reactor->io(
                    $self->{local_socket} => sub {
                        my ($reactor) = @_;
                        my $socket = $self->{local_socket}->accept();

                        $self->ioloop->reactor->io(
                            $socket => sub {
                                my ($reactor) = @_;

                                my $data;
                                if (my $read = sysread($socket, $data, 65536)) {

                                    # dispatch!
                                    $self->handle_console_message($data, $socket);
                                } else {

                                    # ready to read and no data?  time to close!
                                    $self->ioloop->reactor->remove($socket);
                                    $socket->close;
                                }
                            }
                        )->watch($socket, 1, 0);
                    }
                )->watch($self->{local_socket}, 1, 0);
            } else {
                $self->log->fatal(
                    "please set flock_coordinator_socket_path to a file in a directory writable by @{[$self->app->config->{username}]}."
                );
                die
                  "[fatal] please set flock_coordinator_socket_path to a file in a directory writable by @{[$self->app->config->{username}]}.\n";
            }

            #
            # TIMERS AND PERIODICS
            #

            # if the supernode went away, this might go unheard
            $self->ioloop->timer(
                5 => sub {
                    my ($loop) = @_;

                    # tell everyone we're here.
                    $self->send_system_message("COORDINATOR_HELLO @{[$self->uptime]}");
                }
            );

            # this will result in an update from all nodes a second time, but we might
            # have missed some if the supernode had gone away (box crash, etc), so just
            # to be on the safe side...
            $self->ioloop->timer(
                300 => sub {
                    my ($loop) = @_;

                    # tell everyone we're here, again, 5 minutes after we started.
                    $self->send_system_message("COORDINATOR_HELLO @{[$self->uptime]}");
                }
            );

            # Try and figure out the current state of the infrastructure
            if ($self->ascertain_scale_state) {

                # make sure we scale at least to the floor, unless we're in state "stopped"
                if ($self->scale_state < $self->scale_floor) {
                    $self->ioloop->timer(
                        1 => sub {
                            if ($self->stopped && $self->app->config->{flock_autostart}) {
                                $self->scale_to($self->scale_floor, "Autostart Configured");
                            }
                        }
                    );
                }

                $self->log->info(
                    "MeritCommons $MeritCommons::VERSION ($MeritCommons::CODENAME) AWS Flock Coordinator Startup as pid $$");
                $self->log->info("(c) 2014-2019 Wayne State University");
                $self->log->info("detected AWS scale state: @{[$self->state_info->{description}]}.");
                $self->log->info("actively watching for system events.");
                $self->ioloop->start;
            } else {
                $self->log->fatal(
                    "unable to ascertain current AWS scale state; assuming I'm in New Jersey and just killing myself.");
                die
                  "[fatal] unable to ascertain current AWS scale state; assuming I'm in New Jersey and just killing myself.\n";
            }
        } else {
            $self->log->info("flock_coordinator currently only works with FlockVPN");
        }
    } else {
        $self->log->info("flock_coordinator reqires this node be configured with flock_coordinator => 1");
    }
}

sub _state_change_complete {
    my ($self, $sc) = @_;
    $self->log->info("state change complete; ($sc->{from} => $sc->{to})");
}

sub _push_file {
    my ($self, $sock, @args) = @_;
    
    my $help = <<"EOF";

Synopsis: pushes a file from the coordinator to all currently running MeritCommons instances 

Usage: meritcommons flock push_file [OPTIONS] [FILE]

Examples: 
    meritcommons flock push_file -s newconf.conf -d /usr/local/meritcommons/meritcommons/etc/meritcommons.conf
    meritcommons flock push_file var/plugins/saml2/metadata.xml

These options are available for 'flock push_file':
    -s, --source-file       The source file to send, OPTIONAL, defaults to the absolute path of [FILE]
    -d, --destination-file  The absolute path to place the file in on the destination, OPTIONAL, 
                            defaults to the absolute path of [FILE], or if --source-file was specified
                            as a relative path, then the path relative to MERITCOMMONS_HOME, or finally 
                            if --source-file was specified as an absolute path, then this is the same
                            absolute path on the application server.

    If no arguments are used but [FILE] is used instead, the file is pushed from its absolute path on
    the flock coordinator to the same absolute path on the application server.  Paths on the application
    server will be made accordingly if they do not exist.  If [FILE] is a relative path it is considered
    relative to MERITCOMMONS_HOME.

EOF

    GetOptionsFromArray(
        \@args,
        's|source-file=s' => \my $src_file,
        'd|destination-file=s' => \my $dst_file,
    );

    if ($src_file && $src_file =~ /^\//) {
        # case one, source file is an absolute path.
        if ($dst_file) {
            unless ($dst_file =~ /^\//) {
                # dst_file specified, but is not an absolute path.  make it relative to MERITCOMMONS_HOME
                $dst_file = abs_path(join('/', "$ENV{MERITCOMMONS_HOME}", $dst_file));
            }
        } else {
            # destination file wasn't specified, use the source path.
            $dst_file = $src_file;
        }
    }

    $self->{currently_pushing_file} = 1;
    
    $self->on(
        'NODE_FILE_PUSH',
        sub {
            my ($self, $payload) = @_;
            delete $self->{currently_pushing_file};
            my ($id, $instance, $message) = split(/\s+/, $payload, 3);
            print $sock "[$instance]: $message\n";
        }  
    );
}

sub _watch_file {
    my ($self, $sock, @args) = @_;

    my $help = <<"EOF";

Usage: meritcommons flock watch_file [OPTIONS]

Example: meritcommons flock watch_file -i i-273bacf7 -f log/production.log -a ERROR_LOG

These options are available for 'flock watch_file':
    -f, --file              The file to watch/tail.  Can be an absolute or relative path.  Will also 
                            check paths relative to MERITCOMMONS_HOME.  This option is REQUIRED.
    -a, --zmq_address       The ZeroMQ address to publish new lines to. OPTIONAL defaults to WATCHFILE
    -i, --instance          Limit the request to the instance(s) specified. OPTIONAL defaults to all 

EOF

    GetOptionsFromArray(
        \@args,
        'f|file=s'        => \my $file,
        'a|zmq_address=s' => \my $zmq_address,
        'i|instance=s'    => \my @instances,
    );

    if ($file) {
        $zmq_address = 'WATCHFILE' unless $zmq_address;

        $self->{watch_file_response_count} = 0;
        $self->on(
            'NODE_WATCH_FILE',
            sub {
                my ($self, $payload) = @_;
                $self->{watch_file_response_count}++;
                my ($id, $instance, $message) = split(/\s+/, $payload, 3);
                print $sock "[$instance]: $message\n";
            }
        );

        my $check_done;
        $check_done = sub {
            my ($reactor) = @_;
            if ($self->{watch_file_check_tries}++ > 3 ||
                $self->{watch_file_response_count} == scalar keys %{ $self->running_instances }) {

                # clean up after ourselves...
                $self->unsubscribe('NODE_WATCH_FILE');
                $self->ioloop->remove($sock);
                print $sock
                  "[coordinator]: start a ZMQ listener subscribed to the address '$zmq_address' to access your data\n";
                $sock->close;

                # set these back so they dont pollute future runs of this
                $self->{watch_file_response_count} = 0;
                $self->{watch_file_check_tries}    = 0;
            } else {

                # still not done, wait 3 more seconds.
                print $sock
                  "[coordinator]: still haven't heard from all @{[scalar keys %{$self->running_instances}]} running instances yet... waiting.\n";
                $reactor->timer(3 => $check_done);
            }
        };

        # should be done in 3 seconds.
        $self->ioloop->timer(3 => $check_done);

        # issue the command now that our events are all set up...
        $self->send_system_message(
            COORDINATOR_WATCH_FILE => join(' ', $self->app->new_uuid, join(':', $file, $zmq_address, @instances)));
    } else {
        print $sock $help;
        $self->ioloop->remove($sock);
        $sock->close;
    }
}

sub _status {
    my ($self, $sock) = @_;

    if ($self->{stopped}) {
        print $sock "[MeritCommons Flock is DOWN]\n";
    } else {
        print $sock "[MeritCommons Flock is UP]\n";
    }

    print $sock "Current scale state: @{[$self->scale_state]} (@{[$self->state_info->{description}]})\n";
    if (scalar keys %{ $self->running_instances }) {
        print $sock "On-line instances:\n\n";
        printf $sock "%-20s %-14s %-14s %-7s %-7s %-5s %-5s %-8s %-20s\n", "InstanceID", "Hostname", "Load Average",
          "%1mCPU", "%5mCPU", "MAX?", "MIN?", "HTTPConn", "Start Time";
        printf $sock "%-20s %-14s %-14s %-7s %-7s %-5s %-5s %-8s %-20s\n", "-------------------", "--------------",
          "--------------", "------", "------", "----", "----", "--------",
          "------------------------";
        foreach my $instance_id (keys %{ $self->running_instances }) {
            my $si = $self->running_instances->{$instance_id};
            printf $sock "%-20s %-14s %-14s %-7s %-7s %-5s %-5s %-8s %-20s\n", $instance_id,
              substr($si->{hostname}, 0, 14),
              (ref($si->{load_avg}) eq "ARRAY" ? join(' ', @{ $si->{load_avg} }) : "N/A"),
              (ref($si->{cpu}) eq "ARRAY"              ? "$si->{cpu}->[0]%"                         : "N/A"),
              (ref($si->{cpu}) eq "ARRAY"              ? "$si->{cpu}->[1]%"                         : "N/A"),
              ($si->{over_max}                         ? "Yes"                                      : "No"),
              ($si->{below_min}                        ? "Yes"                                      : "No"),
              (defined $si->{established_http_sockets} ? $si->{established_http_sockets}            : "N/A"),
              ($si->{launch_time}                      ? scalar(localtime(int($si->{launch_time}))) : "UNKNOWN");
        }
    }

    my $psc = $self->previous_state_change;
    if (ref($psc) eq "HASH") {
        print $sock "\nLast state change: ($psc->{from} => $psc->{to})\n";
        print $sock " reason  : " . $psc->{reason} . "\n";
        print $sock " started : " . scalar(localtime($psc->{started_time})) . "\n";
        print $sock " finished: " . scalar(localtime($psc->{complete_time})) . "\n";
    }

    print $sock "\n";

    $self->ioloop->remove($sock);
    $sock->close;
}

sub _update {
    my ($self, $sock, @nodes) = @_;

    # 0 is the 'default' argument.. so make sure $nodes[0] isn't 0
    if ($nodes[0] == 0) {

        # empty it out then.
        @nodes = ();
    }

    if (my $hr = $self->{state_change}) {
        print $sock "[coordinator]: cannot update; system changing state changing from $hr->{from} to $hr->{to}\n";
        $self->log->info("coordinator refused to update; currently changing state from $hr->{from} to $hr->{to}");
        $self->ioloop->remove($sock);
        $sock->close;
    } else {
        # here we can do the update.
        my $ri;
        if (scalar(@nodes)) {
            my $grep_or = join('|', @nodes);
            $ri = [ grep { /$grep_or/ } keys %{ $self->running_instances } ];
            if (scalar @$ri) {
                print $sock
                  "[coordinator]: found @{[scalar @$ri]} of @{[scalar @nodes]} specified nodes to be running\n";
                print $sock "[coordinator]: updating and replacing nodes @{[join(', ', @$ri)]}\n";
                $self->log->info("flock update - found @{[scalar @$ri]} of @{[scalar @nodes]} specified nodes to be running");
                
            } else {
                print $sock "[coordinator]: couldn't find specified node(s) @{[join(', ', @nodes)]} in running nodes\n";
                $self->log->info("flock update - couldn't find specified node(s) @{[join(', ', @nodes)]} in running nodes");
                $self->ioloop->remove($sock);
                $sock->close;
                return;
            }
        } else {

            # update all of them
            $ri = [ keys %{ $self->running_instances } ];
        }

        print $sock "[coordinator]: starting flock update; " . scalar(@$ri) . " nodes to update\n";
        $self->log->info("starting flock update; @{[scalar @$ri]} nodes to update");

        my $start_time = time;

        # though not technically a state change, we don't want any to happen while we're doing this, this should block it.
        $self->{state_change} = {
            started_time    => time,
            from            => $self->scale_state,
            to              => $self->scale_state,
            reason          => "Flock Update",
            nodes_to_update => scalar(@$ri),
            nodes_updated   => 0,
        };

        # run this every 5 seconds or so, checking if we should replace the next instance
        my $start_replacement;
        $start_replacement = sub {
            my ($reactor) = @_;
            if ($self->{state_change}->{replacing_instance}) {

                # we're busy, wait til the next tick.
                $reactor->timer(5 => $start_replacement);
            } else {

                # we need to kick off a replacement!
                if (my $next_instance = shift(@$ri)) {
                    print $sock "               ... starting and staging replacement for $next_instance\n";
                    $self->log->info("flock update - starting and staging replacement for $next_instance");

                    # set replacing instance (duh)
                    $self->{state_change}->{replacing_instance} = $next_instance;

                    # just make an exact replacement.
                    my $to_replace = $self->lookup_instance($next_instance);
                    my ($instance) = $self->launch_instances($to_replace->instanceType);

                    my $ip;
                    if ($ip = $self->ec2->allocate_address(-vpc => 1)) {
                        my $allocate_ip;
                        $allocate_ip = sub {
                            my ($reactor) = @_;
                            unless ($ip->associate($instance)) {
                                $self->log->debug($self->ec2->error_str . ", retrying in 5s.");

                                # reset the timer if we didn't get it this time.
                                $reactor->timer(5 => $allocate_ip);
                            }
                        };
                        $self->ioloop->timer(15 => $allocate_ip);
                    } else {
                        print $sock
                          "[fatal] cannot update; you might need to ask Amazon support for more Elastic IPs.  Coordinator exiting.  AWS Elastic IP Allocation Error: "
                          . $self->ec2->error_str . "\n";
                        $self->ioloop->remove($sock);
                        $sock->close;
                        $self->log->fatal(
                            "[fatal] cannot update; you might need to ask Amazon support for more Elastic IPs.  AWS Elastic IP Allocation Error: "
                              . $self->ec2->error_str);
                        $self->{state_change}->{failed} = 1;
                        $self->{previous_state_change} = delete $self->{state_change};
                        die
                          "cannot scale; you might need to ask Amazon support for more Elastic IPs.  AWS Elastic IP Allocation Error: "
                          . $self->ec2->error_str . "\n";
                    }

                    if ($ip) {
                        my $hostname = $self->generate_host;
                        $self->add_dns_record($ip->publicIp, $hostname);
                        $instance->add_tags(
                            hostname                                        => $hostname,
                            Name                                            => $hostname,
                            "@{[$self->app->config('flock_aws_node_tag')]}" => 1,
                        );

                        # add the instance to running instances, they'll be running instances soon enough.
                        $self->bootstrapping_instances->{ $instance->instanceId } = {
                            hostname      => $hostname,
                            instance_id   => $instance->instanceId,
                            instance_type => $instance->instance_type,
                            instance_obj  => $instance,
                            launch_time   => Time::HiRes::time,
                        };
                    } else {

                        # IP Allocation Error
                        $self->log->fatal("[fatal] cannot launch replacement for $next_instance.\n");
                    }
                }

                if (scalar(@$ri)) {

                    # there's still more work to do, but this box won't be up for at least 90 seconds.
                    $reactor->timer(90 => $start_replacement);
                }
            }
        };

        # run this every 5 seconds or so, checking if the new instance is up and ready to go
        my $check_started;
        $check_started = sub {
            my ($reactor) = @_;

            # presence of this means we got NODE_HELLO from a launched instance, it must be ours!
            if (my $replacement_instance_id = $self->{state_change}->{replacement_instance}) {

                # we're done one, let the console know, and stop the old instance.
                print $sock "               ... $self->{state_change}->{replacing_instance} replaced by " .
                  "$replacement_instance_id ($self->{state_change}->{nodes_updated} of " .
                  "$self->{state_change}->{nodes_to_update} updated)\n";
                  
                $self->log->info(
                    "flock update - $self->{state_change}->{replacing_instance} replaced by " .
                    "$replacement_instance_id ($self->{state_change}->{nodes_updated} of " .
                    "$self->{state_change}->{nodes_to_update} updated)"
                );

                # stopping instance
                $self->replace_instance(
                    $self->{state_change}->{replacing_instance},
                    $self->{state_change}->{replacement_instance},
                    sub {
                        delete($self->{state_change}->{replacement_instance});
                        delete($self->{state_change}->{replacing_instance});
                        if ($self->{state_change}->{nodes_to_update} == $self->{state_change}->{nodes_updated}) {
                            $self->{state_change}->{check_started_disengaged} = 1;
                            print $sock "               ... flock updated in " . (time - $start_time) . " seconds.\n";
                            $self->log->info("flock update complete; flock updated in @{[time - $start_time]} seconds");
                            $self->{state_change}->{complete_time} = time;
                            $self->{state_change}->{direction}     = 'flat';
                            $self->{previous_state_change}         = delete $self->{state_change};
                            $self->ioloop->remove($sock);
                            $sock->close;
                        } else {

                            # there's more to do, keep going...
                            $reactor->timer(5 => $check_started);
                        }
                    }
                );
            } else {

                # keep checking.
                $reactor->timer(5 => $check_started);
            }
        };

        # let's get this party started!
        $self->ioloop->timer(1 => $start_replacement);

        # this part can wait a bit for, box has to bootstrap start up
        $self->ioloop->timer(90 => $check_started);
    }
}

sub _start {
    my ($self, $sock, $scale_state) = @_;

    if ($self->{stopped}) {
        $self->{stopped} = 0;
        $self->scale_floor($scale_state) if $scale_state != $self->scale_floor;
        $self->scale_to($self->scale_floor, "Administrator Request");
        my $nsi = $self->app->config->{flock_aws_scale_pattern}->[ $self->scale_floor ];
        print $sock "[coordinator]: flock starting up at state @{[$self->scale_floor]} ($nsi->{description})\n";
    } else {
        if ($scale_state != $self->scale_floor) {

            # make this the new floor and scale up.
            my $old_scale_floor = $self->scale_floor;
            $self->scale_floor($scale_state);
            if ($self->scale_state < $self->scale_floor) {
                print $sock "[coordinator]: updated scale_floor $old_scale_floor => $scale_state\n";
                $self->scale_to($self->scale_floor, "Administrator Request");
            } else {
                print $sock "[coordinator]: lowered the floor, if flock is idle enough, it should downsize shortly\n";
            }
        } else {
            print $sock "[coordinator]: flock is already running; in state @{[$self->scale_state]}\n";
        }
    }
    $self->ioloop->remove($sock);
    $sock->close;
}

sub _stop {
    my ($self, $sock) = @_;
    if ($self->{stopped}) {
        my $ri = $self->running_instances;
        if (scalar keys %$ri == 0) {
            print $sock "[coordinator]: flock is already stopped\n";
        } else {
            print $sock "[coordinator]: flock is currently shutting down\n";
        }
    } else {
        $self->scale_to(-1, "Administrator Request");
        print $sock "[coordinator]: initiating flock shutdown\n";

        my $stop_check;
        $stop_check = sub {
            my ($reactor) = @_;
            if (ref($self->state_change) eq "HASH") {
                print $sock "               ...\n";
                $reactor->timer(3 => $stop_check);
            } else {
                print $sock "               ... shutdown complete.\n";
                $reactor->remove($sock);
                $sock->close;
                $self->{stopped} = 1;
            }
        };
        $self->ioloop->timer(3 => $stop_check);
    }
}

sub _NODE_ESTABLISHED_HTTP_SOCKETS {
    my ($self, $data) = @_;
    my ($event_id, $instance_id, $hostname, $count) = split(/\s/, $data);
    my ($state, $is) = $self->find_instance_state($instance_id);
    if ($state eq "running" && $is) {
        $is->{established_http_sockets} = $count;
    } else {
        $self->log->info(
            "[warning]: we got http socket info for an instance we didn't think was 'running' ($instance_id)");
    }
}

sub _NODE_WEBSOCKET_CLIENTS {
    my ($self, $data) = @_;
    my ($event_id, $instance_id, $hostname, @rest) = split(/\s/, $data);
    my ($state, $is) = $self->find_instance_state($instance_id);
    if ($state eq "running" && $is) {
        $is->{websocket_clients} = { map { split /:/ } @rest };
    } else {
        $self->log->info(
            "[warning]: we got websocket client info for an instance we didn't think was 'running' ($instance_id)");
    }
}

sub _NODE_HELLO {
    my ($self, $data) = @_;
    my ($event_id, $instance_id, $hostname, $primary_ip, $flock_ip) = split(/\s/, $data);

    my ($state, $is) = $self->find_instance_state($instance_id);
    if ($state eq "bootstrapping") {
        my $lb = $self->load_balancer;
        $lb->register_instances_with_load_balancer(-instances => $instance_id);

        # this node is now up!
        $self->change_instance_state($instance_id, 'running');

        # give this 30 seconds cool down and to allow the box to pass "healthy" threshold checks from the load balancer
        $self->ioloop->timer(
            30 => sub {
                $is->{start_time} = Time::HiRes::time;
                if ($is->{launch_time}) {
                    $self->log->info(
                        sprintf(
                            "instance %s in service; %.2f seconds from launch",
                            $instance_id, $is->{start_time} - $is->{launch_time}
                        )
                    );
                }

                if ($self->{state_change}->{nodes_to_update}) {

                    # this is an update, not a scale state change
                    $self->{state_change}->{nodes_updated}++;
                    $self->{state_change}->{replacement_instance} = $instance_id;
                } else {
                    $self->{state_change}->{nodes_started}++;
                }
            }
        );
    }
}

sub _NODE_BOOTSTRAP {
    my ($self, $data) = @_;
    my ($event_id, $instance_id, $flock_ip) = split(/\s+/, $data);

    unless ($self->{bootstrapping_instances}->{$instance_id}->{bootstrap_start_time}) {

        # ping this instance via zmq until we have a pong.
        my $ping;
        $ping = sub {
            my ($reactor) = @_;
            unless ($self->{bootstrapping_instances}->{$instance_id}->{pong_time}) {
                $self->{bootstrapping_instances}->{$instance_id}->{ping_time} = Time::HiRes::time;
                $self->send_system_message(COORDINATOR_PING => join(' ', $self->app->new_uuid, $instance_id));
                $reactor->timer(1 => $ping);
            }
        };
        $self->ioloop->timer(0.25 => $ping);
    }

    my $start_bootstrap;
    $start_bootstrap = sub {
        my ($reactor) = @_;
        if ($self->{bootstrapping_instances}->{$instance_id}->{pong_time}) {
            my $is = $self->{bootstrapping_instances}->{$instance_id};

            # make sure we can reach the node via ZMQ...
            if (my $zmq_latency = $is->{zmq_ping_latency}) {
                if (my $time = $self->ping_ip($flock_ip)) {
                    $self->log->info(
                        "bootstrapping instance $instance_id at address $flock_ip (tcp ping: $time; zmq ping: $zmq_latency ms)"
                    );
                    $self->{bootstrapping_instances}->{$instance_id}->{bootstrap_start_time} = time;
                    $self->{bootstrapping_instances}->{$instance_id}->{flock_ip}             = $flock_ip;
                    $self->send_system_message(COORDINATOR_BOOTSTRAP => "$event_id $instance_id $flock_ip STARTED");

                    # this is a blocking operation.
                    $self->configure_and_sync($instance_id);

                    $self->log->info("done bootstrapping instance $instance_id at address $flock_ip");
                    $self->send_system_message(COORDINATOR_BOOTSTRAP => "$event_id $instance_id $flock_ip COMPLETED");
                }
            }
        } else {
            $reactor->timer(5 => $start_bootstrap);
        }
    };
    $self->ioloop->timer(2 => $start_bootstrap);

}

sub _NODE_PONG {
    my ($self,     $data)        = @_;
    my ($event_id, $instance_id) = split(/\s/, $data);
    my ($is,       $is_data)     = $self->find_instance_state($instance_id);
    if ($is) {
        $is_data->{pong_time} = Time::HiRes::time;
        $is_data->{zmq_ping_latency} = sprintf("%.2f", (($is_data->{pong_time} - $is_data->{ping_time}) * 1000));
        $self->log->debug("$instance_id $is_data->{zmq_ping_latency} ms");
    } else {
        $self->log->error("got NODE_PONG, and couldn't find instance state for $instance_id");
    }
}

sub _NODE_CPU {
    my ($self, $data) = @_;

    # pull out the data
    my ($event_id, $instance_id, $hostname, $cpu1m, $cpu5m) = split(/\s/, $data);

    if (exists $self->{running_instances}->{$instance_id}) {
        my $instance = $self->{running_instances}->{$instance_id};
        $instance->{cpu} = [ $cpu1m, $cpu5m ];

        if ((!$self->app->config('flock_scale_on')) || ($self->app->config('flock_scale_on') eq "NODE_CPU")) {
            my $max_cpu = $self->state_info->{"max_cpu"};
            my $min_cpu = $self->state_info->{"min_cpu"};

            if (ref($max_cpu) && ($max_cpu->[0] < $cpu1m || $max_cpu->[1] < $cpu5m)) {
                $instance->{over_max}  = 1;
                $instance->{below_min} = 0;
            } elsif (ref($min_cpu) && ($min_cpu->[0] > $cpu1m || $min_cpu->[1] > $cpu5m)) {
                $instance->{below_min} = 1;
                $instance->{over_max}  = 0;
            } else {
                $instance->{over_max}  = 0;
                $instance->{below_min} = 0;
            }
        }
    } else {
        $self->log->debug("we just got CPU information for a node we didn't know was running: $instance_id");
    }

    # this does the actual scaling, which we'll only do if we're configured to scale on NODE_CPU
    if ((!$self->app->config('flock_scale_on')) || ($self->app->config('flock_scale_on') eq "NODE_CPU")) {
        my $maxed_out = 0;
        foreach my $instance (values %{ $self->{running_instances} }) {
            if ($instance->{over_max}) {
                $maxed_out++;
            }
        }

        my $minned_out = 0;
        foreach my $instance (values %{ $self->{running_instances} }) {
            if ($instance->{below_min}) {
                $minned_out++;
            }
        }

        # determine if we're currently in a state change.
        my $sc;
        if (ref($self->state_change) eq "HASH") {
            $sc = $self->state_change;
        }

        # get the previous state change if it exists.
        my $psc;
        if (ref($self->previous_state_change) eq "HASH") {
            $psc = $self->previous_state_change;
        }

        # don't change state if we're already in a state change.
        unless ($sc) {

            # if all boxes are maxed out, it's time to scale up. TODO: what if some boxes are maxed out?
            if ($maxed_out == scalar(keys %{ $self->{running_instances} })) {

                # if there are no previous changes, or the last change wasn't a scale up, or enough time has elapsed, let's do it!
                if (!$psc ||
                    $psc->{direction} ne "up" ||
                    ($psc && ($psc->{complete_time} + $self->app->config('flock_aws_scaleup_cooldown') < time))) {

                    # make sure we can scale this high.
                    if ($self->app->config->{flock_aws_scale_pattern}->[ $self->scale_state + 1 ]) {

                        # TRIGGER SCALE UP, WE'VE MAXED OUT ALL INSTANCES IN THIS SCALE STATE + COOLDOWN HAS ELAPSED
                        $self->scale_to($self->scale_state + 1, "High CPU");
                    }
                }
            } elsif ($minned_out == scalar(keys %{ $self->{running_instances} })) {

                # make sure we've waited the scaledown cooldown time
                if (!$psc ||
                    ($psc && ($psc->{complete_time} + $self->app->config('flock_aws_scaledown_cooldown') < time))) {

                    # make sure we can scale this low, can't scale below the floor.
                    if (($self->scale_state - 1) >= $self->scale_floor) {

                        # TRIGGER SCALE DOWN, NOT ENOUGH LOAD TO STAY AT THIS SCALE STATE
                        $self->scale_to($self->scale_state - 1, "Low CPU");
                    }
                }
            }
        }
    }
}

sub _NODE_LOAD {
    my ($self, $data) = @_;

    my ($event_id, $instance_id, $hostname, $l1m, $l5m, $l15m) = split(/\s/, $data);

    if (exists $self->{running_instances}->{$instance_id}) {
        $self->{running_instances}->{$instance_id}->{load_avg} = [ $l1m, $l5m, $l15m ];

        if ((!$self->app->config('flock_scale_on')) || ($self->app->config('flock_scale_on') eq "NODE_LOAD")) {
            my $max_load = $self->state_info->{max_load};
            my $min_load = $self->state_info->{min_load};

            if (ref($max_load) && ($l1m > $max_load->[0] || $l5m > $max_load->[1] || $l15m > $max_load->[2])) {

                # just takes one of the three to trip!
                $self->{running_instances}->{$instance_id}->{over_max}  = 1;
                $self->{running_instances}->{$instance_id}->{below_min} = 0;
            } elsif (ref($min_load) && ($l1m < $min_load->[0] || $l5m < $min_load->[1] || $l15m < $min_load->[2])) {
                $self->{running_instances}->{$instance_id}->{below_min} = 1;
                $self->{running_instances}->{$instance_id}->{over_max}  = 0;
            } else {

                # allow these to toggle off on subsequent checks.
                $self->{running_instances}->{$instance_id}->{over_max}  = 0;
                $self->{running_instances}->{$instance_id}->{below_min} = 0;
            }
        }
    } else {
        $self->log->debug("we just got load information for a node we didn't know was running: $instance_id");
    }

    # this does the actual scaling, which we'll only do if we're configured to scale on NODE_LOAD
    if ((!$self->app->config('flock_scale_on')) || ($self->app->config('flock_scale_on') eq "NODE_LOAD")) {
        my $maxed_out = 0;
        foreach my $instance_id (keys %{ $self->{running_instances} }) {
            if ($self->{running_instances}->{$instance_id}->{over_max}) {
                $maxed_out++;
            }
        }

        my $minned_out = 0;
        foreach my $instance_id (keys %{ $self->{running_instances} }) {
            if ($self->{running_instances}->{$instance_id}->{below_min}) {
                $minned_out++;
            }
        }

        # determine if we're currently in a state change.
        my $sc;
        if (ref($self->state_change) eq "HASH") {
            $sc = $self->state_change;
        }

        # get the previous state change if it exists.
        my $psc;
        if (ref($self->previous_state_change) eq "HASH") {
            $psc = $self->previous_state_change;
        }

        # don't change state if we're already in a state change.
        unless ($sc) {

            # if all boxes are maxed out, it's time to scale up. TODO: what if some boxes are maxed out?
            if ($maxed_out == scalar(keys %{ $self->{running_instances} })) {

                # if there are no previous changes, or the last change wasn't a scale up, or enough time has elapsed, let's do it!
                if (!$psc ||
                    $psc->{direction} ne "up" ||
                    ($psc && ($psc->{complete_time} + $self->app->config('flock_aws_scaleup_cooldown') < time))) {

                    # make sure we can scale this high.
                    if ($self->app->config->{flock_aws_scale_pattern}->[ $self->scale_state + 1 ]) {

                        # TRIGGER SCALE UP, WE'VE MAXED OUT ALL INSTANCES IN THIS SCALE STATE + COOLDOWN HAS ELAPSED
                        $self->scale_to($self->scale_state + 1, "High Load");
                    }
                }
            } elsif ($minned_out == scalar(keys %{ $self->{running_instances} })) {

                # make sure we've waited the scaledown cooldown time
                if (!$psc ||
                    ($psc && ($psc->{complete_time} + $self->app->config('flock_aws_scaledown_cooldown') < time))) {

                    # make sure we can scale this low, can't scale below the floor.
                    if (($self->scale_state - 1) >= $self->scale_floor) {

                        # TRIGGER SCALE DOWN, NOT ENOUGH LOAD TO STAY AT THIS SCALE STATE
                        $self->scale_to($self->scale_state - 1, "Low Load");
                    }
                }
            }
        }
    }
}

# ascend to a higher state
sub scale_to {
    my ($self, $state, $reason) = @_;

    my $proc_sc_queue;
    $proc_sc_queue = sub {
        my ($reactor) = @_;
        if ($self->{state_change}) {

            # we're (still?) in a state change, run again in 60 seconds.
            $reactor->timer(60 => $proc_sc_queue);
        } else {

            # we're not in a state change, let's take one off the queue and process it
            my ($state, $reason) = @{ shift(@{ $self->{state_change_queue} }) };
            $self->scale_to($state, $reason);

            # if there's still more states to scale to, we better keep ourselves activated
            unless (scalar(@{ $self->{state_change_queue} }) == 0) {
                $reactor->timer(60 => $proc_sc_queue);
            }
        }
    };

    if ($self->{state_change}) {

        # we're currently in a state change, queue it, and activate the queue processor.
        push(@{ $self->{state_change_queue} }, [ $state, $reason ]);
        $self->ioloop->timer(60, $proc_sc_queue);
        return undef;
    }

    my $direction;
    if ($self->scale_state > $state) {
        $direction = "down";
    } elsif ($self->scale_state < $state) {
        $direction = "up";
    } else {
        $direction = "flat";
    }

    # register that we're changing state.
    $self->{state_change} = {
        started_time => time,
        from         => $self->scale_state,
        to           => $state,
        reason       => $reason,
        direction    => $direction,
    };

    my $nsi = $self->app->config('flock_aws_scale_pattern')->[$state];
    if ($state >= 0) {
        $self->log->info("initiating scale to state $state ($nsi->{description}); reason: $reason");
    } elsif ($state == -1) {
        $self->log->info("initiating flock-wide shutdown; stopping all nodes");
    }

    my @to_start = $self->nodes_to_start($state);
    my @to_stop  = $self->nodes_to_stop($state);

    $self->{state_change}->{nodes_to_start} = scalar(@to_start);
    $self->{state_change}->{nodes_to_stop}  = scalar(@to_stop);

    # start the new instances.
    my (@started) = $self->launch_instances(@to_start);

    if (scalar(@started) != scalar(@to_start)) {
        $self->log->error("started " .
              scalar(@started) . " nodes, we were supposed to start " .
              scalar(@to_start) . " nodes.  this is bad.");
    }

    foreach my $instance (@started) {
        $self->configure_instance($instance);
    }

    foreach my $instance_id (@to_stop) {
        my ($state, $is) = $self->find_instance_state($instance_id);
        if ($state eq "running") {
            $self->change_instance_state($instance_id, "stopping");
        } else {
            $self->log->error("not-running, or unknown instance '$instance_id' listed as a node to stop.");
        }
    }

    $self->{state_change}->{nodes_started} = 0;
    $self->{state_change}->{nodes_stopped} = 0;

    # this sub will wait until all new nodes have started, and then reap the old ones.
    my $stop_nodes;
    $stop_nodes = sub {
        my ($reactor) = @_;
        my $sc = $self->state_change;
        if ($sc->{nodes_to_start} == $sc->{nodes_started}) {
            foreach my $instance_id (@to_stop) {
                $self->stop_instance($instance_id);
            }
        } else {
            $reactor->timer(5 => $stop_nodes);
        }
    };

    # if we have any nodes to stop, stop them only after we've started the other nodes.
    if (scalar(@to_stop)) {
        $self->ioloop->timer(5 => $stop_nodes);
    }

    # this sub will update state info and emit "state_change_complete"
    my $state_change_finished;
    $state_change_finished = sub {
        my ($reactor) = @_;
        my $sc = $self->state_change;
        if ($sc->{nodes_to_start} == $sc->{nodes_started} &&
            $sc->{nodes_to_stop} == $sc->{nodes_stopped}) {

            # set the complete time...
            $self->{state_change}->{complete_time} = time;

            # copy our last state change over.
            $self->{previous_state_change} = $self->{state_change};

            # indicate that we are no longer changing state.
            $self->{state_change} = undef;

            # set our new state!
            $self->scale_state($state);

            # emit in case anyone cares.. does anyone care?!
            $self->emit(state_change_complete => $self->{previous_state_change});
        } else {

            # keep going.
            $reactor->timer(5 => $state_change_finished);
        }
    };

    $self->ioloop->timer(5 => $state_change_finished);
}

sub replace_instance {
    my ($self, $instance_id, $replacement_instance_id, $callback) = @_;

    # get the info of the instance we are replacing
    my ($state, $is) = $self->find_instance_state($instance_id);
    unless ($state eq "running") {
        $self->log->error(
            "trying to replace '$instance_id' with '$replacement_instance_id' but '$instance_id' doesn't seem to be 'running'."
        );
        return undef;
    }

    # now the info for the replacement
    my ($r_state, $r_is) = $self->find_instance_state($replacement_instance_id);
    unless ($r_state eq "running") {
        $self->log->error(
            "trying to replace '$instance_id' with '$replacement_instance_id' but the replacement '$replacement_instance_id' doesn't seem to be 'running'."
        );
        return undef;
    }

    # let the node know we intend to shut it down
    $self->send_websocket_message(
        "COORDINATOR_NODE_SHUTDOWN_IMMINENT " . $self->app->new_uuid . " $instance_id $r_is->{hostname}");

    my $drain_attempts = 0;
    my $websockets_drained;
    $websockets_drained = sub {
        my ($reactor) = @_;

        if ($is->{established_http_sockets} <= 200 || $drain_attempts >= 2) {
            $self->log->info(
                "replaced instance '$instance_id' down to $is->{established_http_sockets} active connections, stopping instance."
            );
            $self->stop_instance($instance_id);

            if (ref($callback) eq "CODE") {
                $callback->();
            }
        } else {
            $drain_attempts++;
            $self->log->info(
                "replaced instance '$instance_id' still has $is->{established_http_sockets} active connections, delaying instance stop."
            );
            $reactor->timer(30 => $websockets_drained);
        }
    };

    # everyone should be gone by this time...
    $self->ioloop->timer(65 => $websockets_drained);
}

sub stop_instance {
    my ($self, $instance_id) = @_;

    my ($state, $is) = $self->find_instance_state($instance_id);

    unless ($state eq "running") {
        $self->log->info("[warning]: trying to stop '$instance_id' that we don't think is 'running'.");
    }

    my $instance = $self->lookup_instance($instance_id);

    # tear down the $
    $self->deconfigure_instance($instance, $is);

    # get rid of this.
    delete $self->{"$state\_instances"}->{$instance_id};

    # give the node a tiny heads up that this is coming, so it can (hopefully) terminate websockets
    $self->send_system_message("COORDINATOR_NODE_SHUTDOWN " . $self->app->new_uuid . " $instance_id");

    # waiting 3 seconds isn't going to hurt anybody.
    $self->ioloop->timer(
        3 => sub {

            # terminate the instance, this will remove it from the load balancer
            if ($instance->terminate) {

                # don't autovivify state_change if it's not there.
                $self->{state_change}->{nodes_stopped}++ if exists $self->{state_change};
            } else {
                $self->log->error("error terminating instance '$instance_id': @{[$self->ec2->error_str]}");
            }
        }
    );
}

sub lookup_instance {
    my ($self, $instance_id) = @_;
    return $self->ec2->describe_instances($instance_id);
}

# just creates an a record for this IP/Host using Route53
sub add_dns_record {
    my ($self, $ip, $hostname) = @_;
    $self->r53->change_resource_record_sets(
        zone_id => $self->app->config('flock_aws_dns_hosted_zone'),
        action  => 'create',
        name    => "$hostname.",
        type    => 'A',
        ttl     => 3600,
        value   => $ip,
    );
}

# removes a DNS record for this IP/Host using Route 53
sub remove_dns_record {
    my ($self, $hostname, $ip) = @_;

    $self->r53->change_resource_record_sets(
        zone_id => $self->app->config('flock_aws_dns_hosted_zone'),
        action  => 'delete',
        name    => "$hostname.",
        type    => 'A',
        ttl     => 3600,
        value   => $ip,
    );
}

sub generate_host {
    my ($self) = @_;
    my $crchex = $self->app->crc_hex($self->app->new_uuid);
    return "hypno-$crchex.@{[$self->app->config('hostname')]}";
}

sub launch_instances {
    my ($self, @types) = @_;

    # unpack some config options.
    my $c                 = $self->app->config;
    my $zone              = $c->{flock_aws_availability_zone};
    my $ami               = $c->{flock_aws_ami};
    my $key_name          = $c->{flock_aws_key_name};
    my $security_groups   = $c->{flock_aws_security_groups};
    my $subnet            = $self->vpc_subnet;
    my $network_interface = "eth0=:$subnet:" . join(',', @{$security_groups}) . ":true:Autoconfigured";

    my @launched;
    foreach my $type (@types) {
        my $instance = $self->ec2->run_instances(
            -image_id           => $ami,
            -zone               => $zone,
            -instance_type      => $type,
            -key_name           => $key_name,
            -network_interfaces => [$network_interface],
        );
        if ($instance) {
            push(@launched, $instance);
        } else {
            warn "[error]: aws did not launch instance: " . $self->ec2->error_str . "\n";
        }
    }

    foreach my $instance (@launched) {
        $self->ioloop->timer(
            1200 => sub {
                my ($state, $is) = $self->find_instance_state($instance->instanceId);

                # first check that we're still in a state change..
                if (ref($self->state_change) eq "HASH") {
                    unless ($state eq "running") {

                        # get the new one going right away..
                        my ($new_instance) = $self->launch_instances($instance->instanceType);
                        $self->configure_instance($new_instance);

                        # clean up the old one.
                        $self->deconfigure_instance($instance, $is);
                        delete $self->{"$state\_instances"}->{ $instance->instanceId };

                        # just being nice, not sure why.
                        $self->send_system_message(
                            "COORDINATOR_NODE_SHUTDOWN " . $self->app->new_uuid . " @{[$instance->instanceId]}");
                        $instance->terminate;

                        # log that this happened.
                        $self->log->error(
                            "instance @{[$instance->instanceId]} not in state 'running' after 20 minutes; cleaning up and starting again"
                        );
                    }
                }
            }
        );
    }

    return @launched;
}

sub deconfigure_instance {
    my ($self, $instance, $is) = @_;

    # cleanup... load balancer
    my $lb = $self->load_balancer();
    eval { $lb->deregister_instances_from_load_balancer(-instances => $instance->instanceId); };

    # cleanup... elastic ip
    my $ip_address = $self->ec2->describe_addresses($instance->ipAddress);
    eval { $self->remove_dns_record($is->{hostname}, "$ip_address"); };
    eval { $instance->disassociate_address; };

    unless ($ip_address && $self->ec2->release_address($ip_address)) {
        $self->log->error("releasing elastic ip '$ip_address' unsuccessful: @{[$self->ec2->error_str]}");
    }
}

# takes a VM::EC2 instance object as an argument
sub configure_instance {
    my ($self, $instance) = @_;

    # Allocate the IP address
    my $ip;
    if ($ip = $self->ec2->allocate_address(-vpc => 1)) {
        my $allocate_ip;
        $allocate_ip = sub {
            my ($reactor) = @_;
            unless ($ip->associate($instance)) {
                $self->log->debug($self->ec2->error_str . ", retrying in 5s.");

                # reset the timer if we didn't get it this time.
                $reactor->timer(5 => $allocate_ip);
            }
        };
        $self->ioloop->timer(15 => $allocate_ip);
    } else {
        $self->log->fatal(
            "[fatal] cannot scale; you might need to ask Amazon support for more Elastic IPs.  AWS Elastic IP Allocation Error: "
              . $self->ec2->error_str);
        $self->{state_change}->{failed} = 1;
        $self->{previous_state_change} = delete $self->{state_change};
        die
          "cannot scale; you might need to ask Amazon support for more Elastic IPs.  AWS Elastic IP Allocation Error: "
          . $self->ec2->error_str . "\n";
    }

    # generate a new hostname
    my $hostname = $self->generate_host;

    # setup DNS (makes it official)
    $self->add_dns_record($ip->publicIp, $hostname);

    $instance->add_tags(
        hostname                                        => $hostname,
        Name                                            => $hostname,
        "@{[$self->app->config('flock_aws_node_tag')]}" => 1,
    );

    # add the instance to running instances, they'll be running instances soon enough.
    $self->bootstrapping_instances->{ $instance->instanceId } = {
        hostname      => $hostname,
        instance_id   => $instance->instanceId,
        instance_type => $instance->instance_type,
        instance_obj  => $instance,
        launch_time   => Time::HiRes::time,
    };
}

sub vpc_subnet {
    my ($self) = @_;

    # check cache first..
    unless ($self->{subnet_obj}) {
        foreach my $subnet ($self->ec2->describe_subnets) {
            if ($subnet->cidrBlock eq $self->app->config('flock_aws_vpc_subnet')) {
                $self->{subnet_obj} = $subnet;
                last;
            }
        }
    }

    return $self->{subnet_obj};
}

# this returns instanceTypes to start, I'd return instance_ids but we don't have those yet.
sub nodes_to_start {
    my ($self, $state) = @_;

    # if we're going to state -1, we start no nodes.
    if ($state == -1) {
        return ();
    }

    # need the scale pattern.
    my $sp = $self->app->config('flock_aws_scale_pattern');
    my @nodes;
    if ($self->scale_state < 0) {

        # we don't need to check anything, just return the nodes
        for (my $i = 0 ; $i < $sp->[$state]->{nodes} ; $i++) {
            push(@nodes, $sp->[$state]->{instance_type});
        }
    } else {
        my $csi = $sp->[ $self->scale_state ];
        my $nsi = $sp->[$state];
        if ($csi->{instance_type} eq $nsi->{instance_type}) {

            # they're the same instance type, so just spin up however many more
            for (my $i = 0 ; $i < ($nsi->{nodes} - $csi->{nodes}) ; $i++) {
                push(@nodes, $nsi->{instance_type});
            }
        } else {

            # differing instance types, we're gonna start {nodes} of them.
            for (my $i = 0 ; $i < $nsi->{nodes} ; $i++) {
                push(@nodes, $nsi->{instance_type});
            }
        }
    }
    return @nodes;
}

# this returns instance_ids of nodes to stop, since we have those.
sub nodes_to_stop {
    my ($self, $state) = @_;

    # if we're going to state 1, we stop all the nodes.
    if ($state == -1) {
        return (keys %{ $self->running_instances });
    }

    # need the scale pattern.
    my $sp = $self->app->config('flock_aws_scale_pattern');
    my @instances;

    # can't become a state less than zero.
    unless ($state < 0) {

        # need the state definitions (n)ew (s)tate (i)nfo
        my $nsi = $sp->[$state];

        # these should have been set by ascertain_scale_state
        my $ri = $self->running_instances;

        my @same_it_running;

        # stop any instances that are running that don't belong in the $nsi
        foreach my $key (keys %$ri) {
            if ($ri->{$key}->{instance_type} eq $nsi->{instance_type}) {

                # stash these to evaluate later.
                push(@same_it_running, $key);
            } else {

                # if it's not of the new type, it's gotta go.
                push(@instances, $key);
            }
        }

        # if we're running more of this instance type than the new state has running, prune off the difference
        if ($nsi->{nodes} < scalar(@same_it_running)) {
            for (my $i = 0 ; $i < (scalar(@same_it_running) - $nsi->{nodes}) ; $i++) {
                push(@instances, $same_it_running[$i]);
            }
        }
    }
    return @instances;
}

sub configure_and_sync {
    my ($self, $instance_id) = @_;

    # get instance state..
    my ($instance_state, $is) = $self->find_instance_state($instance_id);

    # just make sure we have the instance.
    my $instance = $self->lookup_instance($instance_id);

    if (my $flock_ip = $is->{flock_ip}) {
        my $start_time   = time;
        my $working_path = "/var/tmp/$instance_id.$start_time";

        # create a scratch area for our config
        mkdir("$working_path");

        # copy in our node's config.
        system("rsync -apr --exclude .svn --exclude .git /usr/local/meritcommons/meritcommons/etc/ $working_path/");

        # load the config
        my $meritcommons_conf = do "$working_path/meritcommons.conf";

        # get the hostname out of the instance object.
        my $hostname = $is->{hostname};

        # change the hostname.
        $meritcommons_conf->{hostname} = $hostname;

        # interpolate the hostname into the existing config, and change it...
        my $advertised_websocket = $self->app->config->{advertised_websocket};
        $advertised_websocket =~ s/%%hostname%%/$hostname/g;
        $meritcommons_conf->{advertised_websocket} = $advertised_websocket;

        # get the state we're changing to...
        my $to_state = $self->state_change->{to};

        $meritcommons_conf->{deployment_profile} = "flock_worker.idp";

        # how many hypnotoad workers to start
        $meritcommons_conf->{hypnotoad}->{workers} =
          $meritcommons_conf->{flock_aws_scale_pattern}->[$to_state]->{hypnotoad_workers};

        # how many minion workers to start
        $meritcommons_conf->{minion_mp_workers} =
          $meritcommons_conf->{flock_aws_scale_pattern}->[$to_state]->{minion_workers};

        # the worker node will definitely not be a flock coordinator
        $meritcommons_conf->{flock_coordinator} = 0;

        # write this config out.
        local $Data::Dumper::Terse = 1;
        open my $new_file, '>', "$working_path/meritcommons.conf";
        print $new_file Dumper($meritcommons_conf);
        close $new_file;

        # first meritcommons
        system(
            qq|rsync -e "ssh -q -oStrictHostKeyChecking=no" -apr --exclude log/* --exclude .svn --exclude .git --exclude var/sql /usr/local/meritcommons/meritcommons/ $flock_ip:/usr/local/meritcommons/meritcommons/|
        );

        # now plugins
        if (-d "/usr/local/meritcommons/plugins") {
            system(
                qq|rsync -e "ssh -q -oStrictHostKeyChecking=no" -apr --exclude .git --exclude .svn /usr/local/meritcommons/plugins/ $flock_ip:/usr/local/meritcommons/plugins/|
            );
        }

        # now our config
        system(
            qq|rsync -e "ssh -q -oStrictHostKeyChecking=no" -apr $working_path/ $flock_ip:/usr/local/meritcommons/meritcommons/etc/|
        );

        # plugins schema + config
        system(
            qq|rsync -e "ssh -q -oStrictHostKeyChecking=no" -apr --exclude sql --exclude .git --exclude .svn /usr/local/meritcommons/var/plugins/ $flock_ip:/usr/local/meritcommons/var/plugins/|
        );

        system("rm -rf $working_path");
        return 1;
    } else {
        warn "[error]: cannot configure_and_sync $instance_id, unknown flock_ip.\n";
    }

}

# this moves the data from one instance state to another, returns old state, new state if successful.  undef if not.
sub change_instance_state {
    my ($self, $instance_id, $state) = @_;
    my ($current_state, $is) = $self->find_instance_state($instance_id);
    if (exists($self->{"$state\_instances"})) {
        my $old = delete $self->{"$current_state\_instances"}->{$instance_id};
        $self->{"$state\_instances"}->{$instance_id} = $old;
        return ($current_state, $state);
    } else {
        return undef;
    }
}

sub find_instance_state {
    my ($self, $instance_id) = @_;

    # search all (i)nstance (s)tates for the instance_id...
    foreach my $is (qw/bootstrapping running/) {
        foreach my $key (keys %{ $self->{"$is\_instances"} }) {
            if ($key eq $instance_id) {
                return ($is, $self->{"$is\_instances"}->{$key});
            }
        }
    }
}

sub ping_ip {
    my ($self, $ip) = @_;
    my $ping = `/bin/ping -i .5 -c 2 -w 2 $ip | /bin/grep time=`;
    my ($ptime) = $ping =~ /time=([\d\.]+ \w+)/;
    return $ptime;
}

sub state_info {
    my ($self) = @_;
    my $sp = $self->app->config('flock_aws_scale_pattern');
    if ($self->scale_state == -1) {
        return { description => "Flock is DOWN", };
    } else {
        return $sp->[ $self->scale_state ];
    }
}

sub load_balancer {
    my ($self) = @_;

    my $lb;
    unless ($lb = $self->{lb_cache}) {
        my $lb_name = $self->app->config->{flock_aws_load_balancer};
        $lb = $self->ec2->describe_load_balancers($lb_name);
        $self->{lb_cache} = $lb;
    }
    return $lb;
}

# returns true if the load balancer is balancing these instances, otherwise, no.
sub instance_load_balanced {
    my ($self, $instance_id) = @_;
    foreach my $instance ($self->load_balancer->Instances) {
        if ($instance->instanceId eq $instance_id) {
            return 1;
        }
    }
    return undef;
}

# scale state is now all about running instances with our flock_aws_node_tag set to "1"
sub ascertain_scale_state {
    my ($self) = @_;

    my $node_tag = $self->app->config('flock_aws_node_tag') // "meritcommons-flock";

    my @instances = $self->ec2->describe_instances(
        -filter => {
            "tag:$node_tag" => 1,
        },
    );

    my $instance_types = {};
    foreach my $instance (@instances) {
        if ($instance->instanceState eq "running" && $self->instance_load_balanced($instance)) {
            $instance_types->{ $instance->instanceType }++;
            $self->running_instances->{ $instance->instanceId } = {
                hostname      => $instance->tags->{hostname},
                instance_id   => $instance->instanceId,
                instance_type => $instance->instanceType,
                instance_obj  => $instance,
                launch_time   => str2time($instance->launchTime),
            };
        } else {
            $self->log->debug(
                "non 'running', or non-load-balanced 'running' instance found: $instance for @{[$instance->tags->{hostname}]} "
                  . "in state @{[$instance->instanceState]}")
              unless $instance->instanceState eq "terminated";
        }
    }

    if (scalar(keys %$instance_types) == 0) {
        $self->{scale_state} = -1;    # flock is stopped.
        $self->{stopped}     = 1;
    } else {

        my $instance_type;
        if (scalar(keys %$instance_types) > 1) {

            # we are likely between scale states as we have multiple instance types, let's
            # figure out the "largest" instance type we have running, use that to determine state
            my %sizes = qw/micro 0 small 1 medium 2 large 3 xlarge 4 2xlarge 5 4xlarge 6 8xlarge 7/;

            foreach my $it (keys %$instance_types) {
                my ($class, $size) = split(/\./, $it);
                if ($instance_type) {
                    if ($sizes{$size} > $sizes{$instance_type}) {
                        $instance_type = $size;
                    }
                } else {
                    $instance_type = $size;
                }
            }
            $self->log->info(
                "when determining flock state, found more than one instance type.  settled on $instance_type.");
        } else {
            $instance_type = (keys %$instance_types)[0];
        }

        # get the scale pattern
        my $sp = $self->app->config('flock_aws_scale_pattern');

        for (my $i = 0 ; $i < scalar(@$sp) ; $i++) {
            my $state = $sp->[$i];

            if ($state->{instance_type} eq $instance_type) {

                # if we're running the same number of these nodes, consider us at this state.
                if ($instance_types->{$instance_type} == $state->{nodes}) {
                    $self->{scale_state} = $i;
                    last;
                }
            }
        }

        # if we couldn't figure out what state we're in, let's start over.
        unless (defined($self->{scale_state})) {
            $self->{scale_state} = -1;
            $self->{stopped}     = 1;
        }
    }

    return 1;
}

sub uptime {
    return time - shift->{start_time};
}

sub handle_system_message {
    my ($self,         $message) = @_;
    my ($message_type, $payload) = $message =~ /^([A-Z_]+) (.+)$/;
    $self->emit($message_type => $payload);
}

# can write responses back to socket if need be.
sub handle_console_message {
    my ($self, $message, $socket) = @_;
    my ($command, @args) = split(/\s+/, $message);

    if ($self->has_subscribers($command)) {
        $self->emit($command, $socket, @args);
    } else {
        print $socket 'A:\MERITCOMMONS>' . uc($command) . ".EXE\n";
        print $socket "Bad command or file name\n";
        $self->ioloop->remove($socket);
        $socket->close;
    }
}

sub send_websocket_message {
    my ($self, $message_type, $payload) = @_;

    zmq_msg_send("WEBSOCKET", $self->{zmq_publisher}, ZMQ_SNDMORE);
    if ($payload) {
        zmq_msg_send("$message_type $payload", $self->{zmq_publisher});
    } else {
        zmq_msg_send($message_type, $self->{zmq_publisher});
    }
}

sub send_system_message {
    my ($self, $message_type, $payload) = @_;

    zmq_msg_send("SYSTEM", $self->{zmq_publisher}, ZMQ_SNDMORE);
    if ($payload) {
        zmq_msg_send("$message_type $payload", $self->{zmq_publisher});
    } else {
        zmq_msg_send($message_type, $self->{zmq_publisher});
    }
}

sub shutdown {
    my ($self) = @_;
    $self->log->info(
        "[shutdown]: AWS Flock Coordinator PID $$ shutting down; stopping FlockVPN, ZeroMQ, and exiting...");

    # be polite and say goodbye.
    $self->send_system_message("COORDINATOR_GOODBYE @{[$self->uptime]}");

    # shutting down the IOLoop in a nice way.
    $self->ioloop->stop;

    # shut down and clean up the local UNIX socket
    $self->ioloop->reactor->remove($self->local_socket);
    $self->local_socket->shutdown(2);
    $self->local_socket->close;
    unlink($self->app->config('flock_coordinator_socket_path'));

    # clean up our pidfile
    unlink($self->pid_file);

    # clean up ZMQ
    zmq_setsockopt($self->zmq_subscriber, ZMQ_LINGER, 0);
    zmq_close($self->zmq_subscriber);

    zmq_setsockopt($self->zmq_publisher, ZMQ_LINGER, 0);
    zmq_close($self->zmq_publisher);
    zmq_ctx_destroy($self->zmq_sctx);
    zmq_ctx_destroy($self->zmq_pctx);

    # stop FlockVPN tools
    $self->fvpn->stop_dhcpd;
    $self->fvpn->stop_edge;

    # mark us as shut down.
    $self->{shutdown} = 1;
    exit();
}

sub DESTROY {
    my ($self) = @_;
    if ($self->{fvpn} && !$self->{shutdown}) {
        $self->shutdown;
    }
}

1;
