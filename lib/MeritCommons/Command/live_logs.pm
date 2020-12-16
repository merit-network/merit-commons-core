#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::live_logs;

use Mojo::IOLoop;
use Mojo::Base 'Mojolicious::Command';
use File::Find;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Storable qw(freeze thaw dclone);
use Mojo::EventEmitter;

our @ISA;
push(@ISA, 'Mojo::EventEmitter');

has description => "Live log data from the flock\n";
has usage       => "Usage: $0 live_logs\n";

sub run {
    my ($self, @args) = @_;

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
        next if $publisher =~ /ipc/;    # we don't want our own chatter.
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

                # send for dispatch...
                print "$content\n";
            }
        }
    )->watch($self->{zmq_subfh}, 1, 0);

    print <<"EOF";
MeritCommons $MeritCommons::VERSION ($MeritCommons::CODENAME) Live Logs
(c) 2014 Wayne State University

[info]: actively watching for log events.
EOF

    $loop->start;

}

sub uptime {
    return time - shift->{start_time};
}

sub shutdown {
    my ($self) = @_;
    print "[shutdown]: stopping Live Logs...\n";

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
