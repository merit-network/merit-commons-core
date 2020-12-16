#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::add_link_csv;

use Mojo::Base 'Mojolicious::Command';
use Text::CSV;

has description => "Add a bunch of links to the MeritCommons System.\n";
has usage       => "Usage: $0 add_link_csv [CSV]\n";

sub run {
    my ($self, $csv_file) = @_;
    unless ($csv_file) {
        print $self->usage;
        return;
    }

    my $csv = Text::CSV->new();
    open my $fh, '<', $csv_file or print "Ain't nobody got time for that: $!\n";

    # bye first row.
    <$fh>;

    foreach my $role_name (qw/employee faculty student research finaid/) {
        unless ($self->app->m->resultset('User::Role')->find({ common_name => $role_name })) {
            print "[info] couldn't find user role '$role_name', adding.\n";
            $self->app->m->resultset('User::Role')->create(
                {
                    common_name => $role_name,
                }
            );
        }
    }

    # Get the MeritCommons System user
    my $actor = $self->app->user(1);

    while (my $row = $csv->getline($fh)) {
        my ($role_name, $link_category, $link_subcategory, $link_label, $link_url, $target, $keywords) =
          (lc($row->[0]), $row->[1], $row->[2], $row->[3], $row->[4], $row->[5], $row->[6]);
        next unless $link_url;

        my $role = $self->app->m->resultset('User::Role')->find({ common_name => $role_name });

        # create primary category!
        my ($category, $subcategory);

        if ($link_category eq '') {

            # default to the root collection if none is defined
            $category = $self->app->link_collection('_top');
        } else {
            unless ($category = $self->app->link_collection($link_category)) {
                $category = $self->app->add_link_collection($actor, $link_category);
                print "[info] created category $link_category\n";
            }
        }

        unless ($subcategory = $self->app->link_collection($link_subcategory, $category)) {
            if ($link_subcategory) {
                $subcategory = $self->app->add_link_collection($actor, $link_subcategory, $category->id);
                print "[info] created subcategory $link_subcategory in parent category $link_category\n";
            }
        }

        # create the link in the right place.
        my $link;
        if ($subcategory) {
            $link = $self->app->add_link($actor, $link_url, $link_label, 1, $target, 'system', $keywords);
            $self->app->add_link_to_collection($link, $subcategory);
            print "[info] added link $link_label to category $link_subcategory\n";
        } else {

            # just put the link in the parent category
            $link = $self->app->add_link($actor, $link_url, $link_label, 1, $target, 'system', $keywords);
            $self->app->add_link_to_collection($link, $category);
            print "[info] added link $link_label to category $link_category\n";
        }

        # add the link role if set
        $link->link_roles->create({ role => $role }) if $role;
    }
}

1;
