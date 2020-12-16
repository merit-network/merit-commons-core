#    MeritCommons Portal
#    Copyright 2017 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::clear_link_cache;

use Mojo::Base 'Mojolicious::Command';

has description => "Remove cached link structures\n";
has usage       => "Usage: $0 clear_link_cache\n";

sub run {
    my ($self) = @_;

    my $rs = $self->app->m->resultset('Session')->search({ expire_time => { '>=', (time + 600) } });
    my $i = 0;
    while (my $session = $rs->next) {
        $session->nav_tree_reload_cache(1);
        $session->nav_tree_json_reload_cache(1);
        $i++;
    }
    
    print "[clear_link_cache] cache cleared for $i sessions\n";
}

1;
