#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Mystreams;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    if (my $actor = $self->active_user) {
        if (my $user = $self->user($self->stash('user'))) {
            if ($actor->id == $user->id) {
                $self->stash('user', $user);

                my $subs_to_show = {};
                foreach my $sub ($user->subscriptions) {
                    unless ($sub->stream->id == $user->personal_inbox->id ||
                        $sub->stream->id == $user->notification_inbox->id ||
                        $sub->stream->id == $user->personal_outbox->id    ||
                        $sub->stream->id == 1) {
                        my $name = $sub->stream->common_name;

                        $subs_to_show->{$name} = {
                            'sub'     => $sub,
                            deletable => $sub->stream->id == $user->personal_outbox->id ? 0
                            : !$sub->stream->allow_unsubscribe ? 0
                            :                                    1,
                        };
                    }
                }
                $self->stash('subs', $subs_to_show);

                my $auts_to_show = {};
                foreach my $aut ($user->authorships) {
                    unless ($aut->stream->id == $user->personal_inbox->id ||
                        $aut->stream->id == $user->personal_outbox->id ||
                        $aut->stream->id == $user->notification_inbox->id) {
                        my $name = $aut->stream->common_name;

                        $auts_to_show->{$name} = {
                            'aut'     => $aut,
                            deletable => $aut->stream->id == $user->personal_outbox->id ? 0
                            : !$aut->stream->allow_unsubscribe ? 0
                            :                                    1,
                        };
                    }
                }
                $self->stash('auts', $auts_to_show);

                my $mods_to_show = {};
                foreach my $mod ($user->moderatorships) {
                    my @stream_moderators = $mod->stream->moderators->all;
                    unless ($mod->stream->id == $user->personal_inbox->id ||
                        $mod->stream->id == $user->personal_outbox->id ||
                        $mod->stream->id == $user->notification_inbox->id) {
                        my $name = $mod->stream->common_name;

                        my $message;
                        if ($mod->stream->id == $user->personal_outbox->id) {
                            $message = "Can't remove yourself as moderator of your own feed!";
                        } elsif (scalar(@stream_moderators) <= 1) {
                            $message = "Can't remove yourself as moderator because you're the last one!";
                        }

                        $mods_to_show->{$name} = {
                            'mod'     => $mod,
                            deletable => defined($message) ? 0 : 1,
                            message   => $message,
                        };
                    }
                }
                $self->stash('mods', $mods_to_show);

                $self->render(template => "mystreams/default");
            } else {
                $self->reply->not_found;
            }
        } else {
            $self->reply->not_found;
        }
    } else {
        $self->reply->not_found;
    }
}

1;
