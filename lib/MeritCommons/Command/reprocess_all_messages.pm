#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::reprocess_all_messages;

use MeritCommons::Content;
use Mojo::Base 'Mojolicious::Command';

has description =>
  "Re-runs all messages in the system's original body through the content driver stack, and updates the body\n";
has usage => "Usage: $0 reprocess_all_messages\n";

sub run {
    my ($self) = @_;

    foreach my $message ($self->app->m->resultset('Stream::Message')->all) {
        my $content = MeritCommons::Content->new($message);

        # things will complain about these...
        $content->attempted_streams([]);
        $content->streams([]);
        $content->body($message->original_body);

        $content = $self->app->cd_inbound($content, $message->submitter);
        $message->body($content->body);
        $message->update;
        print "Message '@{[$message->unique_id]}' reprocessed.\n";
    }
}

1;
