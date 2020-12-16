#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::UnlinkFromStream;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;
    my $user = $self->controller->active_user;

    my $streams = $data->{streams};
    my $message = $self->controller->message($data->{message});

    my $submitter = $message->submitter;

    # specified all streams!
    if ($streams->[0] eq "all") {
        $streams = [];

        # only honor this if we're an admin or we submitted the message.
        if ($user->id == $submitter->id || $user->is_admin) {
            foreach my $stream ($message->streams) {
                push(@$streams, $stream->unique_id);
            }
        }
    }

    my $unlinked = 0;
    foreach my $stream (map { $self->controller->stream($_) } @$streams) {
        if ($stream && $message) {
            if ($user->can_moderate($stream) || $user->id == $submitter->id) {
                if ($message->unlink_from_stream($stream)) {
                    $unlinked++;
                }
            } else {
                $self->send("not moderator", "cmdresponse:error");
            }
        } else {
            $self->send("unlink_from_stream: stream or message not found", "cmdresponse:error");
        }
    }

    # just update the message
    if ($unlinked) {
        $self->controller->update_message_index($message);
        $self->controller->cache->delete($message->unique_id);
        $self->controller->pub_write(join(" ", $message->unique_id, $message->unique_id));
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('streams')->like(qr/^(?:all|[A-F0-9-]{36})$/io);
        $v->required('message')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
