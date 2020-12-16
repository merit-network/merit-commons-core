#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::list_keys;

use MeritCommons::KeyManager;
use Mojo::Base 'Mojolicious::Command';
use File::Find;

has description => "Show all stored keys\n";
has usage       => "Usage: $0 list known keys\n";

sub run {
    my ($self, @args) = @_;

    my $m = $self->app->m;

    foreach my $user ($m->resultset('User')->all) {
        if ($user->get_column('public_key')) {
            my $km = $user->public_key;
            printf("%-38s (%39s)\n", $km->who, $km->fingerprint);
        }
    }
}

1;

