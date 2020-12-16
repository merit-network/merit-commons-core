#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::set_url_names;

use Mojo::Base 'Mojolicious::Command';
use File::Find;

has description => "Set url_name field from common_name field for streams\n";
has usage       => "Usage: $0 set_url_names\n";

sub run {
    my ($self, @args) = @_;

    my $m = $self->app->m;

    foreach my $stream ($m->resultset('Stream')->all) {
        my $name = $self->app->stream_generate_url_name($stream->common_name);
        $stream->url_name($name);
        $stream->update;
        print "[info]: set " . $stream->common_name . "'s url_name to $name\n";
    }

}

1;

