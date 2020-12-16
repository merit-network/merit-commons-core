#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Stream;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use MIME::Base64 qw(encode_base64url decode_base64url);
use Mojo::JSON qw(to_json encode_json);
use POSIX qw(strftime);
use Time::HiRes;
use Text::Markdown 'markdown';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    my $ti         = 0;
    my $start_time = Time::HiRes::time;

    unless ($self->active_user) {
        $self->reply->not_found;
        return;
    }

    # we need to prefetch + stash subscriptions
    $self->util->stash_stream_subscriptions;

    # these pages are big, let's turn gzip on...
    $self->stash(gzip => 1);
    $self->res->headers->cache_control('no-store');

    return if $self->features_detected;

    my @stream_identifiers = split(/\+\+/, $self->stash('stream_identifier'));
    if (scalar(@stream_identifiers) == 1) {
        my $stream_identifier = $stream_identifiers[0];

        if (my $user = $self->active_user) {
            my $stream;
            if ($stream_identifier eq "You") {
                $stream = $user->personal_inbox if $user->personal_inbox;
            }

            if ($stream || ($stream = $self->stream($stream_identifier))) {
                if (my $pou = $stream->personal_outbox_user) {

                    # if this is a personal outbox, redirect to the profile page.
                    $self->redirect_to('/u/' . $pou->userid);
                } else {

                    # do not render this template if the user cannot read this stream
                    unless ($user->can_read($stream)) {

                        # this should read $stream->requires_subscriber_authorization && !$stream->private
                        if ($stream->requires_subscriber_authorization && !$stream->private) {
                            $self->stash(
                                {
                                    user   => $user,
                                    stream => $stream,
                                }
                            );
                            $self->render(template => "stream/apply");
                        } elsif (my $invite = $self->invite($user, $stream)) {
                            if ($invite->approved) {
                                $self->stash(
                                    {
                                        user   => $user,
                                        stream => $stream,
                                    }
                                );
                                $self->render(template => "stream/apply");
                            } else {
                                $self->reply->not_found;
                            }
                        } else {
                            $self->reply->not_found;
                        }
                        return;
                    }

                    $stream->{description_html} = markdown($self->app->htmlstrip($stream->description));

                    $self->stash(stream               => $stream);
                    $self->stash(subscriptions        => [$stream]);
                    $self->stash(search_stream_filter => $stream->id);

                    my @payload_messages = $self->app->merged_messages(
                        {
                            user  => $self->active_user,
                            limit => 7,
                            after => time,
                        },
                        $stream
                    );

                    $self->stash(payload_messages      => \@payload_messages);
                    $self->stash(payload_messages_json => to_json(\@payload_messages));
                    $self->stash(
                        alt_title_link => {
                            href => "/s/" . ($stream->url_name || $stream->common_name) . "/",
                            title => $stream->common_name
                        }
                    );

                    $self->render(template => "stream/default");
                }
            } else {

                # Suggest a url name based on the stream identifier
                $self->stash(url_name => $self->stream_generate_url_name($self->stash('stream_identifier')));
                $self->render(template => "stream/create");
            }
        } else {
            if (my $stream = $self->stream($stream_identifier)) {
                if (my $pou = $stream->personal_outbox_user) {
                    $self->redirect_to('/u/' . $pou->userid);
                } else {
                    $self->stash(stream               => $stream);
                    $self->stash(subscriptions        => [$stream]);
                    $self->stash(search_stream_filter => $stream->id);

                    if ($stream->requires_subscriber_authorization) {
                        $self->reply->not_found;
                    } else {
                        $self->stash(render_feed => 1);

                        my @payload_messages = $self->app->merged_messages(
                            {
                                user  => $self->active_user,
                                limit => 7,
                                after => time,
                            },
                            $stream
                        );

                        $self->stash(payload_messages      => \@payload_messages);
                        $self->stash(payload_messages_json => to_json(\@payload_messages));

                        $self->stash(alt_title_link =>
                              { href => "/s/" . $stream->url_name . "/", title => $stream->common_name });
                        $self->render(template => "stream/default");
                    }
                }
            } else {
                $self->reply->not_found;
            }
        }
    } else {

        # Note that the single stream request case could probably be combined with the
        # multiple stream request case, given some clever work on the template.
        my @streams;
        my $permissions = {
            render_post        => [],
            render_feed        => [],
            denied_render_post => [],
            denied_render_feed => [],
            not_found          => [],
        };

        foreach my $stream_identifier (@stream_identifiers) {
            my $stream;
            my $user = $self->active_user;

            if ($stream_identifier eq "You") {
                $stream = $user->personal_inbox if $user->personal_inbox;
            } else {
                $stream = $self->stream($stream_identifier);
            }

            if ($user) {
                if ($stream) {
                    if ($user->can_read($stream)) {
                        warn "@{[$user->common_name]} can read @{[$stream->common_name]}\n";

                        # add this to the list of streams we can read from (below)
                        push(@streams, $stream);
                    } else {
                        return $self->reply->not_found;
                    }
                } else {
                    return $self->reply->not_found;
                }
            } else {

                # if it's open, let it fly!
                if ($stream && !$stream->requires_subscriber_authorization) {
                    push(@streams, $stream);
                } else {
                    return $self->reply->not_found; # 404 if any of the streams aren't viewable by a nonauthenticated user
                }
            }
        }

        $self->stash(subscriptions => \@streams);
        my @payload_messages = $self->app->merged_messages({ user => $self->active_user, limit => 7 }, @streams);
        $self->stash(payload_messages      => \@payload_messages);
        $self->stash(payload_messages_json => to_json(\@payload_messages));
        $self->render(template => "stream/default");
    }

}

# allow rss feed for one or more streams if they are "open" e.g. do not 'require subscriber authorization'
sub rss {
    my ($self) = @_;

    my $user = $self->active_user;
    if ($user || $self->config->{anonymous_stream_rss_feeds}) {
        my @streams = map { $self->stream($_) } split(/\+\+/, $self->stash('stream_identifier'));

        my ($rss_title, $rss_link, @rss_streams);
        foreach my $stream (@streams) {
            if (($user && $user->can_read($stream)) || !$stream->requires_subscriber_authorization) {
                push(@rss_streams, $stream);
                $rss_title .= $rss_title ? (", " . $stream->common_name) : $stream->common_name;
                if ($user) {
                    $rss_link .=
                      $rss_link
                      ? ("," . $stream->url_name)
                      : ($self->config->{front_door_url} . "/s/" . $stream->url_name);
                } else {
                    $rss_link .=
                      $rss_link
                      ? ("," . $stream->url_name)
                      : ($self->config->{front_door_url} . "/login?message=Please%20Log%20In&back=" .
                          $self->config->{front_door_url} . "/s/" . $stream->url_name);
                }
            }
        }

        $self->stash(
            rss_title     => "Stream(s): $rss_title",
            rss_link      => $rss_link,
            rss_pub_date  => strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time())),
            subscriptions => \@rss_streams,
        );

        my @payload_messages = $self->merged_messages(
            {
                user => $user // $self->user(1),
                limit => 10,
            },
            @rss_streams
        );

        $self->stash(payload_messages => \@payload_messages);
        $self->render(template => 'stream/rss', format => 'xml');
    } else {
        $self->reply->not_found;
    }
}

sub create {
    my ($self) = @_;

    my @stream_identifiers = split(/\+\+/, $self->stash('stream_identifier'));

    if (scalar(@stream_identifiers) == 1) {
        my $stream_identifier = $stream_identifiers[0];

        # default to the first 4 characters of the stream identifier
        my ($badge_name) = $self->param('badge_name') || $stream_identifier =~ /^([^\s]{1,4})/;

        # get rid of trailing whitespace on the badge name, this will cause stream badges to wrap
        $badge_name =~ s/\s*$//g;

        my ($description) = $self->param('description') || '';

        my ($keywords) = lc($self->param('keywords')) || '';

        my ($show_publicly) = $self->param('show_publicly') || 0;
        if ($show_publicly != 0 and $show_publicly != 1) {
            $show_publicly = 0;
        }

        my ($private) = $self->param('private') || 0;
        if ($private != 0 and $private != 1) {
            $private = 0;
        }

        my ($display_subscribers) = $self->param('display_subscribers') || 0;
        if ($display_subscribers != 0 and $display_subscribers != 1) {
            $display_subscribers = 0;
        }

        my $error = [];

        my $stream_reserved_error = 0;
        my @stream_reserved_names = (
            qr/^_/,    # streams that start with an underscore are always reserved for system use
        );
        if ($self->config->{stream_reserved_names}) {
            push(@stream_reserved_names, @{ $self->config->{stream_reserved_names} });

            # Prevent streams from being created with reserved names
            foreach my $stream_reserved_name (@stream_reserved_names) {
                if (((ref $stream_reserved_name eq "Regexp") && ($stream_identifier =~ $stream_reserved_name)) ||
                    ((ref $stream_reserved_name ne "Regexp") && ($stream_identifier eq $stream_reserved_name))) {
                    push(@$error, 'Stream name is reserved and cannot be used');
                }
            }
        }

        my $existing_stream;
        my $url_name;
        if (defined $self->param('url_name')) {
            $url_name = lc($self->param('url_name'));

            $existing_stream = $self->app->m->resultset('Stream')->search(
                {
                    url_name => $url_name
                }
            )->first;
            if ($existing_stream) {
                push(@$error, 'URL name is already in use');
            }

            if ($url_name !~ /^[a-z0-9_]{1,255}$/) {
                push(@$error, 'URL name is invalid');
            }

        } else {
            push(@$error, 'URL name not provided');
        }

        if (scalar(@{$error}) > 0) {
            $self->flash(flash_type => 'danger');
            my $error_message = join(', ', @{$error});
            $self->flash(message => $error_message);
            my $submitted_data = {
                url_name      => $url_name,
                badge_name    => $badge_name,
                description   => $description,
                show_publicly => $show_publicly,
                keywords      => $keywords,
            };
            if ($self->param('requires_subscriber_authorization')) {
                $submitted_data->{requires_subscriber_authorization} =
                  $self->param('requires_subscriber_authorization');
            }
            if ($self->param('requires_author_authorization')) {
                $submitted_data->{requires_author_authorization} = $self->param('requires_author_authorization');
            }
            my $redirect_url =
              $self->url_for(name => 'get_stream')->query(data => encode_base64url(encode_json($submitted_data)));
            $self->redirect_to($redirect_url, { stream_identifier => $stream_identifier });
        } else {
            if (my $user = $self->active_user) {

                my $stream = $self->app->m->resultset('Stream')->create(
                    {
                        common_name                   => $stream_identifier,
                        unique_id                     => $self->app->new_uuid,
                        creator                       => $user->id,
                        short_name                    => $badge_name,
                        url_name                      => $url_name,
                        description                   => $description,
                        keywords                      => $keywords,
                        show_publicly                 => $show_publicly,
                        private                       => $private,
                        display_subscribers           => $display_subscribers,
                        type                          => 'user',
                        requires_author_authorization => $self->param('requires_author_authorization') &&
                          $self->param('requires_author_authorization') eq 'open' ? 0 : 1,
                        requires_subscriber_authorization => $self->param('requires_subscriber_authorization') &&
                          $self->param('requires_subscriber_authorization') eq 'open' ? 0 : 1,
                        members_can_invite => $self->param('membership_requires_moderator_approval') &&
                          ($self->param('membership_requires_moderator_approval') eq 'open' ||
                            $self->param('membership_requires_moderator_approval') eq 'open_moderated') ? 1 : 0,
                        membership_requires_moderator_approval =>
                          $self->param('membership_requires_moderator_approval') &&
                          ($self->param('membership_requires_moderator_approval') eq 'open_moderated' ||
                            $self->param('membership_requires_moderator_approval') eq 'moderator_only') ? 1 : 0,
                    }
                );

                $self->add_stream_index($stream);

                $self->app->m->resultset('Stream::Moderator')->create(
                    {
                        meritcommons_user      => $user->id,
                        stream              => $stream->id,
                        allow_add_moderator => 1,
                        added_by            => $user->id,
                    }
                );

                $self->grant_subscription($user, $user, $stream, 1);
                $self->grant_authorship($user, $user, $stream, 1);

                $self->redirect_to('get_stream', { stream_identifier => $stream_identifier });
            } else {
                $self->reply->not_found;
            }
        }
    } else {
        return $self->rendered(400);
    }
}

sub permissions_handler {
    my ($self) = @_;

    if (my $user = $self->active_user) {
        my $sub_aut_mod = $self->stash('sub_aut_mod');
        my $target_user = $self->stash('target_user');
        if ($target_user) {
            $target_user = $user;
        }
        my $do = $self->stash('do');
        if ($do eq 'a') {
            $do = 'add';
        } elsif ($do eq 'r') {
            $do = 'remove';
        } elsif ($do eq 'u') {
            $do = 'authorize';
        }
        my $params = $self->req->params->to_hash;
        foreach my $key (keys %{$params}) {
            if ($key =~ /(subscription|authorship|moderatorship)_(.*)/) {
                my $stream_and_user = $2;
                my $stream_id;
                my $target_user;
                if ($stream_and_user =~ /(.*)_(.*)/) {
                    $stream_id = $1;
                    my $user_unique_id = $2;
                    $target_user = $self->user($user_unique_id);
                } else {
                    $stream_id   = $stream_and_user;
                    $target_user = $user;
                }
                if (!$target_user) {

                    # Needs a good way to tell the user if the input was bad, say for adding an aut or mod
                    return $self->redirect_to($self->req->headers->referrer);
                }
                if (my $stream = $self->stream($stream_id)) {
                    if ($sub_aut_mod eq 'sub') {
                        if ($do eq 'add') {
                            unless ($target_user->is_subscriber($stream)) {
                                if ($stream->requires_subscriber_authorization) {
                                    $self->add_subscription($user, $target_user, $stream);
                                } else {
                                    $self->grant_subscription($user, $target_user, $stream, 0);
                                }
                            }
                        } elsif ($do eq 'remove') {
                            $self->remove_subscription($user, $target_user, $stream);
                        } elsif ($do eq 'authorize') {
                            $self->authorize_subscription($user, $target_user, $stream);
                        } else {
                            $self->reply->not_found;
                        }
                    } elsif ($sub_aut_mod eq 'aut') {
                        if ($do eq 'add') {

                            # Can't force add an aut unless that user is also an authorized sub
                            if ($target_user->is_subscriber($stream) || $user == $target_user) {
                                unless ($target_user->is_author($stream)) {
                                    if ($stream->requires_author_authorization && !$user->can_moderate($stream)) {
                                        $self->add_authorship($user, $target_user, $stream);
                                    } else {
                                        $self->grant_authorship($user, $target_user, $stream, 0);
                                    }
                                }
                            } else {
                                $self->reply->not_found;
                            }
                        } elsif ($do eq 'remove') {
                            $self->remove_authorship($user, $target_user, $stream);
                        } elsif ($do eq 'authorize') {
                            $self->authorize_authorship($user, $target_user, $stream);
                        } else {
                            $self->reply->not_found;
                        }
                    } elsif ($sub_aut_mod eq 'mod') {
                        if ($do eq 'add') {
                            unless ($target_user->can_moderate($stream)) {
                                $self->grant_moderatorship($user, $target_user, $stream, 1);
                            }
                        } elsif ($do eq 'remove' && scalar($stream->moderators->all) > 0) {
                            $self->remove_moderatorship($user, $target_user, $stream);
                        } else {
                            $self->reply->not_found;
                        }
                    } else {
                        $self->reply->not_found;
                    }
                } else {
                    $self->reply->not_found;
                }
            } else {
                $self->reply->not_found;
            }
        }
        $self->redirect_to($self->req->headers->referrer);
    } else {
        $self->reply->not_found;
    }
}

sub list {
    my ($self) = @_;

    # If no page is given, assume the first page. Remove anything that's not a number.
    my $page = $self->param('page') || 1;
    $page =~ s|[^0-9]||g;
    if (!$page) {
        $page = 1;
    }

    my $sort_methods = {
        "name"     => "common_name",
        "name_rev" => "common_name DESC",
        "newest"   => "create_time DESC",
        "oldest"   => "create_time",
        "biggest"  => "subscriber_count DESC",
        "smallest" => "subscriber_count",
    };
    my $sortby = $self->param('sortby') || 'name';

    my $stream_search = $self->app->m->resultset('Stream')->search(
        {
            type          => [ 'user', undef ],
            disabled      => 0,
            show_publicly => 1,
            private       => 0,
        },
        {
            order_by => $sort_methods->{$sortby}
        }
    );

    my $page_size     = 10;
    my $streams_count = $stream_search->count;

    my $page_start = ($page * $page_size) - $page_size;
    my $page_end   = $page_start + ($page_size - 1);
    my $page_count = $streams_count / $page_size;

    # If there's a decimal part, just increment page count, because we'll need
    # another partial page at the end for the remainder.
    if ($page_count != sprintf("%d", $page_count)) {
        $page_count = sprintf("%d", $page_count) + 1;
    }

    my @streams = $stream_search->slice($page_start, $page_end);

    foreach my $s (@streams) {
        $s->{description_trunc_html} = markdown($self->app->truncate_htmlstrip($s->description, 200, 1));
    }

    # Figure out the page list
    my ($first_page, $last_page);
    if ($page_count <= 10) {
        $first_page = 1;
        $last_page  = $page_count;
    } elsif ($page_count > 10) {
        my $fdiff = 0;
        $first_page = $page - 4;
        if ($first_page < 1) {
            $fdiff      = abs($first_page) + 1;
            $first_page = 1;
        }

        $last_page = $page + 4;
        $last_page += $fdiff;
        my $ldiff = 0;
        if ($last_page > $page_count) {
            $ldiff     = $last_page - $page_count;
            $last_page = $page_count;
        }

        if ($ldiff) {
            $first_page -= $ldiff;
            if ($first_page < 1) {
                $first_page = 1;
            }
        }

    }

    $self->stash(alt_title_link => { href => "/streams/", title => 'All Streams' });
    $self->stash(streams        => \@streams);
    $self->stash(page_count     => $page_count);
    $self->stash(first_page     => $first_page);
    $self->stash(last_page      => $last_page);
    $self->stash(page           => $page);
    $self->stash(sortby         => $sortby);
    $self->render(template => "stream/list");
}

sub edit {
    my ($self) = @_;
    my $user = $self->active_user;

    # we need to prefetch + stash subscriptions
    $self->util->stash_stream_subscriptions;

    my $stream = $self->app->m->resultset('Stream')->search(
        {
            url_name => $self->stash('stream_identifier')
        }
    )->first;

    if ($user->can_moderate($stream)) {
        $self->stash(stream => $stream);

        my $settings = to_json(
            {
                id                             => $stream->unique_id,
                name                           => $stream->common_name,
                url                            => $stream->url_name,
                description                    => $stream->description,
                keywords                       => $stream->common_name,
                is_private                     => $stream->private,
                is_listed                      => $stream->show_publicly,
                is_membership_open             => !$stream->requires_subscriber_authorization,
                membership_includes_authorship => !$stream->requires_author_authorization,
                members_can_invite             => $stream->members_can_invite,
                invites_require_approval       => $stream->membership_requires_moderator_approval,
                list_members                   => $stream->display_subscribers,
                role_restricted                => 0,
                permitted_roles                => '',
            }
        );

        $self->stash(settings => $settings);

        $self->render(template => "stream/settings");
    } else {
        $self->flash(message    => 'You\'re not a moderator.');
        $self->flash(flash_type => 'danger');
        $self->flash(button     => 1);
        $self->redirect_to('get_stream', { stream_identifier => $self->stash('stream_identifier') });
    }
}

sub edit_details {
    my ($self) = @_;
    my $user = $self->active_user;

    my $stream = $self->app->m->resultset('Stream')->search(
        {
            url_name => $self->stash('stream_identifier')
        }
    )->first;

    my ($show_publicly) = $self->param('show_publicly') || 0;
    if ($show_publicly != 0 and $show_publicly != 1) {
        $show_publicly = 0;
    }

    my ($display_subscribers) = $self->param('display_subscribers') || 0;
    if ($display_subscribers != 0 and $display_subscribers != 1) {
        $display_subscribers = 0;
    }

    my ($private) = $self->param('private') || 0;
    if ($private != 0 and $private != 1) {
        $private = 0;
    }

    my ($requires_subscriber_authorization) = $self->param('subscription') || 0;
    if ($requires_subscriber_authorization != 0 and $requires_subscriber_authorization != 1) {
        $requires_subscriber_authorization = 0;
    }

    my ($requires_author_authorization) = $self->param('authorship') || 0;
    if ($requires_author_authorization != 0 and $requires_author_authorization != 1) {
        $requires_author_authorization = 0;
    }

    my ($membership_requires_moderator_approval) = $self->param('invitation');
    if ($membership_requires_moderator_approval eq 'open_moderated' ||
        $membership_requires_moderator_approval eq 'moderator_only') {
        $membership_requires_moderator_approval = 1;
    } else {
        $membership_requires_moderator_approval = 0;
    }

    my ($members_can_invite) = $self->param('invitation');
    if ($members_can_invite eq 'open' || $members_can_invite eq 'open_moderated') {
        $members_can_invite = 1;
    } else {
        $members_can_invite = 0;
    }

    if ($user->can_moderate($stream)) {
        $stream->update(
            {
                short_name                             => $self->param('short_name'),
                keywords                               => $self->param('keywords'),
                description                            => $self->param('description'),
                show_publicly                          => $show_publicly,
                private                                => $private,
                display_subscribers                    => $display_subscribers,
                requires_author_authorization          => $requires_author_authorization,
                requires_subscriber_authorization      => $requires_subscriber_authorization,
                membership_requires_moderator_approval => $membership_requires_moderator_approval,
                members_can_invite                     => $members_can_invite,
            }
        );
        $self->flash(message    => 'Your changes were saved.');
        $self->flash(flash_type => 'success');
        $self->flash(button     => 1);
    } else {
        $self->flash(message    => 'You\'re not a moderator.');
        $self->flash(flash_type => 'danger');
        $self->flash(button     => 1);
    }

    $self->redirect_to('get_stream', { stream_identifier => $self->stash('stream_identifier') });

}

sub user_list {
    my ($self) = @_;

    # we need to prefetch + stash subscriptions
    $self->util->stash_stream_subscriptions;

    my $stream = $self->app->m->resultset('Stream')->search(
        {
            url_name => $self->stash('stream_identifier')
        }
    )->first;

    $stream->{description_html} = markdown($self->app->htmlstrip($stream->description));

    # Should we list subscribers/etc for this stream in the first place?
    if (!$stream->display_subscribers) {
        $self->redirect_to('get_stream', { stream_identifier => $self->stash('stream_identifier') });
        return;
    }

    # If no page is given, assume the first page. Remove anything that's not a number.
    my $page = $self->param('page') || 1;
    $page =~ s|[^0-9]||g;
    if (!$page) {
        $page = 1;
    }

    my @users_all;
    if ($self->stash('list_type') eq 'subscribers') {
        @users_all = $stream->get_authed_subscribers;
    } elsif ($self->stash('list_type') eq 'moderators') {
        @users_all = $stream->moderators;
    } elsif ($self->stash('list_type') eq 'authors') {
        @users_all = $stream->get_authed_authors;
    }

    @users_all = sort { $a->meritcommons_user->common_name cmp $b->meritcommons_user->common_name } @users_all;

    my $page_size   = 30;
    my $users_count = scalar @users_all;

    my $page_start = ($page * $page_size) - $page_size;
    my $page_end   = $page_start + ($page_size - 1);
    my $page_count = $users_count / $page_size;

    # If there's a decimal part, just increment page count, because we'll need
    # another partial page at the end for the remainder.
    if ($page_count != sprintf("%d", $page_count)) {
        $page_count = sprintf("%d", $page_count) + 1;
    }

    my @users = @users_all[ $page_start .. ($page_end >= $users_count ? $users_count - 1 : $page_end) ];

    # Figure out the page list
    my ($first_page, $last_page);
    if ($page_count <= 10) {
        $first_page = 1;
        $last_page  = $page_count;
    } elsif ($page_count > 10) {
        my $fdiff = 0;
        $first_page = $page - 4;
        if ($first_page < 1) {
            $fdiff      = abs($first_page) + 1;
            $first_page = 1;
        }

        $last_page = $page + 4;
        $last_page += $fdiff;
        my $ldiff = 0;
        if ($last_page > $page_count) {
            $ldiff     = $last_page - $page_count;
            $last_page = $page_count;
        }

        if ($ldiff) {
            $first_page -= $ldiff;
            if ($first_page < 1) {
                $first_page = 1;
            }
        }

    }

    $self->stash(
        alt_title_link => {
            href  => "/s/" . $self->stash('stream_identifier') . "/" . $self->stash('list_type') . '/1',
            title => $stream->common_name . ' // ' . ucfirst($self->stash('list_type'))
        }
    );
    $self->stash(users              => \@users);
    $self->stash(stream_common_name => $stream->common_name);
    $self->stash(stream             => $stream);
    $self->stash(page_count         => $page_count);
    $self->stash(first_page         => $first_page);
    $self->stash(last_page          => $last_page);
    $self->stash(page               => $page);
    $self->render(template => "stream/user_list");
}

1;
