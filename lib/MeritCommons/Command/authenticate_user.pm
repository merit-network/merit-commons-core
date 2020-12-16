#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::authenticate_user;

use Mojo::Base 'Mojolicious::Command';

has description => "Authenticate an MeritCommons User against the configured authentication_profile\n";
has usage       => "Usage: $0 authenticate_user [UID] [PASSWORD]\n";

sub run {
    my ($self, $username, $password) = @_;
    my $user = $self->app->authenticate_user($username, $password);
    if ($user) {
        print "User " . $user->userid . " authenticated successfully.\n";
    } else {
        print "Invalid login\n";
    }
}

1;
