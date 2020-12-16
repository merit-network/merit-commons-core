#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::nav_tree;

use Mojo::Base 'Mojolicious::Command';

has description => "Prints the navigation tree as we know it as intented text\n";
has usage       => "Usage: $0 nav_tree\n";

sub run {
    my ($self, @args) = @_;

    use Data::Dumper;
    local $Data::Dumper::terse = 1;

    # get the admin user!
    my $c = $self->app->build_controller;
    $c->stash(active_user => $c->user($args[0]) || $c->user(1));

    my $tree = $c->generate_nav_tree;

    $self->print_tree($tree, '');
}

sub print_tree {
    my ($self, $tree, $spaces) = @_;

    foreach my $obj (@$tree) {
        if ($obj->{collection}) {
            print "$spaces\[$obj->{common_name}]\n";
            $self->print_tree($obj->{children}, "$spaces    ");
        } else {
            print "$spaces$obj->{title}\n";
        }
    }
}

1;
