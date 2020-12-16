#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::update_stream_from_ldap_group;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long 'GetOptions';

has description => "Update a stream containing users who are members of an LDAP group\n";
has usage       => "Usage: $0 update_stream_from_ldap_group [OPTIONS]\n";
has hint        => <<EOF;

These options are available for update_stream_from_ldap_filter:
    -a, --actor             Who to run this command as, will default to the system user
                            if none is specified.
    -s, --stream            The name of the stream you want to update.
    -g, --group-dn          The DN (LDAP Distinguished Name) of the LDAP group to use as
                            the basis for stream membership
        --all-are-authors   Automatically add all matching users as authors to this stream
                            as well.

EOF

sub run {
    my ($self) = @_;
    my ($actor, $stream_name, $group_dn, $all_are_authors);

    GetOptions(
        "a|actor=s"       => \$actor,
        "s|stream=s"      => \$stream_name,
        "g|group-dn=s"    => \$group_dn,
        "all-are-authors" => \$all_are_authors
    );

    unless ($stream_name && $group_dn) {
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

    my ($created, $added) = $self->app->update_stream_from_ldap_group(
        {
            actor           => $actor,
            stream_name     => $stream_name,
            group_dn        => $group_dn,
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
