#    MeritCommons Portal
#    Copyright 2013-2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::link_info;

use Mojo::Base 'Mojolicious::Command';
use File::Find;
use Text::Wrap;

has description => "Show link information.\n";
has usage       => "Usage: $0 link_info [short_loc]\n";

sub run {
    my ($self, @args) = @_;

    my $link = $self->app->m->resultset('Link')->search({ short_loc => $args[0] })->first;
    unless ($link) {
        my @links = $self->app->m->resultset('Link')->search({ title => join(' ', @args) });
        if (scalar(@links) > 1) {
            print "More than one link found matching '@{[join(' ', @args)]}', did you mean:\n";
            foreach my $link (@links) {
                print "  @{[$link->title]} (@{[$link->short_loc]})\n";
            }
            exit;
        } elsif (scalar(@links) == 1) {
            $link = $links[0];
        }
    }

    if ($link) {
        print "id: @{[$link->id]}\n";
        print "title: @{[$link->title]}\n";
        print "href: @{[$link->href]}\n";
        print "short_loc: @{[$link->short_loc]}\n";
        print "target: @{[$link->target]}\n";
        print "keywords: @{[$link->keywords]}\n" if $link->keywords;
        print "collections: [" . join(', ', map { $_->common_name . " (" . $_->id . ")" } $link->collections) . "]\n";
        print "roles: [" . join(', ', map { $_->common_name . " (" . $_->id . ")" } $link->roles) . "]\n";
    } else {
        print "[error]: no links found!\n";
    }
}

1;

