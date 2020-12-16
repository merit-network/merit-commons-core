#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::delete_link_collection;

use Mojo::Base 'Mojolicious::Command';

has description => "Delete a specific link collection and the associated links.\n";
has usage       => "Usage: $0 delete_link_collection [LINK COLLECTION IDS]... \n";

sub run {
    my ($self, @link_collection_ids) = @_;

    unless (@link_collection_ids > 0) {
        print $self->usage;
        return;
    }

    foreach my $link_collection_id (@link_collection_ids) {

        # Delete all links.  DBIx will automatically take care of deleting associated records (clicks and collection_members).
        print "Deleting links for collection " . $link_collection_id . "...\n";
        $self->app->m->resultset('Link')->search(
            {
                'collection_members.collection' => $link_collection_id,
            },
            {
                prefetch => ['collection_members']
            }
        )->delete_all;

        print "Deleting link collection...\n";
        my @collections = $self->app->m->resultset('Link::Collection')->search(
            {
                'id' => $link_collection_id
            }
        )->all;

        foreach my $collection (@collections) {
            if ($collection->common_name eq '_top') {
                print "[warn] _top cannot be deleted\n";
            } else {
                $collection->delete;
            }
        }
    }

    print "Done.\n";
}

1;
