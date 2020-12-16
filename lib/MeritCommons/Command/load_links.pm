#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::load_links;

use Mojo::Base 'Mojolicious::Command';

has description => "Load a link dump file into meritcommons\n";
has usage       => "Usage: $0 load_links [FILE]\n";

sub run {
    my ($self, $file) = @_;

    unless ($file) {
        die $self->usage;
    }

    unless (-e $file) {
        die "[error] $file does not exist; load_links is having an existential crisis now.\n";
    }

    open my $fh, '<', $file or die "Can't open $file for reading: $!\n";

    # Get the MeritCommons System user
    my $actor = $self->app->user(1);

    my $i = 0;
    while (my $line = <$fh>) {
        chomp($line);
        my ($link_definition, $collection_trees) = split(/\s*::\s*/, $line);
        my ($href, $title, $target, $roles) = $link_definition =~ /^"([^"]+)" "([^"]+)" ([^\s]+)\s*([^\s]*)$/;

        my $link = $self->app->add_link($actor, $href, $title, 1, $target, 'system');

        if ($link->{error}) {
            print "$link->{error}\n";
        } else {
            $i++;

            # add roles
            if ($roles) {
                foreach my $role_name (split(/,/, $roles)) {
                    my $role = $self->app->m->resultset('User::Role')->search({ common_name => $role_name })->first;

                    # create role by default.
                    unless ($role) {
                        $role = $self->app->m->resultset('User::Role')->create({ common_name => $role_name });
                    }

                    $link->link_roles->create(
                        {
                            role => $role
                        }
                    );
                }
            }

            foreach my $collection_tree (split(',', $collection_trees)) {

                # get rid of quotes
                $collection_tree =~ s/\"//g;

                my $collection;

                # walk the collection tree, creating or finding as we go along.
                foreach my $collection_name (split(/\./, $collection_tree)) {
                    unless (ref($collection)) {
                        unless ($collection =
                            $self->app->m->resultset('Link::Collection')->search({ common_name => $collection_name })
                            ->first) {
                            $collection = $self->app->add_link_collection($actor, $collection_name);
                        }
                    } else {
                        my $child_collection;
                        unless ($child_collection =
                            $collection->collections->search({ common_name => $collection_name })->first) {
                            $child_collection =
                              $self->app->add_link_collection($actor, $collection_name, $collection->id);
                        }
                        $collection = $child_collection;
                    }
                }

                # $collection should now be the last one in the tree, i.e. the one we're going to add the link to!
                $self->app->add_link_to_collection($link, $collection);
            }
        }
    }

    close $fh;

    print "[done]: $i links loaded from $file\n";
}

1;
