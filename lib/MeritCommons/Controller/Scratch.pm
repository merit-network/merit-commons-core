#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

# A simple scratch space controller for testing widgets + layouts
package MeritCommons::Controller::Scratch;

use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    if ($self->app->mode eq "development") {

        $self->render('general/scratch');

    } else {
        $self->reply->not_found;
    }
}

1;
