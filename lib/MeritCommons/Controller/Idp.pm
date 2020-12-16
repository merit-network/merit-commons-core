#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Idp;

# declare our @ISA
our @ISA;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;
    $self->render(
        destination_name => 'Destination Name',
        message          => "Please log in with your username and password to be redirected to [destination]",
        template         => "idp/login"
    );
}

sub logout {
    my ($self) = @_;
    $self->render(
        destination_name => 'Destination Name',
        message          => "You have been successfully logged out. You will be redirected to [destination] shortly.",
        template         => "idp/logout"
    );
}

1;
