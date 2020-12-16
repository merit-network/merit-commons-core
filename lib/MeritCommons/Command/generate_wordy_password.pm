#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::generate_wordy_password;

use Mojo::Base 'Mojolicious::Command';

has description => "Generate a random password from numbers and dictionary words.\n";
has usage       => "Usage: $0 generate_wordy_password [WORDCOUNT] [NUMCOUNT] [WORDLEN] [DELIM]\n";

sub run {
    my ($self, $words, $numbers, $word_maxlen, $delim) = @_;

    # it's not my defaults. (buh dum pum)
    $words       ||= 2;
    $numbers     ||= 1;
    $word_maxlen ||= 4;
    $delim       ||= '-';

    print $self->app->generate_wordy_password($words, $numbers, $word_maxlen, $delim) . "\n";
}

1;
