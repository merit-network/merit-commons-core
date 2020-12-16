#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Catchall;

# declare our @ISA
our @ISA;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;
    my $catchall = $self->stash("catchall");

    my $stream = $self->stream($catchall);

    if ($stream) {
        $self->redirect_to('get_stream', { stream_identifier => $catchall });
    } else {
        $self->reply->not_found;
    }
}

1;
