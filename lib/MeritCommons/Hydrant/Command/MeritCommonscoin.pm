# MeritCommons Portal
# Copyright 2015 Wayne State University
# All Rights Reserved

package MeritCommons::Hydrant::Command::MeritCommonscoin;

use Mojo::Base qw/MeritCommons::Hydrant::Command/;
use Mojo::JSON qw/decode_json true false/;

has subcommands         => 1;
has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data, $command) = @_;

    my $c = $self->controller;

    if ($command) {
        if ($self->can($command)) {
            $self->send($self->$command($data));
        } else {
            $self->send("Invalid command: $command");
        }
    } else {
        $self->send("No command specified.");
    }
}

sub balance {
    my ($self, $data) = @_;

    my $c = $self->controller;

    if ($data->{user_id}) {
        if ($c->active_user->is_admin || $data->{user_id} == $c->active_user->id) {
            my $user = $c->m->resultset('User')->find({ user_id => $data->{user_id} });
            if ($user) {
                return { balanace => $user->meritcommonscoin_balance };
            } else {
                return { error => "User ID provided does not exist." };
            }
        } else {
            return { error => "You do not have permission to view this user's balance." };
        }
    } else {
        return { balanace => $c->active_user->meritcommonscoin_balance };
    }
}

sub transactions {
    my ($self, $data) = @_;

    my $c = $self->controller;

    if ($data->user_id) {
        if ($c->active_user->is_admin || $data->{user_id} == $c->active_user->id) {

            # return user's transactions;
        } else {
            return { error => "You do not have permission to view this user's transactions." };
        }
    } else {

        # return active user's transactions
    }
}

sub transfer {
    my ($self, $data) = @_;

    my $c = $self->controller;

    if ($data->{amount}) {    # check if we've been passed an amount
        if ($data->{recipient_id}) {    # check if we've been passed a recipient
            return $c->transfer_coins($c->active_user, $c->active_user, $data->{recipient_id}, $data->{amount});
        } else {
            return { error => "A recipient was not provided" };
        }
    } else {
        return { error => "An amount was not provided." };
    }
}

sub request {
    my ($self, $data) = @_;

    my $c = $self->controller;

    if ($data->{amount}) {
        if ($data->{reason}) {
            return $c->request_coins($c->active_user, $data->{amount}, $data->{reason});
        } else {
            return { error => "A reason was not provided." };
        }
    } else {
        return { error => "An amount was not provided." };
    }
}

sub respond {
    my ($self, $data) = @_;

    my $c = $self->controller;
    my $response;

    if ($c->active_user->is_admin) {
        if ($data->{request_id}) {
            if (defined $data->{approve}) {
                $response = $c->respond_to_coin_request($c->active_user, $data->{request_id}, $data->{approve});
            } else {
                $response->{error} = "A response to the request was not provided.";
            }
        } else {
            $response->{error} = "A request id was not provided.";
        }
    } else {
        $response->{error} = "You do not have permission to do this.";
    }

    # need to send back the request_id for our ui
    $response->{request_id} = $data->{request_id};

    return $response;
}

sub credit {
    my ($self, $data) = @_;

    my $c = $self->controller;

    if ($c->active_user->is_admin) {
        if ($data->{recipient_id}) {
            if ($data->{amount}) {
                return $c->credit_coins($c->active_user, $data->{amount}, $data->{recipient_id});
            } else {
                return { error => "An amount was not specified." };
            }
        } else {
            return { error => "A recipient was not provided." };
        }
    } else {
        return { error => "You do not have permission to do this." };
    }
}

sub validate {
    my ($self, $arg, $command) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        if ($command eq "balance") {
            $v->optional('user_id')->like($self->F_USERID);
        } elsif ($command eq "transactions") {
            $v->optional('user_id')->like($self->F_USERID);
        } elsif ($command eq "transfer") {
            $v->required('recipient_id')->like($self->F_UUID);
            $v->required('amount')->like($self->F_INT);
        } elsif ($command eq "request") {
            $v->required('amount')->like($self->F_INT);
            $v->required('reason');
        } elsif ($command eq "respond") {
            $v->required('request_id')->like($self->F_INT);
            $v->required('approve')->like($self->F_INT);
        } elsif ($command eq "credit") {
            $v->required('recipient_id')->like($self->F_UUID);
            $v->required('amount')->like($self->F_INT);
        }

        return $v;
    }

    return undef;
}

1;
