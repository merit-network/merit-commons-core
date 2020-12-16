#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::WhatsYourPid;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'text';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;
    $self->send("My pid is $$\n");
}

1;
