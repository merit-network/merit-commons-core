#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Subscribe;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'stream';
has user_activity_flag  => 1;

sub command {
    my ($self, $stream) = @_;
    my $active_user = $self->controller->active_user;

    if ($active_user && $active_user->can_read($stream)) {
        unless (zmq_setsockopt($self->hydrant->zmq_subscriber, ZMQ_SUBSCRIBE, $stream->unique_id) == 0) {
            $self->send("Error adding subscription to stream '@{[$stream->common_name]}': $!", "cmdresponse:error");
        }
    } else {
        $self->send("Access Denied: you don't have access to subscribe to stream @{[$stream->common_name]}.",
            "cmdresponse:error");
    }
}

# a hook to add custom checks..
sub _validation {
    my ($self, $validation) = @_;

    # add this check if we're the first...
    # unless (exists $validation->validator->checks->{stream}) {
    #     $validation->validator->add_check(stream => sub {
    #         my ($validation, $name, $value) = @_;
    #         if (ref $value eq "MeritCommons::Model::Stream") {
    #             return undef;
    #         } else {
    #             return 1;
    #         }
    #     });
    # }

    return $validation;
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input({ stream => $arg })->required('stream')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
