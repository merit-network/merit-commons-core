#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::SubscribeToMessages;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Array::Utils qw(:all);
use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/decode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;

    my @requested_message_ids = @{ $arg->{messages} };

    if (my $user = $self->controller->active_user) {

        # Push requested messages through a filter to determine what the user has access to
        my $filtered_messages = $user->authorized_messages_filter(@requested_message_ids);
        my @filtered_message_ids = map { $_->unique_id } $filtered_messages->all;

        # Identify messages that didn't make it through the filter
        my @rejected_message_ids = array_minus(@requested_message_ids, @filtered_message_ids);
        foreach my $rejected_msg_id (@rejected_message_ids) {
            $self->send("Invalid message or access denied - $rejected_msg_id.", "cmdresponse:error");
        }

        # Subscribe to messages that passed the filter
        foreach my $msg_id (@filtered_message_ids) {
            unless (zmq_setsockopt($self->hydrant->zmq_subscriber, ZMQ_SUBSCRIBE, $msg_id) == 0) {
                $self->send("Error adding subscription to message '$msg_id': $!", "cmdresponse:error");
            }
        }
    } else {
        $self->send("Invalid message or access denied.", "cmdresponse:error");
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        return $v->input($arg)->required('messages')->like($self->F_UUID);
    }

    return undef;
}
1;
