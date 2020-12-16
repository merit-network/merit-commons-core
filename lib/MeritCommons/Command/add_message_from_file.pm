#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::add_message_from_file;
use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use MeritCommons::Content;

use Mojo::File;
use Mojo::Base 'Mojolicious::Command';

has description => "Add a message to a stream from a file\n";
has usage       => <<"EOF";
Usage: $0 add_message_from_file [OPTIONS]

These options are available for 'add_message_from_file':
    --file                  The file that contains the unprocessed body of the message
    --user                  The UserID of the user to post the message as (defaults to 
                            'MeritCommons System Messages')
    --stream                The Stream identifier of the stream to post the message to

EOF

sub run {
    my ($self, @args) = @_;

    GetOptionsFromArray(
        \@args,
        "f|file=s"   => \my $file_name,
        "u|user=s"   => \my $user,
        "s|stream=s" => \my $stream,
    );

    unless ($file_name && -e $file_name) {
        print "[error] couldn't find file $file_name\n" if $file_name;
        print $self->usage;
        return;
    }

    unless ($stream = $self->app->stream($stream)) {
        print $self->usage;
        return;
    }

    my $body = Mojo::File->new($file_name)->slurp;

    my $content = MeritCommons::Content->new(
        {
            render_as     => 'generic',
            body          => $body,
            original_body => $body,
            streams       => [$stream],
            public        => 1,
            serialized    => 0,
        }
    );

    $user = $self->app->user($user || 1);
    print $self->app->dumper($self->app->add_inbound_message($user, $content));
}

1;
