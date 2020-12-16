#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::add_link;

use Mojo::Base 'Mojolicious::Command';

has description => "Add a link to the MeritCommons System.\n";
has usage       => "Usage: $0 add_link [HREF] [TITLE] [TARGET] [LINK_COLLECTION_IDS] [ROLES]\n";

sub run {
    my ($self, $href, $title, $target, $link_collection_id, $roles) = @_;
    unless ($href && $title && $target) {
        print $self->usage;
        return;
    }

    # Get the MeritCommons System user
    my $actor = $self->app->user(1);

    my $link = $self->app->add_link($actor, $href, $title, 1, $target, 'system');

    if ($link->{error}) {
        print "$link->{error}\n";
    } else {
        print "Created link " . $link->id . ", short code: " . $link->short_loc . "\n";

        # add the new collections
        if ($link_collection_id) {
            foreach my $collection_id (split /,/, $link_collection_id) {
                my $collection = $self->app->link_collection($collection_id);

                if ($collection) {
                    $self->app->add_link_to_collection($link, $collection);
                } else {
                    print "Collection $collection_id not found\n";
                }
            }
        }

        # add roles
        if ($roles) {
            foreach my $role_name (split(/,/, $roles)) {
                my $role = $self->app->m->resultset('User::Role')->search({ common_name => $role_name })->first;

                # create role by default.
                unless ($role) {
                    $role = $self->app->m->resultset('User::Role')->create({ common_name => $role_name });
                }

                print 'Adding role: ' . $role->common_name . "\n";

                $link->link_roles->create(
                    {
                        role => $role
                    }
                );
            }
        }
    }
}

1;
