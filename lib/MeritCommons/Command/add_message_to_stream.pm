#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::add_message_to_stream;

use Mojo::Base 'Mojolicious::Command';

has description => "Add an existing message to a stream\n";
has usage       => "Usage: $0 add_message_to_stream [MESSAGE] [STREAM] \n";

sub run {
    my ($self, $message, $stream) = @_;

    $message = $self->app->message($message);
    $stream  = $self->app->stream($stream);

    unless ($message) {
        warn "[fatal]: message not found\n";
        die $self->usage;
    }

    unless ($stream) {
        warn "[fatal]: stream not found\n";
        die $self->usage;
    }

    foreach my $mstr ($message->streams) {
        if ($mstr->id == $stream->id) {
            print "[info]: message @{[$message->unique_id]} is already in stream @{[$stream->common_name]}\n";
            exit 0;
        }
    }

    $self->app->m->resultset('Stream::MessageStream')->create(
        {
            stream  => $stream->id,
            message => $message->id,
        }
    );

    print "[info]: added message @{[$message->unique_id]} to stream @{[$stream->common_name]}\n";
}

1;
