#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::update_stream_from_ldap_filter;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long 'GetOptions';

has description => "Update a stream to contain users found by an LDAP filter\n";
has usage       => "Usage: $0 update_stream_from_ldap_filter [OPTIONS]\n";
has hint        => <<EOF;

These options are available for update_stream_from_ldap_filter:
    -a, --actor             Who to run this command as, will default to the system user
                            if none is specified.
    -s, --stream            The name of the stream you want to update.
    -f, --filter            The LDAP filter to use to find stream subscribers.  The search
                            will begin at your configured Base DN.
        --all-are-authors   Automatically add all matching users as authors to this stream
                            as well.

EOF

sub run {
    my ($self) = @_;
    my ($actor, $stream_name, $filter, $all_are_authors);

    GetOptions(
        "a|actor=s"       => \$actor,
        "s|stream=s"      => \$stream_name,
        "f|filter=s"      => \$filter,
        "all-are-authors" => \$all_are_authors
    );

    unless ($stream_name && $filter) {
        print $self->usage;
        print $self->hint;
        return;
    }

    $actor = $actor ? $self->app->user($actor) : $self->app->user(1);
    unless ($actor) {
        print "Actor user not found.\n";
        return;
    }

    $all_are_authors = 0 unless $all_are_authors;

    my ($created, $added) = $self->app->update_stream_from_ldap_filter(
        {
            actor           => $actor,
            stream_name     => $stream_name,
            filter          => $filter,
            all_are_authors => $all_are_authors,
        }
    );

    if ($all_are_authors) {
        print "[info]: $stream_name updated w/ $added subscribers/authors.\n";
    } else {
        print "[info]: $stream_name updated w/ $added subscribers.\n";
    }

}

1;
