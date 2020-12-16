#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::user_info;

use Mojo::Base 'Mojolicious::Command';
use File::Find;
use Text::Wrap;

has description => "Show detailed information about a user.\n";
has usage       => "Usage: $0 user_info [USER]\n";

sub run {
    my ($self, @args) = @_;

    my $user;
    unless ($user = $self->app->user($args[0])) {
        print $self->usage;
        return;
    }

    print $self->app->render_user_info_string($user);
}

1;

