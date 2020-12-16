#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Vote;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

use MeritCommons::Content;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    if ($data->{vote} > 0) {
        $data->{vote}      = 1;
        $data->{is_a_vote} = 1;
    } elsif ($data->{vote} < 0) {
        $data->{vote}      = -1;
        $data->{is_a_vote} = 1;
    }

    my $message = $self->controller->message($data->{message_id});

    if ($message) {
        if ($data->{is_a_vote}) {
            my $pv = $message->votes->search({ voter => $self->controller->active_user->id })->first;
            my ($undo, $change);

            # clean up previous vote
            if ($pv) {
                $message->score($message->score - $pv->vote);
                $message->update;
                $pv->delete;
            }

            if (!$pv || $pv->vote != $data->{vote}) {
                my $v = $message->votes->create(
                    {
                        voter => $self->controller->active_user->id,
                        vote  => $data->{vote},
                    }
                );

                if ($data->{vote} > 0) {
                    $self->controller->notifier_write($message, $self->controller->active_user, "like");
                } else {
                    $self->controller->notifier_write($message, $self->controller->active_user, "dislike");
                }
                $change = 1 if $pv;
            } elsif ($pv) {
                $undo = 1;
            }

            # tell our publisher!
            $self->controller->cache->delete($data->{message_id});
            $self->controller->pub_write($message->unique_id . " " . $message->unique_id);

            $self->send(
                {
                    success         => 1,
                    upvote_undo     => (($data->{vote} == 1) && $undo) ? 1 : 0,
                    downvote_undo   => (($data->{vote} == -1) && $undo) ? 1 : 0,
                    upvote          => (($data->{vote} == 1) && !$undo && !$change) ? 1 : 0,
                    downvote        => (($data->{vote} == -1) && !$undo && !$change) ? 1 : 0,
                    upvote_change   => (($data->{vote} == 1) && !$undo && $change) ? 1 : 0,
                    downvote_change => (($data->{vote} == -1) && !$undo && $change) ? 1 : 0,
                },
                'vote:response'
            );
        }
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('vote')->in(-1, 1);
        $v->required('message_id')->like(qr/^[A-F0-9-]{36}$/i);
        return $v;
    }

    return undef;
}

1;
