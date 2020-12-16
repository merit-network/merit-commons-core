#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::flock_coordinator;

use Mojo::IOLoop;
use Mojo::Base 'Mojolicious::Command';
use MeritCommons::Infra::FlockVPN;
use File::Find;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Storable qw(freeze thaw dclone);
use Mojo::EventEmitter;
use IO::Interface;

our @ISA;
push(@ISA, 'Mojo::EventEmitter');

has description => "MeritCommons Flock (cluster) coordinator process\n";
has usage       => "Usage: $0 flock_coordinator\n";

sub run {
    my ($self, @args) = @_;

    # what time did we start running?
    $self->{start_time} = time;

    if ($self->app->config('flock_coordinator')) {
        if ($self->app->config('flock_vpn')) {
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

            $self->on(
                NODE_HELLO => sub {
                    my ($self, $data) = @_;
                    print "Node came online: $data\n";
                }
            );

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

                        # send for dispatch...
                        $self->handle_system_message($content);
                    }
                }
            )->watch($self->{zmq_subfh}, 1, 0);

            print <<"EOF";
MeritCommons $MeritCommons::VERSION ($MeritCommons::CODENAME) Flock Coordinator
(c) 2014 Wayne State University

[info]: actively watching for system events.
EOF

            # if the supernode went away, this might go unheard
            $loop->timer(
                5 => sub {
                    my ($loop) = @_;

                    # tell everyone we're here.
                    $self->send_system_message("COORDINATOR_HELLO @{[$self->uptime]}");
                }
            );

            # this will result in an update from all nodes a second time, but we might
            # have missed some if the supernode had gone away (box crash, etc), so just
            # to be on the safe side...
            $loop->timer(
                300 => sub {
                    my ($loop) = @_;

                    # tell everyone we're here, again, 5 minutes after we started.
                    $self->send_system_message("COORDINATOR_HELLO @{[$self->uptime]}");
                }
            );

            $loop->start;
        } else {
            print "[info] flock_coordinator currently only works with FlockVPN\n";
        }
    } else {
        print "[info] flock_coordinator reqires this node be configured with flock_coordinator => 1",;
    }
}

sub uptime {
    return time - shift->{start_time};
}

sub handle_system_message {
    my ($self,         $message) = @_;
    my ($message_type, $payload) = $message =~ /^([A-Z_]+) (.+)$/;
    $self->emit($message_type => $payload);
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
    print "[shutdown]: stopping FlockVPN, ZeroMQ, and exiting...\n";

    # be polite and say goodbye.
    $self->send_system_message("COORDINATOR_GOODBYE @{[$self->uptime]}");

    # clean up ZMQ
    zmq_close($self->{zmq_subscriber});
    zmq_close($self->{zmq_publisher});
    zmq_term($self->{zmq_sctx});
    zmq_term($self->{zmq_pctx});

    # stop FlockVPN tools
    $self->{fvpn}->stop_dhcpd;
    $self->{fvpn}->stop_edge;
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
