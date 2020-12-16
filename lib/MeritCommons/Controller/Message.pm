#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Message;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    return if $self->features_detected;

    my $message_id = $self->stash('message_identifier');
    my $message    = $self->message($message_id);

    my ($has_access, $user);
    if ($user = $self->active_user) {
        if ($user->is_admin) {
            $has_access = 1;
        } else {
            foreach my $stream ($message->streams) {
                if ($user->can_read($stream)) {
                    $has_access = 1;
                    last;
                }
            }
        }
    }

    if ($has_access) {
        $self->stash(payloads => [ $self->prepare_payload([$message], $user, 1) ]);
        $self->render(template => "message/default");
    } else {
        $self->reply->not_found;
    }
}

#
# mark a message read!
#
sub mark_read {
    my ($self) = @_;

    # what message id (retrieve by JSON or POST param)
    my (@message_ids);
    if (my $json_data = $self->req->json) {
        @message_ids =
          ref($json_data->{message_ids}) eq "ARRAY" ? @{ $json_data->{message_ids} } : ($json_data->{message_id});
    } else {
        @message_ids = @{ $self->every_param('message_id') };
    }

    foreach my $message_id (@message_ids) {

        # mark it read!
        my $user = $self->active_user;
        my $msg  = $self->message($message_id);
        $msg->mark(_read => $user);
    }

    $self->render(text => scalar(@message_ids) . " marked as read!");
}

1;
