#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::reprocess_message;

use MeritCommons::Content;
use Mojo::Base 'Mojolicious::Command';

has description => "Re-runs a message's original body through the content driver stack, and updates the body\n";
has usage       => "Usage: $0 reprocess_message [MESSAGE_ID]\n";

sub run {
    my ($self, $message_id) = @_;
    unless ($message_id) {
        die $self->usage;
    }

    if (my $message = $self->app->message($message_id)) {
        my $content = MeritCommons::Content->new($message);

        # things will complain about these...
        $content->attempted_streams([]);
        $content->streams([]);
        $content->body($message->original_body);

        $content = $self->app->cd_inbound($content, $message->submitter);
        $message->body($content->body);
        $message->update;
        print "Message '$message_id' reprocessed.\n";
    } else {
        print "Message '$message_id' not found.\n";
    }
}

1;
