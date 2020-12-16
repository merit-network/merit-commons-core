#    MeritCommons Portal
#    Copyright 2018 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Unsubscribe;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    my @uuids;
    foreach my $check (qw/messages streams/) {
        if (ref $data->{$check} eq "ARRAY") {
            push(@uuids, @{ $data->{$check} });
        }
    }

    if ($self->controller->active_user) {
        foreach my $uuid (@uuids) {
            unless (zmq_setsockopt($self->hydrant->zmq_subscriber, ZMQ_UNSUBSCRIBE, $uuid) == 0) {
                $self->send("Error removing subscription to message/stream $uuid", "cmdresponse:error");
            }
        }
    } else {
        $self->send("Access Denied: I don't have any idea who you are, please log in!", "cmdresponse:error");
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input($arg);
        $v->optional('streams')->like($self->F_UUID);
        $v->optional('messages')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
