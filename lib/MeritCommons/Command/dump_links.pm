#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::dump_links;

use Mojo::Base 'Mojolicious::Command';

has description => "Serialize system links into a file\n";
has usage       => "Usage: $0 dump_links [FILE]\n";

sub run {
    my ($self, $file) = @_;

    unless ($file) {
        die $self->usage;
    }

    if (-e $file) {
        die "[error] $file exists; dump_links wants to create a file of its own, not use your old crusty file.  eew.\n";
    }

    open my $fh, '>', $file or die "Can't open $file for writing: $!\n";

    my $i = 0;
    foreach my $link ($self->app->m->resultset('Link')->search({ type => 'system' })) {
        $i++;
        my @collections;
        foreach my $collection ($link->collections) {

            # get the full path of the collection
            my @path = ('"' . $collection->common_name . '"');
            while (my $parent = $collection->parent) {
                unshift(@path, '"' . $parent->common_name . '"');
                $collection = $parent;
            }
            push(@collections, join('.', @path));
        }

        print $fh join(" ",
            "\"@{[$link->href]}\"", "\"@{[$link->title]}\"", $link->target,
            join(',', map { $_->common_name } $link->roles)),
          "::", join(',', @collections) . "\n";
    }

    close $fh;

    print "[done]: $i links dumped to $file\n";
}

1;
