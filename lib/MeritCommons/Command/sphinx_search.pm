#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::sphinx_search;

use Mojo::Base 'Mojolicious::Command';
use Sphinx::Search;

has description => "Perform a Sphinx search as a user\n";
has usage       => "Usage: $0 sphinx_search [USERNAME] [SEARCH STRING]\n";

sub run {
    my ($self, $username, $search_string) = @_;

    unless ($username && $search_string) {
        print $self->usage;
        return;
    }

    my $user = $self->app->user($username);

    print "Searching for:     " . $search_string . "\n";
    print "Searching as user: " . $user->userid . " (" . $user->common_name . ")\n\n";

    my @messages = $user->search_messages($self->app->sphinx_h, $search_string);
    my @links = $user->search_links($self->app->sphinx_h, $search_string);
    my @streams = $user->search_streams($self->app->sphinx_h, $search_string);
    my @users = $self->app->search_users($self->app->sphinx_h, $search_string);

    print "Messages:\n";
    if (@messages) {
        foreach my $message (@messages) {
            print "\t ID = " . $message->id . ", body = " . $message->body . "\n";
        }
    } else {
        print "\tNo messages found.\n";
    }

    print "Links:\n";
    if (@links) {
        foreach my $link (@links) {
            print "\t SHORT = " . $link->short_loc . ", ID = " . $link->id . ", title = " . $link->title . "\n";
        }
    } else {
        print "\tNo links found.\n";
    }

    print "Users:\n";
    if (@users) {
        foreach my $user (@users) {
            print "\t ID = " . $user->id . ", common_name = " . $user->common_name . "\n";
        }
    } else {
        print "\tNo users found.\n";
    }

    print "Streams:\n";
    if (@streams) {
        foreach my $stream (@streams) {
            print "\t ID = " . $stream->id . ", common_name = " . $stream->common_name . "\n";
        }
    } else {
        print "\tNo streams found.\n";
    }
}

1;
