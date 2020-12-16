#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::rename_stream;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;

has description => "Rename an existing stream\n";
has usage       => "Usage: $0 rename_stream [UNIQUE_ID] [NEW_NAME]\n";

sub run {
    my ($self, $stream_name, $new_name) = @_;

    unless ($stream_name && $new_name) {
        print $self->usage;
        return;
    }

    my $stream;
    unless ($stream = $self->app->stream($stream_name)) {
        print "Can't find stream '$stream_name'\n";
        return;
    }

    if ($stream->common_name !~ /^_/) {
        $stream->common_name($new_name);
        $stream->update;

        print "[info] '$stream_name' renamed to '$new_name'\n";
    } else {
        print "Stream " .
          $stream->common_name . " is a system, notification, or inbox stream, and cannot be renamed.\n";
    }
}

1;
