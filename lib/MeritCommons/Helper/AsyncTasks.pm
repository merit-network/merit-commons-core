#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::AsyncTasks;
use Mojo::Base 'Mojolicious::Plugin';
use Time::HiRes qw/time/;
use Carp qw/croak/;
use Mojolicious::Controller;
use Tie::IxHash;

our $app;

sub register {
    my $self = shift;
    $app = shift;

    # development-only tasks.
    if ($app->mode eq "development") {
        $app->add_async_task(hello_world => \&_hello_world);
    }

    # install tasks here!
    $app->add_async_task(get_more               => \&_get_more);
    $app->add_async_task(get_more_notifications => \&_get_more_notifications);
    $app->add_async_task(recipient_search       => \&_recipient_search);
    $app->add_async_task(process_file_upload    => \&_process_file_upload);
    $app->add_async_task(stream_search          => \&_stream_search);
}

sub _process_file_upload {
    my ($job, $file_id, $header) = @_;

    my $file = $app->m->resultset('File')->single({ unique_id => $file_id });
    if ($file) {
        my $pg = $app->async_mojo_pg;

        # create a scratch space for us to work in
        $pg->db->query(
            "insert into meritcommons_async_stash (unique_id, payload) values (?, ?)",
            "@{[$file->unique_id]}.process_file_upload",
            { json => {} }
        );

        # this will block until all handlers fire.
        $app->emit("file_uploaded", $file, $header);

        # delete the temp file data
        $pg->db->query("delete from meritcommons_async_stash where unique_id = ?", $file_id);

        my $doc = $pg->db->query("select payload from meritcommons_async_stash where unique_id = ?",
            "@{[$file->unique_id]}.process_file_upload")->expand->hash->{payload};

        if ($doc) {
            $pg->db->query("delete from meritcommons_async_stash where unique_id = ?",
                "@{[$file->unique_id]}.process_file_upload");
            return $doc;
        } else {
            return { success => 0 };
        }
    } else {
        return { success => 0 };
    }
}

# stream_search options
# search for streams by name
sub _stream_search {
    my ($job, $search) = @_;

    my $requestor = $app->user($search->{requestor});

    my $opts = { include_private => 1 };

    if ($search->{search_string}) {
        $opts->{search_string} = $search->{search_string};
    }

    if (my $type = $search->{type}) {
        $opts->{type} = $type;
    }

    if (my $min_sub = $search->{minimum_subscribers}) {
        $opts->{minimum_subscribers} = $min_sub;
    }

    return [
        map { { id => $_->unique_id, text => $_->common_name . " (@{[$_->subscriber_count]})" } }
        sort { $a->common_name cmp $b->common_name } $requestor->search_streams($app->sphinx_h, $opts)
    ];
}

# recipient_search options
# search_string = the search string
# search_contexts = an array of search contexts.
# valid contexts: my_followers, followers_of, im_following, followed_by, thread, subscribed_to, my_aliases, ldap, streams

sub _recipient_search {
    my ($job, $search) = @_;

    # search string is a null string if undefined.
    $search->{search_string} //= '';

    # get the cache token
    my $raw_ct = $search->{search_string} . $search->{requestor};
    foreach my $ctx (@{ $search->{search_contexts} }) {
        if (ref($ctx) eq "HASH") {
            foreach my $k (sort { $a cmp $b } keys %$ctx) {
                my $v = $ctx->{$k};
                $raw_ct .= $k;
                if (ref($v) eq "HASH") {
                    foreach my $ok (keys %$v) {
                        $raw_ct .= "$ok:$v->{$ok}";
                    }
                } elsif (ref($v) eq "ARRAY") {
                    $raw_ct .= join('', @$v);
                } else {
                    $raw_ct .= $v;
                }
            }
        } elsif (!ref($ctx)) {
            $raw_ct .= "$ctx";
        }
    }

    my $cache_token = $app->md5_hex($raw_ct);
    if (my $cached = $app->cache->get("recipient_search/$cache_token")) {
        if ($ENV{MERITCOMMONS_DEBUG}) {
            print "[debug] CACHED recipient_search: ";
            print $app->dumper($search);
            if (scalar(keys %{ $cached->{match_pool} })) {
                print "[debug] CACHED response: ";
                print $app->dumper($cached);
            } else {
                print "[debug] CACHED response: EMPTY\n";
            }
        }
        return $cached;
    } else {
        if ($ENV{MERITCOMMONS_DEBUG}) {
            print "[debug] recipient_search cache MISS\n";
        }
    }

    my $requestor = $app->user($search->{requestor});

    my $search_types = {
        my_followers => sub {
            my ($search_string) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            # don't allow this search without a user specified
            my $user = $requestor;
            return [] unless $user;

            my @matches;
            foreach my $f ($user->followers) {
                if ($f->userid =~ /\Q$search_string/i ||
                    $f->common_name =~ /\Q$search_string/i ||
                    __aliases_match($f, $search_string)) {
                    push(@matches, $f);
                }
            }

            return [ map { __user_payload($requestor, $_) } @matches ];
        },
        followers_of => sub {
            my ($search_string, $followed) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            # don't allow this search without a user specified
            my $user = $app->user($followed);
            return [] unless $user;

            my @matches;
            foreach my $f ($user->followers) {
                if ($f->userid =~ /\Q$search_string/i ||
                    $f->common_name =~ /\Q$search_string/i ||
                    __aliases_match($f, $search_string)) {
                    push(@matches, $f);
                }
            }

            return [ map { __user_payload($requestor, $_) } @matches ];
        },
        im_following => sub {
            my ($search_string) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            # don't allow this search without a user specified
            my $user = $requestor;
            return [] unless $user;

            my @matches;
            foreach my $f ($user->following) {
                if ($f->userid =~ /\Q$search_string/i ||
                    $f->common_name =~ /\Q$search_string/i ||
                    __aliases_match($f, $search_string)) {
                    push(@matches, $f);
                }
            }

            return [ map { __user_payload($requestor, $_) } @matches ];
        },
        followed_by => sub {
            my ($search_string, $following) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            # don't allow this search without a user specified
            my $user = $app->user($following);
            return [] unless $user;

            my @matches;
            foreach my $f ($user->following) {
                if ($f->userid =~ /\Q$search_string/i ||
                    $f->common_name =~ /\Q$search_string/i ||
                    __aliases_match($f, $search_string)) {
                    push(@matches, $f);
                }
            }

            return [ map { __user_payload($requestor, $_) } @matches ];
        },
        thread => sub {
            my ($search_string, $thread_id) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            # don't allow this search without a thread specified!
            my $thread = $app->message($thread_id);
            return [] unless $thread;

            # get all thread participants...
            my $tp = {};

            foreach my $reply ($thread->thread_replies) {
                my $submitter = $reply->submitter;

                if (
                    !$tp->{ $reply->submitter->unique_id } &&
                    ($submitter->userid =~ /\Q$search_string/i ||
                        $submitter->common_name =~ /\Q$search_string/i ||
                        __aliases_match($submitter, $search_string))
                  ) {
                    $tp->{ $reply->submitter->unique_id } = $reply->submitter;
                }
            }

            return [ map { __user_payload($requestor, $_) } map { $tp->{$_} } keys %$tp ];
        },
        subscribed_to => sub {
            my ($search_string, $stream_ids) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            my @matches = $app->rorm->resultset('User')->search(
                {
                    'subscriptions.stream' => [$stream_ids],
                    'me.id' =>
                      [ grep { $_ ne $requestor->id } @{ $app->search_users_id_only($app->sphinx_h, $search_string) } ],
                },
                {
                    join     => ['subscriptions'],
                    distinct => 1,
                }
            )->all;

            return [ map { __user_payload($requestor, $_) } @matches ];
        },
        subscribed_with_me => sub {
            my ($search_string) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            my @matches = $app->rorm->resultset('User')->search(
                {
                    'subscriptions.stream' =>
                      [ grep { $_ != 1 } map { $_->id } $requestor->authorized_subscribed_streams ],
                    'subscriptions.meritcommons_user' =>
                      [ grep { $_ ne $requestor->id } @{ $app->search_users_id_only($app->sphinx_h, $search_string) } ],
                },
                {
                    join     => ['subscriptions'],
                    distinct => 1,
                }
            )->all;

            return [ map { __user_payload($requestor, $_) } @matches ];
        },
        my_aliases => sub {
            my ($search_string) = @_;
            my $user = $requestor;

            return [] unless $user;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            my $matches = {};
            foreach my $alias ($user->nicknames_for_others) {
                if ($alias->common_name =~ /\Q$search_string/i) {
                    $matches->{ $alias->meritcommons_user->id } = $alias->meritcommons_user;
                }
            }

            return [ map { __user_payload($requestor, $matches->{$_}) } keys %$matches ];
        },
        global => sub {
            my ($search_string) = @_;

            # no global searches on any less than 5 characters
            return [] unless (length($search_string) >= 5);

            return [ map { __user_payload($requestor, $_) } $app->search_users($app->sphinx_h, $search_string) ];
        },
        ldap => sub {
            my ($search_string) = @_;

            # don't allow this search with null search strings!
            return [] unless $search_string;

            my $config = $app->global_config;
            my $ldap;

            eval { $ldap = $app->fetch_ldap(); };

            my $error = $@;

            if ($error || !$ldap) {
                $app->log->error("LDAP server unavailable in AsyncTask recipient_search!!");
                return [];
            }

            my @entries;
            foreach my $filter (@{ $config->{ldap_connect_info}->{recipient_search_filters} }) {
                $filter =~ s/\$\{search_string\}/$search_string/g;

                my $lres = $ldap->search(
                    base      => $config->{ldap_connect_info}->{base_dn},
                    scope     => 'sub',
                    sizelimit => 20,
                    filter    => $filter,
                );

                push(@entries, $lres->entries);
            }

            # map the LDAP account to a user account payload by the configured unique id field.
            my @users;
            foreach my $entry (@entries) {
                if (my $user = __uid_to_user($entry->get_value($config->{ldap_connect_info}->{unique_id_field}))) {
                    push(@users, $user);
                }
            }

            return [ map { __user_payload($requestor, $_) } @users ];
        },
        streams => sub {
            my ($search_string, $opts, $requestor) = @_;
            $opts->{search_string} = $search_string;
            return [
                sort { $a->{common_name} cmp $b->{common_name} }
                map { __stream_payload($requestor, $_) } $requestor->search_streams($app->sphinx_h, $opts)
            ];
        },
    };

    my $results = [];
    foreach my $ctx (@{ $search->{search_contexts} }) {
        my $name = $ctx;
        eval {
            if (ref($ctx) eq "HASH") {
                my ($type, $arg) = each %$ctx;
                $name = $type;
                push(@$results, $search_types->{$type}->($search->{search_string}, $arg, $requestor));
            } elsif (!ref($ctx)) {
                push(@$results, $search_types->{$ctx}->($search->{search_string}, $requestor));
            }
        };
        if (my $error = $@) {
            $app->log->error("AsyncTasks::recipient_search - error in search context $name - $error");
        }
    }

    # collate results into a search result data structure...
    my $search_results = {

        # pass this back to them
        search_string => $search->{search_string},

        # unique users' data objects
        match_pool => {},

        # $results reduced to lists of IDs
        search_results => [],

        # a list of all of the names of all of the matches
        names => {},
    };

    foreach my $rs (@$results) {
        my $sr = [];
        foreach my $match (@$rs) {
            unless (exists $search_results->{match_pool}->{ $match->{unique_id} }) {
                $search_results->{match_pool}->{ $match->{unique_id} } = $match;

                # everything has a common name
                push(@{ $search_results->{names}->{ $match->{common_name} } }, $match->{unique_id});

                if ($match->{entity_type} eq "user") {
                    push(@{ $search_results->{names}->{ $match->{userid} } },        $match->{unique_id});
                    push(@{ $search_results->{names}->{ $match->{email_address} } }, $match->{unique_id})
                      if $match->{email_address};

                    # add all their aliases to the names structure, pointing back to their pool entry
                    foreach my $alias (@{ $match->{aliases} }) {
                        my $found;
                        foreach my $euuid (@{ $search_results->{names}->{$alias} }) {
                            if ($euuid eq $match->{unique_id}) {
                                $found = 1;
                                last;
                            }
                        }
                        push(@{ $search_results->{names}->{$alias} }, $match->{unique_id}) unless $found;
                    }
                }
            }
            push(@$sr, $match->{unique_id});
        }
        push(@{ $search_results->{search_results} }, $sr);
    }

    # convert names into an array of hashrefs sorted by how well they match the search string
    my $search_string = $search->{search_string};
    my @sorted_names  = sort {
        ($a =~ /^$search_string/i ? length $a : (9000 + length $a))
          <=> ($b =~ /^$search_string/i ? length $b : (9000 + length $b))
    } keys %{ $search_results->{names} };

    my %ordered_hash;
    tie(%ordered_hash, 'Tie::IxHash', map { $_ => $search_results->{names}->{$_} } @sorted_names);

    $search_results->{names} = \%ordered_hash;

    # set for later!
    $app->cache->set("recipient_search/$cache_token", $search_results, ($app->global_config->{recipient_search_cache_timeout} // 3600));

    if ($ENV{MERITCOMMONS_DEBUG}) {
        print "[debug] recipient_search: ";
        print $app->dumper($search);
        if (scalar(keys %{ $search_results->{match_pool} })) {
            print "[debug] response: ";
            print $app->dumper($search_results);
        } else {
            print "[debug] response: EMPTY\n";
        }
    }

    # complete list of search results, in the order their contexts were in.  empty arrayrefs for searches that had no results.
    return $search_results;
}

sub __uid_to_user {
    my ($uid) = @_;
    return $app->m->resultset('User')->single({ userid => $uid });
}

sub __aliases_match {
    my ($user, $search_string) = @_;
    if ($app->db_is_postgres) {
        return $user->aliases->search({ common_name => { ilike => $search_string . "%" } })->first;
    } else {

        # i think everyone else has a case insensitive like
        return $user->aliases->search({ common_name => { like => $search_string . "%" } })->first;
    }
}

sub __stream_payload {
    my ($requestor, $stream) = @_;

    return undef unless $stream;

    # cache this in case we've already
    if (my $cached = $app->cache->get("stream_payload_structure/" . $stream->unique_id)) {
        return $cached;
    }

    my $hr = {
        entity_type        => 'stream',
        common_name        => $stream->common_name,
        unique_id          => $stream->unique_id,
        description        => $stream->description,
        private            => $stream->requires_subscriber_authorization ? 1 : 0,
        relative_url       => "/s/@{[$stream->url_name]}",
        subscriber_count   => $stream->subscriber_count,
        author_count       => $stream->author_count,
        moderator_count    => $stream->moderator_count,
        type               => $stream->type,
        subtype            => $stream->subtype,
        members_can_invite => $stream->members_can_invite,
        creator => __user_payload($requestor, $stream->creator),
    };

    if ($stream->personal_inbox_user || $stream->personal_outbox_user || $stream->notification_inbox_user) {
        $hr->{personal} = 1;
    }

    $hr->{names} = [ $hr->{common_name}, ];

    $hr->{profile_thumb_url} = $app->profile_picture_url_for_stream($stream, 'thumbnail');
    $hr->{profile_tiny_url}  = $app->profile_picture_url_for_stream($stream, 'tiny');

    $app->cache->set("stream_payload_structure/" . $stream->unique_id,
        $hr, ($app->global_config->{recipient_search_cache_timeout} // 3600));

    return $hr;
}

sub __user_payload {
    my ($requestor, $user) = @_;

    return undef unless $user;

    # cache this in case we've already
    if (my $cached = $app->cache->get("user_payload_structure/" . $user->unique_id)) {
        return $cached;
    }

    my $hr = {
        entity_type   => 'user',
        userid        => $user->userid,
        common_name   => $user->common_name,
        unique_id     => $user->unique_id,
        organization  => $user->organization || "Wayne State",
        email_address => $user->email_address,
        title         => $user->title || "Affiliate",
    };

    # get all their unique aliases, requestor's aliases first.
    my $aliases = {};
    foreach my $alias (sort { ($a->owner->id == $requestor->id) <=> ($b->owner == $requestor->id) } $user->aliases) {
        $aliases->{ lc($alias->common_name) } = $alias->common_name;
    }

    # the first user defined alias capitalization, duplicates filtered out case insensitively
    $hr->{aliases} = [ map { $aliases->{$_} } keys %$aliases ];

    $hr->{profile_thumb_url} = $app->profile_picture_url_for_user($user, 'thumbnail');
    $hr->{profile_tiny_url}  = $app->profile_picture_url_for_user($user, 'tiny');

    # this merged list is to make the javascript easier.  Any of these names are this person.
    $hr->{names} = [ $hr->{common_name}, $hr->{userid}, @{ $hr->{aliases} } ];

    if ($hr->{email_address}) {
        push(@{ $hr->{names} }, $hr->{email_address});
    }

    # store this in our cache for a configured time or 1 hour
    $app->cache->set("user_payload_structure/" . $user->unique_id, $hr, ($app->global_config->{recipient_search_cache_timeout} // 3600));

    return $hr;
}

sub _hello_world {
    my ($job, @args) = @_;

    my $start_time = time;

    srand();
    my $todo = int(rand(1000000));

    my $thang = 0;
    for (my $i = 0 ; $i < $todo ; $i++) {
        $thang += $todo * $i;
    }

    my $time_taken = sprintf("%.5f", time - $start_time);

    return {
        message => "thang is $thang (took $time_taken seconds, @args) processed by @{[$app->global_config->{hostname}]}"
    };
}

sub _get_more {
    my ($self, $get_more_params, $user_id) = @_;

    my $user = $app->rorm->resultset('User')->find({ id => $user_id });

    if ($get_more_params->{afterId} && $get_more_params->{after} && $get_more_params->{streams}) {

        # convert the message's unique id to a numeric id
        my $after_unique_id = $get_more_params->{afterId};
        my $after_id =
          $app->rorm->resultset('Stream::Message')->find({ unique_id => $after_unique_id })->id;

        my @streams = $app->rorm->resultset('Stream')->search(
            {
                unique_id => $get_more_params->{streams}
            }
        );

        my @stream_ids = map { $_->id } @streams;

        my @messages;
        if ($get_more_params->{searchFilter}) {
            my @message_results = $user->search_messages(
                $app->sphinx_h,
                $get_more_params->{searchFilter},
                $get_more_params->{after},
                $after_id, @stream_ids
            );

            @messages = map { $app->messages->prepare($_, $user) } @message_results;
        } else {
            @messages = $app->messages->merged(
                {
                    user     => $user,
                    limit    => 25,
                    after    => $get_more_params->{after},
                    after_id => $after_id,
                    replica  => 1,
                },
                @streams
            );
        }

        return { message => \@messages };
    }
}

sub _get_more_notifications {
    my ($self, $get_more_params, $user_id) = @_;

    my $user = $app->m->resultset('User')->find({ id => $user_id });

    my @notifications = $app->notifications(
        {
            user => $user,
            before =>
              $app->m->resultset('Stream::Message')->find({ unique_id => $get_more_params->{beforeId} })->post_time,
            limit => 10,
        }
    );

    return { message => \@notifications };
}

1;
