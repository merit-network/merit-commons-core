#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Invite;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/decode_json true false/;
has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    my $controller = $self->controller;

    my $response;
    my $event;

    my $action = $data->{action};
    my $stream = $controller->stream($data->{streamId});

    if ($action eq "invite") {
        my $inviter = $data->{inviterId} ? $controller->user($data->{inviterId}) : $controller->active_user;
        my $invitees = $data->{invitees};

        foreach my $unique_id (@$invitees) {
            if (my $invitee = $controller->user($unique_id)) {
                if (!$invitee->is_subscriber($stream)) {
                    $response = $controller->invite_to_stream($inviter, $invitee, $stream);
                    if ($response->{error}) {
                        $event = 'invite:error';
                    } else {
                        $event = 'invite:added';
                    }
                } else {
                    $event = 'invite:error';
                    $response->{error} = $invitee->common_name . ' is already a member of ' . $stream->common_name;
                }
            } else {
                $event = 'invite:error';
                $response->{error} = 'Invitee not found';
            }

            # original invitee uuid needs to be returned for dom rendering, even if it doesn't exist
            $response->{invitee} = $unique_id;

            $self->send($response, $event);
        }
    } elsif ($action eq "respond") {
        my $invitee = $controller->active_user;

        my $invite;
        if ($invite = $controller->invite($invitee, $stream)) {
            my $inviter = $invite->inviter;

            if ($invite->approved) {
                if ($data->{response} eq "accept") {

                    # this is a moderator approved invite, we dont need to do any "adding", we just need to make sure
                    # that whatever adds this account can.
                    if ($inviter->can_moderate($stream)) {
                        $controller->grant_subscription(
                            {
                                actor             => $inviter,
                                user              => $invitee,
                                stream            => $stream,
                                allow_history     => 1,
                                mute_notification => 1,
                            }
                        );
                    } else {

                        # if the inviter isn't a moderator, then use MeritCommons System user
                        $controller->grant_subscription(
                            {
                                actor             => $controller->user(1),
                                user              => $invitee,
                                stream            => $stream,
                                allow_history     => 1,
                                mute_notification => 1,
                            }
                        );
                    }

                    # if the inviter is an author of the stream, grant authorship
                    if (!$stream->requires_author_authorization || $inviter->is_author($stream)) {
                        $controller->grant_authorship(
                            {
                                actor             => $inviter,
                                user              => $invitee,
                                stream            => $stream,
                                allow_edit        => 1,
                                mute_notification => 1,
                            }
                        );
                    }
                }

                $response = $controller->respond_to_invite($invitee, $stream, $data->{response});
                $response->{user_is_subscriber}                = $invitee->is_subscriber($stream);
                $response->{stream_id}                         = $stream->unique_id;
                $response->{requires_subscriber_authorization} = $stream->requires_subscriber_authorization;
                $response->{user_is_author}                    = $invitee->is_author($stream);
            } else {
                if ($inviter->can_moderate($stream)) {
                    $controller->grant_subscription($inviter, $invitee, $stream);
                    $controller->grant_authorship($inviter, $invitee, $stream) if $inviter->is_author($stream);

                    $response = $controller->respond_to_invite($invitee, $stream, $data->{response});

                    $response->{user_is_subscriber}                = $invitee->is_subscriber($stream);
                    $response->{stream_id}                         = $stream->unique_id;
                    $response->{requires_subscriber_authorization} = $stream->requires_subscriber_authorization;
                    $response->{user_is_author}                    = $invitee->is_author($stream);
                } else {
                    $response->{error} = "Invite has not been approved by a moderator";
                }
            }
        } else {
            $response->{error} =
              "An invite to " . $stream->common_name . " for " . $invitee->common_name . " does not exist";
        }

        if ($response->{error}) {
            $event = 'invite:responded:error';
        } else {
            $event = 'invite:responded';
        }

        $self->send($response, $event);
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('action')->in(qw/invite respond/);
        $v->required('streamId')->like($self->F_UUID);
        $v->optional('inviterId')->like($self->F_UUID);
        $v->optional('invitees')->like($self->F_UUID);
        $v->optional('response')->like($self->F_WORD);
        return $v;
    }

    return undef;
}

1;

