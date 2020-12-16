#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::update_link;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long;

has description => "Update link in the MeritCommons System.\n";
has usage       => "Usage: $0 update_link [SHORT_LOC] [OPTIONS]\n" . "\t --href=[HREF]\n" .
  "\t --title=[TITLE]\n" . "\t --collections=[COLLECTION1,COLLECTION2,...]\n" . "\t --roles=[ROLE1,ROLE2,...]\n" .
  "\t --target=[TARGET STRING]\n" . "\t --keywords=[KEYWORDS STRING]\n" . "\t --clear-collections\n";

sub run {
    my ($self, $link_short_loc) = @_;

    my ($href, $title, $roles, $collection_ids, $keywords, $target);
    my $result = GetOptions(
        "href=s"            => \$href,
        "title=s"           => \$title,
        "collections=s"     => \$collection_ids,
        "roles=s"           => \$roles,
        "keywords=s"        => \$keywords,
        "target=s"          => \$target,
        "clear-collections" => \my $clear_collections,
    );

    if (!$link_short_loc ||
        !($link_short_loc =~ /^[\d\w]+$/) ||
        (!$href && !$title && !$roles && !$collection_ids && !$keywords && !$target && !$clear_collections)) {
        print $self->usage;
        return;
    }

    my $link = $self->app->m->resultset('Link')->search({ short_loc => $link_short_loc })->first;

    if ($link) {
        print "[@{[$link->title]}]\n";
    } else {
        print "Link $link_short_loc does not exist!\n";
        return;
    }

    if ($target) {
        print "Updating target: " . $target . "\n";
        $link->target($target);
    }

    if ($href) {
        print "Updating href: " . $href . "\n";
        $link->href($href);
    }

    if ($title) {
        print "Updating title: " . $title . "\n";
        $link->title($title);
    }

    if ($collection_ids) {
        print "Updating collections: " . $collection_ids . "\n";

        # purge existing collections.
        foreach my $link_collection_member ($link->collection_members) {
            $link_collection_member->delete;
        }

        # add the new collections
        foreach my $collection_id (split /\s*,\s*/, $collection_ids) {
            my $collection = $self->app->link_collection($collection_id);

            if ($collection) {
                $self->app->add_link_to_collection($link, $collection);
            }
        }
    } elsif ($clear_collections) {

        # purge existing collections.
        foreach my $link_collection_member ($link->collection_members) {
            print "Removing link from collection: " . $link_collection_member->collection->common_name . "\n";
            $link_collection_member->delete;
        }
    }

    if ($keywords) {
        print "Updating keywords: " . $keywords . "\n";
        $link->keywords($keywords);
    }

    if ($roles) {
        foreach my $link_role ($link->link_roles) {
            print "Deleting role: " . $link_role->role->common_name . "\n";
            $link_role->delete;
        }

        foreach my $role_name (split(",", $roles)) {
            my $role = $self->app->m->resultset('User::Role')->search({ common_name => $role_name })->first;

            # create by default.
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

    $link->update;
    $self->app->delete_link_index($link);
    $self->app->add_link_index($link);
}

1;
