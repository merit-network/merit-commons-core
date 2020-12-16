#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::user_top_links;

use Mojo::Base 'Mojolicious::Command';

has description => "Set a user's attribute\n";
has usage       => "Usage: $0 user_top_links [USER] [COUNT]\n";

sub run {
    my ($self, $username, $count) = @_;
    unless ($username) {
        print $self->usage;
        return;
    }

    my $user = $self->app->user($username);

    unless ($user) {
        print "Can't find user $username!\n";
        return;
    }

    $count = 10 unless $count;
    foreach my $link ($user->most_clicked_links($count)) {
        print $link->{title} . ": " . $link->{href} . " (" . $link->{click_count} . ")\n";
    }
}

1;
