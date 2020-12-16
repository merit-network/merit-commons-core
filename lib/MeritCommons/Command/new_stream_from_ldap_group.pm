#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::new_stream_from_ldap_group;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long 'GetOptions';

has description => "Create a new stream containing users who are members of an LDAP group\n";
has usage       => "Usage: $0 new_stream_from_ldap_group [OPTIONS]\n";
has hint        => <<EOF;

These options are available for new_stream_from_ldap_group:
    -a, --actor             Who to run this command as, will default to the system user
                            if none is specified.
    -s, --stream            The name of the stream you want to create.
    -g, --group-dn          The DN (LDAP Distinguished Name) of the LDAP group to use as
                            the basis for stream membership
        --moderator         The user who will moderate this stream, user must already 
                            exist in the system (see new_user_from_ldap).
        --req-sub-authn     Create the stream with require_subscriber_authorization = 1
        --req-auth-authn    Create the stream with require_author_authorization = 1
        --all-are-authors   Automatically add all matching users as authors to this stream
                            as well.

EOF

sub run {
    my ($self, @args) = @_;

    my ($actor, $stream_name, $moderator, $auth_authn, $sub_authn, $group_dn, $all_are_authors);

    GetOptions(
        "a|actor=s"       => \$actor,
        "s|stream=s"      => \$stream_name,
        "moderator=s"     => \$moderator,
        "req-sub-authn"   => \$sub_authn,
        "req-auth-authn"  => \$auth_authn,
        "g|group-dn=s"    => \$group_dn,
        "all-are-authors" => \$all_are_authors
    );

    unless ($stream_name && $moderator && $group_dn) {
        print $self->usage;
        print $self->hint;
        return;
    }

    $actor = $actor ? $self->app->user($actor) : $self->app->user(1);
    unless ($actor) {
        print "Actor user not found.\n";
        return;
    }

    $moderator = $self->app->user($moderator);
    unless ($moderator) {
        print "Moderator user not found.\n";
        return;
    }

    $sub_authn       = 0 unless $sub_authn;
    $auth_authn      = 0 unless $auth_authn;
    $all_are_authors = 0 unless $all_are_authors;

    my ($created, $added) = $self->app->new_stream_from_ldap_group(
        {
            actor                            => $actor,
            stream_name                      => $stream_name,
            moderator                        => $moderator,
            group_dn                         => $group_dn,
            all_are_authors                  => $all_are_authors,
            require_author_authorization     => $auth_authn,
            require_subscriber_authorization => $sub_authn,
        }
    );

    if ($all_are_authors) {
        print "[info]: $stream_name created w/ $added subscribers/authors.\n";
    } else {
        print "[info]: $stream_name created w/ $added subscribers.\n";
    }

}

1;
