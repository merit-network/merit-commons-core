#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::add_link_collection;

use Mojo::Base 'Mojolicious::Command';

has description => "Add a link collection\n";
has usage       => "Usage: $0 add_link_collection [COMMON_NAME] [PARENT] \n";

sub run {
    my ($self, $common_name, $parent) = @_;

    unless ($common_name && $parent) {
        print $self->usage;
        return;
    }

    $parent = $self->app->link_collection($parent);

    if ($parent) {

        # Get the MeritCommons System user
        my $actor = $self->app->user(1);

        if (my $collection = $self->app->add_link_collection($actor, $common_name, $parent->id)) {

            if ((ref $collection) eq 'HASH') {
                print '[error] ' . $collection->{error} . "\n";
            } else {
                print '[info] created category ' . $common_name . ' [' . $collection->id . "]\n";
            }
        } else {
            print "[error] category could not be created\n";
        }
    } else {
        print "Parent link collection could not be found\n";
    }
}

1;
