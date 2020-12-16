# MeritCommons Portal
# Copyright 2015 Wayne State University
# All Rights Reserved

package MeritCommons::Hydrant::Command::RemoveProfilePicture;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/encode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;

    my $c = $self->controller;
    my $response;

    if (my $user = $c->active_user) {
        if ($arg->{user_id}) {
            if ($arg->{user_id} eq $user->userid || $user->is_admin) {
                my $user_profile = $c->m->resultset('User')->search(
                    {
                        userid => $arg->{user_id},
                    }
                )->first;

                if ($user_profile) {
                    $user_profile->profile_picture->delete;
                    $user_profile->update;
                    $response->{success} = 1;
                } else {
                    $response->{error} = "Could not find user: " . $arg->{user_id};
                }
            } else {
                $response->{error} = "You do not have permission to remove this user's profile picture";
            }
        } else {
            $user->profile_picture->delete;
            $user->update;
            $response->{success} = 1;
        }
    } else {
        $response->{error} = "No active user.";
    }

    $self->send($response);
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->optional('user_id')->like($self->F_USERID);
        return $v;
    }

    return undef;
}

1;
