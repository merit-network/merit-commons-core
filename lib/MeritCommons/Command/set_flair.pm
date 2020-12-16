#    MeritCommons Portal
#    Copyright 2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::set_flair;

use Mojo::Base 'Mojolicious::Command';

has description => "Set a user's flair, defaults to whatever's in the 'organization' attribute\n";
has usage       => "Usage: $0 set_flair [USER] [FLAIR STRING]\n";

sub run {
    my ($self, $userid, @flair) = @_;

    if (my $user = $self->app->user($userid)) {
        $user->flair(scalar @flair ? join(' ', @flair) : $user->organization);
        print "Set flair for @{[$user->userid]} to '@{[$user->flair]}'\n";
    } else {
        print $self->usage;
    }
}

1;
