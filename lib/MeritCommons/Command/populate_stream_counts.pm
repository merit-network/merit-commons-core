#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::populate_stream_counts;

use Mojo::Base 'Mojolicious::Command';

has description => "Populates the stream moderator, subscriber, and author counts per stream\n";
has usage       => "Usage: $0 populate_stream_counts\n";

sub run {
    my ($self) = @_;
    foreach my $stream ($self->app->m->resultset('Stream')->all) {
        print "[info] populating " . $stream->common_name . "\n";
        $stream->subscriber_count($stream->subscribers->count);
        $stream->moderator_count($stream->moderators->count);
        $stream->author_count($stream->authors->count);
        $stream->update;
    }
    print "[info] done.\n";
}

1;
