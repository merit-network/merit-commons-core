#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::sphinx_rebuild;

use Mojo::Base 'Mojolicious::Command';
use Sphinx::Search;

has description => "Rebuild the Sphinx database\n";
has usage       => "Usage: $0 sphinx_rebuild\n";

sub run {
    my ($self) = @_;

    print "Deleting all indexes\n";
    my %results = $self->app->sphinx_delete_all_indexes();

    foreach my $key (keys %results) {
        print "\t$key ... " . $results{$key} . " records\n";
    }

    print "Rebuilding indexes\n";

    #  Rebuild links
    my $link_count = $self->app->sphinx_rebuild_link_indexes();
    print "\tlinks ... " . $link_count . " records\n";

    #  Rebuild messages
    my $message_count = $self->app->sphinx_rebuild_message_indexes();
    print "\tmessages ... " . $message_count . " records\n";

    #  Rebuild users
    my $user_count = $self->app->sphinx_rebuild_user_indexes();
    print "\tusers ... " . $user_count . " records\n";

    #  Rebuild streams
    my $stream_count = $self->app->sphinx_rebuild_stream_indexes();
    print "\tstreams ... " . $stream_count . " records\n";
}

1;
