#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::UnlinkFromThread;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;
    my $user = $self->controller->active_user;

    my $message = $self->controller->message($data->{message});
    my $thread  = $self->controller->message($data->{thread});

    my $can_moderate = 0;
    foreach my $stream ($message->streams) {
        if ($user->can_moderate($stream)) {

            # just takes one.
            $can_moderate = 1;
            last;
        }
    }

    if ($message->thread_id eq $thread->unique_id) {
        if ($can_moderate || $message->submitter->id == $user->id) {

            # orphan the message...
            foreach my $stream ($message->streams) {
                $message->unlink_from_stream($stream);
            }

            my $watch = $user->watched_messages->find({ target => $message->thread_id });
            if ($watch) {
                $watch->delete;
            }

            # remove it from the thread by making its own parent.
            $message->thread_id($message->unique_id);
            $message->update;

            $self->controller->update_message_index($message);
            $self->controller->cache->delete($message->unique_id);
            $self->controller->pub_write(join(" ", $message->unique_id, $message->unique_id));
        }
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('message')->like($self->F_UUID);
        $v->required('thread')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
