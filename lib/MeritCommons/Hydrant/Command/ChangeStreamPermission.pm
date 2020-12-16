#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::ChangeStreamPermission;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/decode_json true false/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    my $controller = $self->controller;
    my $actor      = $controller->active_user;

    my $event;
    my $response;
    my $stream = $controller->stream($data->{streamId});
    if ($data->{action} eq 'remove') {
        if ($data->{what} eq 'subscription') {
            $response = $controller->remove_subscription(
                $actor,
                $controller->user($data->{userUniqueId}),
                $controller->stream($data->{streamId})
            );
            $response->{user_unique_id} = $data->{userUniqueId};
            $event = 'subscriber:removed';
        } elsif ($data->{what} eq 'authorship') {
            $response = $controller->remove_authorship(
                $actor,
                $controller->user($data->{userUniqueId}),
                $controller->stream($data->{streamId})
            );
            $response->{user_unique_id} = $data->{userUniqueId};
            $event = 'author:removed';
        } elsif ($data->{what} eq 'moderatorship') {
            $response = $controller->remove_moderatorship($actor, $controller->user($data->{userUniqueId}), $stream);
            $response->{user_unique_id} = $data->{userUniqueId};
            $response->{stream_id}      = $data->{streamId};
            if ($data->{eject}) {
                $response->{redirect_to} =
                  $controller->url_for('get_stream', { stream_identifier => $stream->url_name });
            } else {

                # Only send the last supermod check event if we know we're not going to rerender
                my $last_supermod = $self->_find_last_supermod($stream, $controller->user($data->{userUniqueId}));
            }

            $event = 'moderator:removed';
        }
    } elsif ($data->{action} eq 'add') {

        # Get id from text input, find user from it
        my $user = $controller->user($data->{user_id});
        if ($data->{what} eq 'authorship') {
            $response = $controller->grant_authorship($actor, $user, $controller->stream($data->{streamId}));
            delete $response->{authorship};    # We don't need this on the javascript side
            if ($response->{error}) {          # If the user doesn't have moderatorship
                $event = 'author:error:added';
            } else {
                $response->{user_unique_id}   = $user->unique_id;
                $response->{stream_id}        = $data->{streamId};
                $response->{user_common_name} = $user->common_name;

                $event = 'author:added';
            }
        } elsif ($data->{what} eq 'moderatorship') {

            # Get checkbox value
            my $add_other_moderators = $data->{add_other_moderators} == true() ? 1 : 0;

            $response = $controller->add_moderatorship($actor, $user, $controller->stream($data->{streamId}),
                $add_other_moderators);
            if ($response->{error}) {

                # FOR REVIEW: this is a way we could be leaking user unique_id.  Is this a security risk?
                $response->{user_unique_id} = $user->unique_id;
                $event = 'moderator:error:added';
            } else {
                $response->{user_unique_id}   = $user->unique_id;
                $response->{stream_id}        = $data->{streamId};
                $response->{me}               = $actor->id == $user->id ? true() : false();
                $response->{user_common_name} = $user->common_name;
                $response->{allow_add_moderator} =
                  $response->{moderatorship}->allow_add_moderator eq 1 ? true() : false();
                my $last_supermod = $self->_find_last_supermod($stream, $actor);

                $event = 'moderator:added';
            }
            delete $response->{moderatorship};    # We don't need this on the javascript side
        } elsif ($data->{what} eq 'invite') {
            my $inviter = $actor;
            my $invitee = $controller->user($data->{invitee});

            $response = $controller->invite_to_stream($inviter, $invitee, $controller->stream($data->{streamId}));
            if ($response->{error}) {
                $event = 'invite:error:added';
            } else {
                $response->{invitee_unique_id}   = $invitee->unique_id;
                $response->{invitee_common_name} = $invitee->common_name;
                $response->{inviter_unique_id}   = $controller->active_user->unique_id;
                $response->{inviter_common_name} = $controller->active_user->common_name;
                $response->{stream_id}           = $data->{streamId};

                $event = 'invite:added';
            }
        }
    } elsif ($data->{action} eq 'authorize') {
        if ($data->{what} eq 'subscription') {
            $response = $controller->authorize_subscription(
                $actor,
                $controller->user($data->{userUniqueId}),
                $controller->stream($data->{streamId})
            );
            $response->{user_unique_id} = $data->{userUniqueId};
            $event = 'subscriber:authorized';
        } elsif ($data->{what} eq 'authorship') {
            $response = $controller->authorize_authorship(
                $actor,
                $controller->user($data->{userUniqueId}),
                $controller->stream($data->{streamId})
            );
            $response->{user_unique_id} = $data->{userUniqueId};
            $event = 'author:authorized';
        }
    } elsif ($data->{action} eq 'powerup') {
        if ($data->{what} eq 'moderatorship') {
            $response = $controller->add_allow_add_moderator($actor, $controller->user($data->{userUniqueId}), $stream);
            $response->{user_unique_id} = $data->{userUniqueId};

            my $last_supermod = $self->_find_last_supermod($stream, $actor);

            $event = 'moderator:powerup';
        }
    } elsif ($data->{action} eq 'powerdown') {
        if ($data->{what} eq 'moderatorship') {
            $response =
              $controller->remove_allow_add_moderator($actor, $controller->user($data->{userUniqueId}), $stream);
            $response->{user_unique_id} = $data->{userUniqueId};

            if ($data->{reload}) {
                $response->{redirect_to} =
                  $controller->url_for('moderate_stream', { stream_identifier => $stream->url_name });
            } else {

                # Only send the last supermod check event if we know we're not going to rerender
                my $last_supermod = $self->_find_last_supermod($stream, $actor);
            }

            $event = 'moderator:powerdown';
        }
    } elsif ($data->{action} eq 'approve') {
        if ($data->{what} eq 'invite') {
            my $invitee = $controller->user($data->{invitee});
            $response = $controller->approve_invite($controller->active_user, $invitee, $stream);

            if ($response->{error}) {
                $event = 'invite:error:approved';
            } else {
                $event = 'invite:approved';
                $response->{invitee} = $data->{invitee};
            }
        }
    }

    $self->send($response, $event);
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('action')->in(qw/approve powerdown powerup authorize add remove/);
        $v->required('what')->in(qw/invite moderatorship authorship subscription/);
        $v->required('streamId')->like($self->F_UUID);
        $v->optional('userUniqueId')->like($self->F_UUID);
        $v->optional('user_id')->like($self->F_USERID)->size(1, 255);
        $v->optional('invitee')->like($self->F_UUID);
        $v->optional('add_other_moderators')->in(true, false);
        $v->optional('eject')->in(true, false);
        return $v;
    }

    return undef;
}

sub _find_last_supermod {
    my ($self, $stream, $actor) = @_;

    # This is so the JS side can change the UI if no more mods can be removed
    my @mods = $self->controller->app->m->resultset('Stream::Moderator')->search(
        {
            stream              => $stream->id,
            allow_add_moderator => 1,
        }
    );
    if (scalar(@mods) == 1) {
        $self->send(
            {
                user_unique_id => $mods[0]->meritcommons_user->unique_id,
            },
            'moderator:lastsupermod'
        );
        return $mods[0];
    } else {
        $self->send(
            {
                stream_id      => $stream->unique_id,
                active_user_id => $actor->unique_id,
            },
            'moderator:more_than_one_supermod'
        );
    }
}

1;
