#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::add_stream;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use Getopt::Long 'GetOptions';
use Mojo::Util qw/decamelize/;

has description => "Add a stream/feed to meritcommons\n";
has usage       => <<EOF;

Usage: $0 add_stream [OPTIONS]

Add a new stream to this MeritCommons Instance

These options are required for add_stream:
    -n, --common-name       Stream title / Common Name
    -m, --moderator         The userid of the MeritCommons user who will be moderator of this stream

These options are optional for add_stream:
    -s, --short-name        A short name for this stream; used in message badges (defaults to first 4 of title)
    -u, --url-name          What name to use in URLs for this stream (defaults to decamelized title)
    -d, --description       A description of this stream, used in stream index and for stream discovery
    -k, --keywords          Phrases used to uniquely identify this stream in searches
    -p, --show-publicly     If used, designates that this stream show up in the stream list
    -i, --show-subscribers  If used, all the stream's subscribers will show up on the stream page 
    -t, --type              What type of stream (system, role or user) is this?  Defaults to 'system'
        --subtype           Used to categorize streams; Example subtype: "People", "Courses", "Roles", specifying
                            a subtype overrides default behavior where subtype is computed for some streams
        --req-sub-authn     If used, requires all subscribers be authorized by moderators;  if not used, anyone
                            can simply become a subscriber to this stream
        --req-aut-authn     If used, requires all authors be authorized by moderators; if not used, anyone can 
                            simply become an author on this stream
        --private           If used, MeritCommons will pretend this stream does not exist to anyone who is not already
                            associated with it (subscriber, author, or moderator).
        --anyone-can-invite If specified, anyone can invite anyone else in the system to have their level of access to
                            the stream.  Otherwise, all access must be approved by the moderator.

EOF

sub run {
    my ($self) = @_;

    my (
        $common_name,   $short_name,       $url_name, $description, $keywords,
        $show_publicly, $show_subscribers, $type,     $moderator,   $subtype,
        $req_sub_authn, $req_aut_authn,    $private,  $anyone_can_invite
    );

    GetOptions(
        "n|common-name=s"    => \$common_name,
        "s|short-name=s"     => \$short_name,
        "u|url-name=s"       => \$url_name,
        "d|description=s"    => \$description,
        "k|keywords=s"       => \$keywords,
        "p|show-publicly"    => \$show_publicly,
        "i|show-subscribers" => \$show_subscribers,
        "t|type=s"           => \$type,
        "m|moderator=s"      => \$moderator,
        "subtype=s"          => \$subtype,
        "req-sub-authn"      => \$req_sub_authn,
        "req-aut-authn"      => \$req_aut_authn,
        "private"            => \$private,
        "anyone-can-invite"  => \$anyone_can_invite,
    );

    my $app = $self->app;

    unless ($common_name && $moderator) {
        warn $self->usage;
        exit;
    }

    $type = "system" unless $type;

    # default to the first 4 non whitespace chars of the common name
    unless ($short_name) {
        ($short_name) = $common_name =~ /^([^\s]{1,4})/;
    }

    # ThisName becomes this_name
    unless ($url_name) {
        $url_name = decamelize($common_name);
    }

    my $user;
    unless ($user = $app->user($moderator)) {
        $user = $app->user(1);    # default to MeritCommons System User
    }

    # some things can't be null, set them to default if not defined.
    foreach my $thing ($req_sub_authn, $req_aut_authn, $show_publicly, $show_subscribers, $private) {
        $thing = 0 unless $thing;
    }

    my $stream = $app->m->resultset('Stream')->create(
        {
            common_name                            => $common_name,
            unique_id                              => $app->new_uuid,
            creator                                => $user->id,
            short_name                             => $short_name,
            url_name                               => $url_name,
            description                            => $description,
            keywords                               => $keywords,
            show_publicly                          => $show_publicly,
            display_subscribers                    => $show_subscribers,
            type                                   => $type,
            membership_requires_moderator_approval => $anyone_can_invite ? 0 : 1,
            requires_subscriber_authorization      => $req_sub_authn,
            requires_author_authorization          => $req_aut_authn,
        }
    );

    $app->add_stream_index($stream);

    $app->m->resultset('Stream::Moderator')->create(
        {
            meritcommons_user      => $user->id,
            stream              => $stream->id,
            allow_add_moderator => 1,
            added_by            => $user->id,
        }
    );

    print "[info]: added stream " . $stream->common_name . " (" . $stream->unique_id . ")\n";
}

1;
