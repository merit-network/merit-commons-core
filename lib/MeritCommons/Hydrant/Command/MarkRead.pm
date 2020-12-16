#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::MarkRead;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'messages';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;
    my $user = $self->controller->active_user;
    my $count;
    foreach my $msg (@$arg) {
        $msg->mark_read_by($user);
        $count++;

        # clear the cache for this message.
        $self->controller->cache->delete($msg->unique_id);

        # let everyone know this message has changed.
        foreach my $stream ($msg->streams) {
            $self->controller->pub_write(join(" ", $stream->unique_id, $msg->unique_id));
        }
    }
    $self->send("$count messages marked as read");
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input({ message_ids => $arg })->required('message_ids')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
