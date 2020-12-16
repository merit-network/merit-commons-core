#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::delete_all_link_collections;

use Mojo::Base 'Mojolicious::Command';

has description => "Delete all link collections and the associated links.\n";
has usage       => "Usage: $0 delete_all_link_collections\n";

sub run {
    my ($self) = @_;

    # Delete all links.  DBIx will automatically take care of deleting associated records (clicks and collection_members).
    print "Deleting links...\n";
    $self->app->m->resultset('Link')->search(
        {
            'collection_members.id' => { '<>' => undef }
        },
        {
            prefetch => ['collection_members']
        }
    )->delete_all;

    print "Deleting link collections...\n";
    $self->app->m->resultset('Link::Collection')->search({ 'common_name' => { '!=' => '_top' } })->delete_all;

    print "Done.\n";
}

1;
