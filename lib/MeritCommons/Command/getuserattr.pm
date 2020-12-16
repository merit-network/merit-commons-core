#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::getuserattr;

use Mojo::Base 'Mojolicious::Command';

has description => "Set a user's attribute\n";
has usage       => "Usage: $0 getuserattr [USER] [ATTR]\n";

sub run {
    my ($self, $username, $attr) = @_;
    unless ($username && $attr) {
        print $self->usage;
        return;
    }

    my $user = $self->app->user($username);

    unless ($user) {
        print "Can't find user $username!\n";
        return;
    }

    my @get = $user->$attr;

    if (!$get[0]) {
        print "$attr empty.\n";
    } else {
        print "$attr => " . join(', ', @get) . "\n";
    }
}

1;
