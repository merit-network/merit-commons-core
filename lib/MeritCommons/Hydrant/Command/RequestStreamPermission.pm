#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::RequestStreamPermission;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/decode_json true false/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    my $controller = $self->controller;
    my $user       = $controller->active_user;

    my $stream = $controller->stream($data->{streamId});

    my $action     = $data->{action};
    my $permission = $data->{permission};
    my $method     = $action . "_" . $permission;

    my $response;
    my $event;

    if ($action eq "add") {
        my ($response_subscription, $response_authorship);
        if ($permission eq "membership") {
            $response_subscription = $controller->add_subscription($controller->active_user, $user, $stream);
            if (!$stream->requires_author_authorization) {
                $response_authorship = $controller->add_authorship($controller->active_user, $user, $stream);
            }

            $response->{stream_id}      = $stream->unique_id;
            $response->{user_is_author} = $user->is_author($stream);
        } else {
            $response = $controller->$method($controller->active_user, $user, $stream);
        }

        if ($response->{error} || ($response_subscription->{error} && $response_authorship->{error})) {
            $event = $permission . ":error";
        } else {
            $event = $permission . ":added";
        }
    } elsif ($action eq "remove") {
        my ($response_subscription, $response_authorship);
        if ($permission eq "membership") {
            $response_subscription = $controller->remove_subscription($controller->active_user, $user, $stream);
            $response_authorship = $controller->remove_authorship($controller->active_user, $user, $stream);
        } else {
            $response = $controller->$method($controller->active_user, $user, $stream);
        }

        if ($response->{error} || ($response_subscription->{error} && $response_authorship->{error})) {
            $event = $permission . ":error";
        } else {
            $event = $permission . ":removed";
        }
    }

    $self->send($response, $event);

}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('action')->in(qw/add remove/);
        $v->required('permission')->in(qw/membership moderatorship authorship subscription/);
        $v->required('streamId')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
