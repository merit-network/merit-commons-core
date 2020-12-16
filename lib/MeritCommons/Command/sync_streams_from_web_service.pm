#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::sync_streams_from_web_service;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long 'GetOptions';
use Mojo::UserAgent;

has description => "Create and/or synchronize one or many streams from remote JSON data\n";
has usage       => "Usage: $0 sync_streams_from_web_service [OPTIONS]\n";
has hint        => <<EOF;

These options are available for new_stream_from_ldap_filter:
    -a, --actor             Who to run this command as, will default to the system user
                            if none is specified
    -u, --url               The URL of the remote web service to load stream information
                            from [REQUIRED]
    -m, --merge             If specified, associations present in the source will be added
                            to the destination, but associations in the destination will 
                            not be removed.  by default, the source is treated as 
                            a comprehensive snapshot of what stream associations should
                            look like

The remote JSON structure should look like:
[
    {
        "common_name": "Stream Title",
        "url_name": "stream_url_name",
        "membership_requires_moderator_approval": 1,
        "requires_subscriber_authorization": 1,
        "requires_author_authorization": 1,
        "private": 1,
        
        // read + write access
        "members": [
            "user1", "user2"
        ],

        // stream management + moderator access
        "moderators": [
            "user1"
        ],

        // read-only access
        "subscribers": [
            "user3", "user4"
        ],

        // write-only access (i know, kind of exotic)
        "authors": [
            "user5"
        ]
    },
    
    // a second stream; an unlimited number of streams may be defined in a single .json file.
    {
        "common_name": "Another Stream",
        // ...
    }
]

EOF

my $assoc_types = {
    authors     => ['Stream::Author'],
    subscribers => ['Stream::Subscriber'],
    moderators  => ['Stream::Moderator'],
    members     => [ 'Stream::Subscriber', 'Stream::Author' ],
};

my $asns = {};

sub run {
    my ($self, @args) = @_;

    GetOptions(
        "a|actor=s" => \my $actor,
        "u|url=s"   => \my $url,
        "m|merge"   => \my $merge,
    );

    # default to MeritCommons System user
    $actor = $self->app->user($actor) // $self->app->user(1);

    unless ($url) {
        warn $self->usage;
        die $self->hint;
    }

    my $ua = Mojo::UserAgent->new;
    my $doc = $ua->get($url => { 'Cache-Control' => 'private, max-age=0, no-cache' })->res->json;

    if (ref($doc) eq "ARRAY") {
        print "[info/http]: loaded definitions for @{[scalar(@$doc)]} stream(s) from URL '$url'\n";
        foreach my $sd (@$doc) {
            print "[info/json]: working on $sd->{common_name}...\n";

            my $s;
            unless ($s = $self->app->stream($sd->{url_name})) {
                $s = $self->app->m->resultset('Stream')->create(
                    {
                        common_name   => $sd->{common_name},
                        unique_id     => $self->app->new_uuid,
                        creator       => $actor->id,
                        short_name    => $sd->{short_name} ? $sd->{short_name} : $sd->{common_name} =~ /^([^\s]{1,4})/,
                        url_name      => $sd->{url_name},
                        description   => $sd->{description},
                        keywords      => $sd->{keywords},
                        show_publicly => $sd->{show_publicly} ? 1 : 0,
                        allow_unsubscribe => defined $sd->{allow_unsubscribe} ? $sd->{allow_unsubscribe} : 1,
                        display_subscribers => $sd->{show_subscribers} ? 1 : 0,
                        origin => substr($url, 0, 255),
                        type => $sd->{type} || "user",
                        membership_requires_moderator_approval => $sd->{membership_requires_moderator_approval} ? 1 : 0,
                        requires_subscriber_authorization      => $sd->{requires_subscriber_authorization}      ? 1 : 0,
                        requires_author_authorization          => $sd->{requires_author_authorization}          ? 1 : 0,
                    }
                );
                print "[info/stream]: created stream $sd->{common_name} with unique ID @{[$s->unique_id]}\n";
            }

            my $orig_merge = $merge;
            if (exists($sd->{member_management_policy}) && lc($sd->{member_management_policy}) eq "merge") {
                $merge = 1;
            }

            no warnings 'uninitialized';
            my $updated;
            foreach my $attribute (
                qw/common_name short_name description keywords show_publicly show_subscribers type
                membership_requires_moderator_approval requires_subscriber_authorization requires_author_authorization/
              ) {
                if (defined $sd->{$attribute} && $sd->{$attribute} ne $s->$attribute) {
                    print
                      "[info/stream]: updating attribute $attribute; old value: '@{[$s->$attribute]}'; new value: '$sd->{$attribute}'\n";
                    $s->$attribute($sd->{$attribute});
                    $updated = 1;
                }
            }
            use warnings 'uninitialized';

            if ($updated) {
                $s->update;
            }

            unless ($merge) {
                if ($s->requires_subscriber_authorization || $s->requires_author_authorization || $s->membership_requires_moderator_approval) {
                    my $ua_auth_removed = $s->authors->search({authorized => 0})->delete;
                    if ($ua_auth_removed > 0) {
                        print "[info/cleanup]: removed $ua_auth_removed unauthorized authors from @{[$s->common_name]} (@{[$s->unique_id]})\n";
                    }
                    my $ua_sub_removed = $s->subscribers->search({authorized => 0})->delete;
                    if ($ua_sub_removed > 0) {
                        print "[info/cleanup]: removed $ua_sub_removed unauthorized subscribers from @{[$s->common_name]} (@{[$s->unique_id]})\n";
                    }
                }
            }

            $self->app->add_stream_index($s);

            print "[info/json]: evaluating association lists for @{[$s->common_name]} (@{[$s->unique_id]})\n";
            foreach my $association (qw/members authors subscribers moderators/) {

                # use hashes for fast lookups..
                $asns->{$association}->{src} =
                  { map { $_ => 1 } ref($sd->{$association}) eq "ARRAY" ? @{ $sd->{$association} } : () };
                $asns->{$association}->{dst} = $association eq "members"
                  ?

                  # the member method already prefetches
                  { map { $_ => 1 } map { $_->meritcommons_user->userid } $s->$association }
                  :

                  # non-members benefit greatly from this prefetch
                  {
                    map { $_ => 1 }
                      map { $_->meritcommons_user->userid }
                      $s->$association->search({}, { prefetch => ['meritcommons_user'] })
                  };

                my @assoc_to_remove;
                unless ($merge) {

                    # perform merge of source to destination
                    foreach my $key (keys %{ $asns->{$association}->{dst} }) {
                        my $should_delete;
                        if ($association eq "subscribers" || $association eq "authors") {

                            # check members as this includes members in the source or destination (members in the destination will get
                            # cleaned up by the members pass)
                            unless (exists $asns->{$association}->{src}->{$key} ||
                                exists $asns->{members}->{src}->{$key} ||
                                exists $asns->{members}->{dst}->{$key}) {
                                $should_delete = 1;
                            }
                        } else {
                            unless (exists $asns->{$association}->{src}->{$key}) {
                                $should_delete = 1;
                            }
                        }
                        if ($should_delete) {

                            # it's not in the source, remove it...
                            push(@assoc_to_remove, $key);
                        }
                    }
                }

                my @assoc_to_add;
                foreach my $key (keys %{ $asns->{$association}->{src} }) {
                    unless (exists $asns->{$association}->{dst}->{$key}) {

                        # not in the destination, add it...
                        push(@assoc_to_add, $key);
                    }
                }

                unless (scalar(@assoc_to_add) == 0 && scalar(@assoc_to_remove) == 0) {
                    if (scalar(@assoc_to_add) > 0) {
                        print "[info/acl]: adding @{[scalar(@assoc_to_add)]} $association\n";
                        my $i      = 0;
                        my $errors = 0;
                        foreach my $a2a (@assoc_to_add) {
                            if (my $user = $self->fetch_or_create_user($a2a)) {
                                foreach my $class (@{ $assoc_types->{$association} }) {

                                    # make this non-fatal
                                    eval {
                                        my $to_create = {
                                            meritcommons_user => $user->id,
                                            stream         => $s->id,
                                            added_by       => $actor->id,
                                        };

                                        # subscribers need subscriptions authorized for closed streams.
                                        if ($association eq "subscribers" ||
                                            $association eq "authors" ||
                                            $association eq "members") {
                                            $to_create->{authorized} = 1;
                                        }

                                        $self->app->m->resultset($class)->create($to_create);
                                    };
                                }
                                $i++;
                            } else {
                                warn "              ERROR ";
                                warn "user $username not found in the database or in any configured provisioning source; skipping.\n";
                                $errors++
                            }
                        }
                        print
                          "                ... done, added $i $association to @{[$s->common_name]} ($errors errors)\n";
                    }

                    if (scalar(@assoc_to_remove) > 0) {
                        print "[info/acl]: removing @{[scalar(@assoc_to_remove)]} $association\n";
                        my $i      = 0;
                        my $errors = 0;
                        foreach my $a2r (@assoc_to_remove) {
                            if (my $user = $self->fetch_or_create_user($a2r)) {
                                foreach my $class (@{ $assoc_types->{$association} }) {
                                    # make this non-fatal
                                    eval {
                                        $self->app->m->resultset($class)->search(
                                            {
                                                meritcommons_user => $user->id,
                                                stream         => $s->id,
                                            }
                                        )->delete;
                                    };
                                }
                                $i++;
                            } else {
                                warn "              ERROR ";
                                warn "user $username not found in the database or in any configured provisioning source; skipping.\n";
                                $errors++;
                            }
                        }
                        print
                          "                ... done, removed $i $association from @{[$s->common_name]} ($errors errors)\n";
                    }
                }
                
                $merge = $orig_merge;
            }
            print "[info/status]: $@{[$s->common_name]} synchronized with $url\n";
        }
    } else {
        print $self->app->dumper($doc);
        die "[fatal/http]: error retrieving document from URL '$url'\n";
    }
}

sub fetch_or_create_user {
    my ($self, $username) = @_;
                            
    # get (or create) the user...
    my $user = $self->app->user($username);
    unless ($user) {
        eval {
            $user = $self->app->new_user_from_ldap($username);
        };
        if (my $error = $@) {
            if ($self->global_config->{authentication_provider} eq "MeritCommons::Helper::LDAPAuth") {
                warn "[error/ldap]: unable to automatically provision user $username - $error\n";
            } else {
                                                      
            }
            $errors++;
        } else {
            print "[info/ldap]: user $username automatically provisioned.\n";
        }
    }
    
    return ref($user) eq "MeritCommons::Model::User" ? $user : undef;
}


1;
