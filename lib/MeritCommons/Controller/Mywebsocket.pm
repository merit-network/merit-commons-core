#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Mywebsocket;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Mojo::File;

#
# return the websocket we are.
#
sub default {
    my ($self) = @_;

    if ($self->active_user) {
        if (-e '/var/tmp/meritcommons_myws_override') {
            my $ws_address = Mojo::File->new('/var/tmp/meritcommons_myws_override')->slurp;
            $self->render(text => $ws_address);
        } else {
            $self->render(text => $self->app->config->{advertised_websocket});
        }
    } else {
        $self->render(text => '');
    }
}

1;
