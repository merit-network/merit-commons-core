#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Vote;

# declare our @ISA
our @ISA;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

sub vote {
    my ($self) = @_;

    # check for an active session..
    unless ($self->active_user) {
        $self->render(text => 'NO CARRIER');
        return;
    }

    # register this vote!
    my ($message_id, $vote);
    if (my $json_data = $self->req->json) {
        $message_id = $json_data->{message_id};
        $vote       = $json_data->{vote};
    } else {
        $message_id = $self->param('message_id');
        $vote       = $self->param('vote');
    }

    # normalize hack0d vote values ;)
    if ($vote > 0) {
        $vote = 1;
    } elsif ($vote < 0) {
        $vote = -1;
    } else {

        # tell the "hacker" they've hurt our feelings.
        $self->render(text => "... *sigh*");
        return;
    }

    if (my $msg = $self->app->message($message_id)) {
        my $previous_vote = $msg->votes->search({ voter => $self->active_user->id })->first;
        if (!$previous_vote || $previous_vote->vote != $vote) {

            # really wipe out the previous vote.
            if ($previous_vote) {
                $msg->score($msg->score - $previous_vote->vote);
                $msg->update;
                $previous_vote->delete;
            }

            # register vote
            my $vote = $msg->votes->create(
                {
                    voter => $self->active_user->id,
                    vote  => $vote,
                }
            );

            # tell the client side.
            $self->render(
                json => {
                    success       => 1,
                    message       => "Vote for $message_id registered successfully",
                    message_score => $msg->score + $vote->vote,
                }
            );

            $self->app->cache->delete($message_id);

            # tell the publisher that this message has been updated (update all watching)
            $self->pub_write($msg->unique_id . " " . $msg->unique_id);

            # tell the notifier that this happened, too.  so we can let people know we liked/disliked their thing.
            if ($vote->vote > 0) {
                $self->notifier_write($msg, $self->active_user, "like");
            } else {
                $self->notifier_write($msg, $self->active_user, "dislike");
            }
        } elsif ($previous_vote) {

            # this is a re-click of the same type of vote, aka undo / neutral.
            $msg->score($msg->score - $previous_vote->vote);
            $msg->update;
            $previous_vote->delete;

            # tell the client side.
            $self->render(
                json => {
                    success       => 1,
                    message       => "Vote for $message_id has been expunged successfully",
                    message_score => $msg->score,
                }
            );

            $self->app->cache->delete($message_id);

            # tell the publisher that this message has been updated (update all watching)
            $self->pub_write($msg->unique_id . " " . $msg->unique_id);
        } else {
            $self->render(json =>
                  { success => 0, message => "This shouldn't ever happen (yeah, i wrote an error message like this)" });
        }

    } else {
        $self->render(json => { success => 0, message => "Message $message_id not found" });
    }
}

sub voted {
    my ($self) = @_;

    # register this vote!
    my ($message_id);
    if (my $json_data = $self->req->json) {
        $message_id = $json_data->{message_id};
    } else {
        $message_id = $self->param('message_id');
    }

    if (my $msg = $self->app->message($message_id)) {
        my $for     = [];
        my $against = [];
        foreach my $vote ($msg->votes) {
            my $profile_picture = $self->profile_picture_url_for($vote->voter, 'tiny');

            if ($vote->vote > 0) {

                # this is a like
                push(
                    @$for,
                    {
                        vote => $vote->vote,
                        who  => {
                            userid          => $vote->voter->userid,
                            common_name     => $vote->voter->common_name,
                            profile_picture => $profile_picture,
                        },
                        when => $vote->create_time,
                    }
                );
            } else {

                # this is a dislike
                push(
                    @$against,
                    {
                        vote => $vote->vote,
                        who  => {
                            userid          => $vote->voter->userid,
                            common_name     => $vote->voter->common_name,
                            profile_picture => $profile_picture,
                        },
                        when => $vote->create_time,
                    }
                );
            }
        }

        # sort both by name...
        $for     = [ sort { $a->{who}->{common_name} cmp $b->{who}->{common_name} } @$for ];
        $against = [ sort { $a->{who}->{common_name} cmp $b->{who}->{common_name} } @$against ];

        $self->render(json => { success => 1, voted_for => $for, voted_against => $against });
    } else {
        $self->render(json => { success => 0, message => "Message $message_id not found" });
    }
}

1;
