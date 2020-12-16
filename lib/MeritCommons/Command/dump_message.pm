#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::dump_message;

use Mojo::Base 'Mojolicious::Command';
use Data::TreeDumper;

has description => "Dumps a message.\n";
has usage       => "Usage: $0 dump_message [MESSAGE]\n";

sub run {
    my ($self, $message_id) = @_;

    if ($message_id) {
        my $message = $self->app->message($message_id);
        if ($message) {
            my %data = $message->get_columns();
            print DumpTree(\%data);
        } else {
            print "[error]: message $message_id not found\n";
        }
    } else {
        die $self->usage;
    }
}

1;
