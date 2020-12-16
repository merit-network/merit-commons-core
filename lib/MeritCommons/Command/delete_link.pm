#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::delete_link;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long;

has description => "Delete a link.\n";
has usage       => "Usage: $0 delete_link [SHORT_LOC]\n";

sub run {
    my ($self, $link_short_loc) = @_;

    if (!$link_short_loc) {
        print $self->usage;
        return;
    }

    my $link = $self->app->m->resultset('Link')->search({ short_loc => $link_short_loc })->first;

    if ($link) {
        $self->app->delete_link($link);
        print "Deleted link $link_short_loc\n";
    } else {
        print "Link $link_short_loc does not exist!\n";
    }
}

1;
