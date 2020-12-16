package MeritCommons::Controller::Coins;

use Mojo::Base 'Mojolicious::Controller';

sub default {
    my ($self) = @_;

    if ($self->active_user) {
        $self->render(template => "coins/default");
    } else {
        $self->render(template => "general/welcome");
    }
}

sub transfer {
    my ($self) = @_;

    if ($self->active_user) {
        $self->render(template => "coins/transfer");
    } else {
        $self->render(template => "general/welcome");
    }
}

sub request {
    my ($self) = @_;

    if ($self->active_user) {
        $self->render(template => "coins/request");
    } else {
        $self->render(template => "general/welcome");
    }
}

sub admin {
    my ($self) = @_;

    if ($self->active_user) {
        if ($self->active_user->is_admin) {
            $self->render(template => "coins/admin");
        } else {
            $self->render(template => "not_found");
        }
    } else {
        $self->render(template => "general/welcome");
    }
}

1;
