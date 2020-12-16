#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::DataUtil;

use Mojo::Base 'Mojolicious::Plugin';
use MeritCommons::Content;
use Date::Parse;
use Digest::CRC qw/crc32_hex/;
use MIME::Base64 qw/encode_base64/;
use Carp qw/croak/;
use List::MoreUtils qw/ uniq /;
use HTML::Truncate;
use Text::Wrap;
use Carp;
use Mojo::JSON qw/encode_json decode_json/;
use POSIX qw/strftime/;

our $truncate = HTML::Truncate->new(ellipsis => '...');

sub register {
    my ($self, $app) = @_;

    #
    #  _          _
    # | |__   ___| |_ __   ___ _ __ ___
    # | '_ \ / _ \ | '_ \ / _ \ '__/ __|
    # | | | |  __/ | |_) |  __/ |  \__ \
    # |_| |_|\___|_| .__/ \___|_|  |___/
    #              |_|
    #

    # global helpers
    $app->helper(message    => \&_message);
    $app->helper(stream     => \&_stream);
    $app->helper(user       => \&_user);
    
    #                    _     _
    #                   ( ) _ ( )_
    #    _ _  _   _    _| |(_)| ,_)
    #  /'_` )( ) ( ) /'_` || || |
    # ( (_| || (_) |( (_| || || |_
    # `\__,_)`\___/'`\__,_)(_)`\__)    
    #
    # helpers that query or establish an audit trail
    
    $app->helper('audit.log'                                    => \&_audit_log);

    #                _
    #    ___    _   (_)  ___
    #  /'___) /'_`\ | |/' _ `\
    # ( (___ ( (_) )| || ( ) |
    # `\____)`\___/'(_)(_) (_)
    #
    # helpers that deal with meritcommonscoins
    
    $app->helper('coin.request'                                 => \&_request_coins);
    $app->helper('coin.respond_to_request'                      => \&_respond_to_coin_request);
    $app->helper('coin.transfer'                                => \&_transfer_coins);
    $app->helper('coin.credit'                                  => \&_credit_coins);
    $app->helper('coin.balance'                                 => \&_bank_balance);
    $app->helper('coin.issuance'                                => \&_coins_in_circulation);

    #   ___ ___    ___    __  
    # /' _ ` _ `\/',__) /'_ `\
    # | ( ) ( ) |\__, \( (_) |
    # (_) (_) (_)(____/`\__  |
    #                  ( )_) |
    #                   \___/'
    #
    # helpers that operate on for a single message
    
    $app->helper('msg.ro'                                   => \&_message_ro);
    $app->helper('msg.add'                                  => \&_add_inbound_message);
    $app->helper('msg.edit'                                 => \&_edit_inbound_message);
    $app->helper('msg.prepare'                              => \&_prepare_payload_single);
    $app->helper('msg.attributes'                           => \&_prepare_payload_message_attributes);
    $app->helper('msg.add_outbound_attributes'              => \&_add_outbound_attributes);

    #   ___ ___     __    ___   ___    _ _    __     __    ___
    # /' _ ` _ `\ /'__`\/',__)/',__) /'_` ) /'_ `\ /'__`\/',__)
    # | ( ) ( ) |(  ___/\__, \\__, \( (_| |( (_) |(  ___/\__, \
    # (_) (_) (_)`\____)(____/(____/`\__,_)`\__  |`\____)(____/
    #                                      ( )_) |
    #                                       \___/'
    #
    # helpers that operate on multiple messages at once 
    
    $app->helper('messages.notifications'                       => \&_notifications);
    $app->helper('messages.merged'                              => \&_merged_messages);
    $app->helper('messages.from_single_stream'                  => \&_single_stream_messages);
    $app->helper('messages.from_multiple_streams'               => \&_multiple_stream_messages);   
    $app->helper('messages.prepare'                             => \&_prepare_payload);
    $app->helper('messages.prepare_collection'                  => \&_prepare_payload_collection);
    $app->helper('messages.submitted_by_user'                   => \&_user_messages);

    #        _
    #       ( )_
    #   ___ | ,_) _ __   __     _ _   ___ ___
    # /',__)| |  ( '__)/'__`\ /'_` )/' _ ` _ `\
    # \__, \| |_ | |  (  ___/( (_| || ( ) ( ) |
    # (____/`\__)(_)  `\____)`\__,_)(_) (_) (_)
    # 
    # helpers that operate on a single stream
    
    $app->helper('stream.ro'                                    => \&_stream_ro);
    $app->helper('stream.create'                                => \&_create_stream);
    $app->helper('stream.update'                                => \&_update_stream);
    $app->helper('stream.check_valid_url_name'                  => \&_check_valid_stream_url_name);
    $app->helper('stream.subscriber_count'                      => \&_subscriber_count);
    $app->helper('stream.generate_url_name'                     => \&_stream_generate_url_name);
    $app->helper('stream.approve_invitation'                    => \&_approve_invite);
    $app->helper('stream.respond_to_invitation'                 => \&_respond_to_invite);
    $app->helper('stream.invite'                                => \&_invite_to_stream);


    #        _                                                _
    #       ( )_                                             (_ )
    #   ___ | ,_) _ __   __     _ _   ___ ___     _ _    ___  | |
    # /',__)| |  ( '__)/'__`\ /'_` )/' _ ` _ `\ /'_` ) /'___) | |
    # \__, \| |_ | |  (  ___/( (_| || ( ) ( ) |( (_| |( (___  | |
    # (____/`\__)(_)  `\____)`\__,_)(_) (_) (_)`\__,_)`\____)(___)
    #
    # helpers that manipulate stream access control lists
    
    # authorship ACL methods
    $app->helper('streamacl.grant_authorship'                   => \&_grant_authorship);
    $app->helper('streamacl.add_authorship'                     => \&_add_authorship);
    $app->helper('streamacl.authorize_authorship'               => \&_authorize_authorship);
    $app->helper('streamacl.deauthorize_authorship'             => \&_deauthorize_authorship);
    $app->helper('streamacl.remove_authorship'                  => \&_remove_authorship);

    # subscription ACL methods
    $app->helper('streamacl.grant_subscription'                 => \&_grant_subscription);
    $app->helper('streamacl.add_subscription'                   => \&_add_subscription);
    $app->helper('streamacl.authorize_subscription'             => \&_authorize_subscription);
    $app->helper('streamacl.deauthorize_subscription'           => \&_deauthorize_subscription);
    $app->helper('streamacl.remove_subscription'                => \&_remove_subscription);

    # moderatorship ACL methods
    $app->helper('streamacl.grant_moderatorship'                => \&_add_moderatorship);
    $app->helper('streamacl.add_moderatorship'                  => \&_add_moderatorship);
    $app->helper('streamacl.add_allow_add_moderator'            => \&_add_allow_add_moderator);
    $app->helper('streamacl.remove_allow_add_moderator'         => \&_remove_allow_add_moderator);
    $app->helper('streamacl.remove_moderatorship'               => \&_remove_moderatorship);
    
    # query stream ACL
    $app->helper('streamacl.get_permissions'                    => \&_get_permissions);
    
    #        _
    #       ( )_
    #   ___ | ,_) _ __   __     _ _   ___ ___    ___
    # /',__)| |  ( '__)/'__`\ /'_` )/' _ ` _ `\/',__)
    # \__, \| |_ | |  (  ___/( (_| || ( ) ( ) |\__, \
    # (____/`\__)(_)  `\____)`\__,_)(_) (_) (_)(____/
    # 
    # helpers that operate on multiple streams at once
    
    $app->helper('streams.moderated_by'                         => \&_streams_moderated_by);
    
    #        _
    #       ( )_        _
    #   ___ | ,_) _ __ (_)  ___     __
    # /',__)| |  ( '__)| |/' _ `\ /'_ `\
    # \__, \| |_ | |   | || ( ) |( (_) |
    # (____/`\__)(_)   (_)(_) (_)`\__  |
    #                            ( )_) |
    #                             \___/'
    # 
    # helpers that manipulate string inputs then return them

    $app->helper('string.truncate'                              => \&_truncate);
    $app->helper('string.truncate_htmlstrip'                    => \&_truncate_htmlstrip);
    $app->helper('string.htmlstrip'                             => \&_htmlstrip);

    #                           _
    #   ___    __    ___   ___ (_)   _     ___
    # /',__) /'__`\/',__)/',__)| | /'_`\ /' _ `\
    # \__, \(  ___/\__, \\__, \| |( (_) )| ( ) |
    # (____/`\____)(____/(____/(_)`\___/'(_) (_)
    # 
    # helpers that operate on session objects

    $app->helper('session.created_from'                         => \&_resolve_session_created_from);

    #         _       _
    #        ( )_  _ (_ )
    #  _   _ | ,_)(_) | |
    # ( ) ( )| |  | | | |
    # | (_) || |_ | | | |
    # `\___/'`\__)(_)(___)
    #
    # helpers that facilitate common or miscellaneous functions
    
    $app->helper('util.stream'                                  => \&_stream);
    $app->helper('util.message'                                 => \&_message);
    $app->helper('util.user'                                    => \&_user);
    $app->helper('util.profile_picture_url_for'                 => \&_profile_picture_url_for);
    $app->helper('util.profile_picture_url_for_stream'          => \&_profile_picture_url_for_stream);
    $app->helper('util.profile_picture_url_for_user'            => \&_profile_picture_url_for_user);
    $app->helper('util.invitation'                              => \&_invite);
    $app->helper('util.stash_stream_subscriptions'              => \&_stash_subscriptions);

    #  _   _   ___    __   _ __
    # ( ) ( )/',__) /'__`\( '__)
    # | (_) |\__, \(  ___/| |
    # `\___/'(____/`\____)(_)
    # 
    # helpers that operate on a single user

    $app->helper('user.ro'                                      => \&_user_ro);
    $app->helper('user.add_with_streams'                        => \&_add_user_with_streams);
    $app->helper('user.add_identity'                            => \&_add_identity_to_user);
    $app->helper('user.render_info_to_string'                   => \&_render_user_info_string);

    #  _   _   ___    __   _ __   ___
    # ( ) ( )/',__) /'__`\( '__)/',__)
    # | (_) |\__, \(  ___/| |   \__, \
    # `\___/'(____/`\____)(_)   (____/
    # 
    # helpers that operate on multiple users at once

    $app->helper('users.by_config_val'                          => \&_users_by_config_val);
    $app->helper('users.search'                                 => \&_search_users);

    #      _                                          _               _
    #     ( )                                        ( )_            ( )
    #    _| |   __   _ _    _ __   __     ___    _ _ | ,_)   __     _| |
    #  /'_` | /'__`\( '_`\ ( '__)/'__`\ /'___) /'_` )| |   /'__`\ /'_` |
    # ( (_| |(  ___/| (_) )| |  (  ___/( (___ ( (_| || |_ (  ___/( (_| |
    # `\__,_)`\____)| ,__/'(_)  `\____)`\____)`\__,_)`\__)`\____)`\__,_)
    #               | |
    #               (_)
    #
    # deprecated helpers that spew errors pointing users to new helpers

    $app->deprecated_helper(message_ro                         => \&_message_ro, '$c->msg->ro', 'Helper renamed');
    $app->deprecated_helper(stream_ro                          => \&_stream_ro, '$c->stream->ro', 'Helper renamed');
    $app->deprecated_helper(user_ro                            => \&_user_ro, '$c->user->ro', 'Helper renamed');
    $app->deprecated_helper(profile_picture_url_for            => \&_profile_picture_url_for, '$c->util->profile_picture_url_for', 'Helper renamed');
    $app->deprecated_helper(profile_picture_url_for_stream     => \&_profile_picture_url_for_stream, '$c->util->profile_picture_url_for_stream', 'Helper renamed');
    $app->deprecated_helper(profile_picture_url_for_user       => \&_profile_picture_url_for_user, '$c->util->profile_picture_url_for_user', 'Helper renamed');
    $app->deprecated_helper(add_user_with_streams              => \&_add_user_with_streams, '$c->user->add_with_streams', 'Helper renamed');
    $app->deprecated_helper(notifications                      => \&_notifications, '$c->messages->notifications', 'Helper renamed');
    $app->deprecated_helper(merged_messages                    => \&_merged_messages, '$c->messages->merged', 'Helper renamed');
    $app->deprecated_helper(single_stream_messages             => \&_single_stream_messages, '$c->messages->from_single_stream', 'Helper renamed');
    $app->deprecated_helper(multiple_stream_messages           => \&_multiple_stream_messages, '$c->messages->from_multiple_streams', 'Helper renamed');
    $app->deprecated_helper(stream_generate_url_name           => \&_stream_generate_url_name, '$c->stream->generate_url_name', 'Helper renamed');
    $app->deprecated_helper(prepare_payload                    => \&_prepare_payload, '$c->messages->prepare', 'Helper renamed');
    $app->deprecated_helper(prepare_payload_collection         => \&_prepare_payload_collection, '$c->messages->prepare_collection', 'Helper renamed');
    $app->deprecated_helper(prepare_payload_single             => \&_prepare_payload_single, '$c->msg->prepare', 'Helper renamed');
    $app->deprecated_helper(prepare_payload_message_attributes => \&_prepare_payload_message_attributes, '$c->msg->attributes', 'Helper renamed');
    $app->deprecated_helper(user_messages                      => \&_user_messages, '$c->messages->submitted_by_user', 'Helper renamed');
    $app->deprecated_helper(add_inbound_message                => \&_add_inbound_message, '$c->msg->add', 'Helper renamed');
    $app->deprecated_helper(edit_inbound_message               => \&_edit_inbound_message, '$c->msg->edit', 'Helper renamed');
    $app->deprecated_helper(add_identity_to_user               => \&_add_identity_to_user, '$c->user->add_identity', 'Helper renamed');
    $app->deprecated_helper(truncate                           => \&_truncate, '$c->string->truncate', 'Helper renamed');
    $app->deprecated_helper(truncate_htmlstrip                 => \&_truncate_htmlstrip, '$c->string->truncate_htmlstrip', 'Helper renamed');
    $app->deprecated_helper(htmlstrip                          => \&_htmlstrip, '$c->string->htmlstrip', 'Helper renamed');
    $app->deprecated_helper(subscriber_count                   => \&_subscriber_count, '$c->stream->subscriber_count', 'Helper renamed');
    $app->deprecated_helper(streams_moderated_by               => \&_streams_moderated_by, '$c->streams->moderated_by', 'Helper renamed');
    $app->deprecated_helper(users_by_config_val                => \&_users_by_config_val, '$c->users->by_config_val', 'Helper renamed');
    $app->deprecated_helper(add_outbound_attributes            => \&_add_outbound_attributes, '$c->msg->add_outbound_attributes', 'Helper renamed');
    $app->deprecated_helper(dbix_search_users                  => \&_search_users, '$c->users->search', 'Helper renamed');
    $app->deprecated_helper(create_stream                      => \&_create_stream, '$c->stream->create', 'Helper renamed');
    $app->deprecated_helper(audit_log                          => \&_audit_log, '$c->audit->log', 'Helper renamed');
    $app->deprecated_helper(update_stream                      => \&_update_stream, '$c->stream->update', 'Helper renamed');
    $app->deprecated_helper(check_valid_stream_url_name        => \&_check_valid_stream_url_name, '$c->stream->check_valid_url_name', 'Helper renamed');
    $app->deprecated_helper(render_user_info_string            => \&_render_user_info_string, '$c->user->render_info_to_string', 'Helper renamed');
    $app->deprecated_helper(resolve_session_created_from       => \&_resolve_session_created_from, '$c->session->created_from', 'Helper renamed');

    # authorship ACL methods
    $app->deprecated_helper(grant_authorship                    => \&_grant_authorship, '$c->streamacl->grant_authorship', 'Helper renamed');
    $app->deprecated_helper(add_authorship                      => \&_add_authorship, '$c->streamacl->add_authorship', 'Helper renamed');
    $app->deprecated_helper(authorize_authorship                => \&_authorize_authorship, '$c->streamacl->authorize_authorship', 'Helper renamed');
    $app->deprecated_helper(deauthorize_authorship              => \&_deauthorize_authorship, '$c->streamacl->deauthorize_authorship', 'Helper renamed');
    $app->deprecated_helper(remove_authorship                   => \&_remove_authorship, '$c->streamacl->remove_authorship', 'Helper renamed');

    # subscription ACL methods
    $app->deprecated_helper(grant_subscription                  => \&_grant_subscription, '$c->streamacl->grant_subscription', 'Helper renamed');
    $app->deprecated_helper(add_subscription                    => \&_add_subscription, '$c->streamacl->add_subscription', 'Helper renamed');
    $app->deprecated_helper(authorize_subscription              => \&_authorize_subscription, '$c->streamacl->authorize_subscription', 'Helper renamed');
    $app->deprecated_helper(deauthorize_subscription            => \&_deauthorize_subscription, '$c->streamacl->deauthorize_subscription', 'Helper renamed');
    $app->deprecated_helper(remove_subscription                 => \&_remove_subscription, '$c->streamacl->remove_subscription', 'Helper renamed');

    # moderatorship ACL methods
    $app->deprecated_helper(grant_moderatorship                 => \&_add_moderatorship, '$c->streamacl->grant_moderatorship', 'Helper renamed');
    $app->deprecated_helper(add_moderatorship                   => \&_add_moderatorship, '$c->streamacl->add_moderatorship', 'Helper renamed');
    $app->deprecated_helper(add_allow_add_moderator             => \&_add_allow_add_moderator, '$c->streamacl->add_allow_add_moderator', 'Helper renamed');
    $app->deprecated_helper(remove_allow_add_moderator          => \&_remove_allow_add_moderator, '$c->streamacl->remove_allow_add_moderator', 'Helper renamed');
    $app->deprecated_helper(remove_moderatorship                => \&_remove_moderatorship, '$c->streamacl->remove_moderatorship', 'Helper renamed');

    # ACL query methods
    $app->deprecated_helper(get_permissions                     => \&_get_permissions, '$c->streamacl->get_permissions', 'Helper renamed');

    # Invites.
    $app->deprecated_helper(invite                              => \&_invite, '$c->util->invitation', 'Helper renamed');
    $app->deprecated_helper(approve_invite                      => \&_approve_invite, '$c->stream->approve_invitation', 'Helper renamed');
    $app->deprecated_helper(respond_to_invite                   => \&_respond_to_invite, '$c->stream->respond_to_invitation', 'Helper renamed');
    $app->deprecated_helper(invite_to_stream                    => \&_invite_to_stream, '$c->stream->invite', 'Helper renamed');

    # Coins.
    $app->deprecated_helper(request_coins                       => \&_request_coins, '$c->coin->request', 'Helper renamed');
    $app->deprecated_helper(respond_to_coin_request             => \&_respond_to_coin_request, '$c->coin->respond_to_request', 'Helper renamed');
    $app->deprecated_helper(transfer_coins                      => \&_transfer_coins, '$c->coin->transfer', 'Helper renamed');
    $app->deprecated_helper(credit_coins                        => \&_credit_coins, '$c->coin->credit', 'Helper renamed');
    $app->deprecated_helper(bank_balance                        => \&_bank_balance, '$c->coin->balance', 'Helper renamed');
    $app->deprecated_helper(coins_in_circulation                => \&_coins_in_circulation, '$c->coin->issuance', 'Helper renamed');

    # former around_action hook
    $app->deprecated_helper(stash_subscriptions                 => \&_stash_subscriptions, '$c->util->stash_stream_subscriptions', 'Helper renamed');

    #                       _
    #   _____   _____ _ __ | |_ ___
    #  / _ \ \ / / _ \ '_ \| __/ __|
    # |  __/\ V /  __/ | | | |_\__ \
    #  \___| \_/ \___|_| |_|\__|___/
    #
    
    $app->on(session_established => \&_sync_role_streams);    # sync the role streams!
}

# required for Merge, stream/default.html.ep, and sidebar.html.ep, uses active_user
# CANNOT BE RUN FROM A COMMAND.
sub _stash_subscriptions {
    my ($c) = @_;

    if (my $user = $c->active_user) {
        my @authorized_authorships = $c->rorm->resultset('Stream')->search(
            {
                'authors.authorized'     => 1,
                'authors.meritcommons_user' => $user->id
            },
            {
                join => ['authors']
            }
        )->all;

        $c->stash(authorized_authorships => \@authorized_authorships);

        my @all_subscriptions = $c->rorm->resultset('Stream::Subscriber')->search(
            {
                'me.meritcommons_user' => $user->id,
                'me.authorized' => 1,
            },
            {
                prefetch => ['stream']
            }
        )->all;

        my %all_subscription_streams = ();
        foreach my $sub (@all_subscriptions) {
            my $subtype = $sub->stream->subtype;
            if (!defined $subtype) {
                if (defined $sub->stream->personal_outbox_user) {
                    $subtype = 'People';
                } elsif ($sub->stream->type && $sub->stream->type eq "role") {
                    $subtype = 'Roles';
                } else {
                    if (defined $c->global_config->{default_subscription_block_title}) {
                        $subtype = $c->global_config->{default_subscription_block_title};
                    } else {
                        $subtype = '__UNDEFINED__';
                    }
                }
            }
            if (exists $all_subscription_streams{$subtype}) {
                push(@{ $all_subscription_streams{$subtype} }, $sub->stream);
            } else {
                $all_subscription_streams{$subtype} = [ $sub->stream ];
            }
        }

        $c->stash(all_subscriptions_by_subtype => {%all_subscription_streams});
        $c->stash(is_admin                     => $user->is_admin);
    }
}

sub _search_users {
    my ($self, $search_string, $extra, $join) = @_;

    my @words = split(/\s+/, $search_string);

    my $default = [
        'me.common_name' => { -ilike => "$search_string%" },
        'me.common_name' => { -ilike => "%$search_string" },
        'me.userid'      => { -ilike => "$search_string%" },
        'me.common_name' => { -ilike => "%@{[join('%', @words)]}%" },
    ];

    my $default_sj = [
        order_by => "common_name ilike " . $self->app->m->storage->dbh->quote("$search_string%") .
          " desc, common_name ilike " . $self->app->m->storage->dbh->quote("$words[0]%") . "desc, common_name asc",
        rows => 200,
    ];

    if (ref($join) eq "ARRAY") {
        push(@$default_sj, @$join);
    }

    my $users = $self->app->rorm->resultset('User')->search(
        {
            -or => $default,
            ref $extra eq "ARRAY" ? @$extra : (),
        },
        {@$default_sj}
    );

    return $users->all;
}

# this code was in pretty much every content driver's outbound... putting it in one place for simplicity
sub _add_outbound_attributes {
    my ($self, $content, $actor) = @_;

    $content->{day_hhmmss}         = $self->app->day_hhmmss($content->post_time);
    $content->{post_time_pretty}   = $self->app->time_mmddyy_hhmmss($content->post_time);
    $content->{post_day_pretty}    = $self->app->time_week_month_day($content->post_time);
    $content->{abbr_ago}           = $self->app->abbr_ago($content->post_time);
    $content->{seconds_since_post} = (time - $content->post_time);

    my $edits = $content->{message}->changes;
    if ($edits->count) {
        my $latest =
          $edits->search({ create_time => $content->{message}->changes->get_column('create_time')->max() })->first;

        if ($latest) {
            $content->{edited}    = 1;
            $content->{edited_on} = $self->app->time_mmddyy_hhmmss($latest->create_time);
            $content->{editor}    = defined $latest->actor;
            if ($content->{editor}) {
                $content->{editor_userid}            = $latest->actor->userid;
                $content->{editor_common_name}       = $latest->actor->common_name;
                $content->{editor_profile_url}       = "/u/@{[$latest->actor->unique_id]}/";
                $content->{editor_profile_thumb_url} = $self->profile_picture_url_for($latest->actor, 'thumbnail');
                $content->{editor_profile_tiny_url}  = $self->profile_picture_url_for($latest->actor, 'tiny');
            }
        }
    }

    no warnings 'uninitialized';

    my $masked;
    if (my $mask = $content->{submitter_mask}) {
        my ($entity_type, $unique_id) = split(/:/, $mask, 2);
        if ($entity_type eq "stream") {
            my $m_stream = $self->stream($unique_id);

            $content->{submitter_userid}            = $content->submitter->userid;
            $content->{submitter_profile_url}       = "/s/@{[$m_stream->url_name // $m_stream->unique_id]}/";
            $content->{submitter_common_name}       = $m_stream->common_name;
            $content->{submitter_profile_thumb_url} = $self->profile_picture_url_for_stream($m_stream, 'thumbnail');
            $content->{submitter_profile_tiny_url}  = $self->profile_picture_url_for_stream($m_stream, 'tiny');

            # set this flag so we don't clobber with the actual submitter's info below..
            $content->{masked} = 1;
        } elsif ($entity_type eq "user") {
            unless ($unique_id eq $content->submitter->unique_id) {
                $self->app->log->error(
                    "weird business... user @{[$content->submitter->userid]} trying to send a message as $unique_id");
            }
        }
    }

    unless ($content->masked) {
        $content->{submitter_userid}            = $content->submitter->userid;
        $content->{submitter_profile_url}       = "/u/" . $content->submitter->userid . "/";
        $content->{submitter_common_name}       = $content->submitter->common_name;
        $content->{submitter_profile_thumb_url} = $self->profile_picture_url_for($content->submitter, 'thumbnail');
        $content->{submitter_profile_tiny_url}  = $self->profile_picture_url_for($content->submitter, 'tiny');
        $content->{submitter_flair}             = "@{[$content->submitter->flair]}";
    }

    return $content;
}

# a list of streams moderated by a user
sub _streams_moderated_by {
    my ($c, $user, $include_single_subscriber, $include_personal_outbox) = @_;

    # these have to be integers
    $include_single_subscriber = $include_single_subscriber ? 1 : 0;

    my $search = { 'moderators.meritcommons_user' => $user->id, };

    unless ($include_single_subscriber) {
        $search->{'stream.single_subscriber'} = '0';
    }

    unless ($include_personal_outbox) {
        $search->{'stream.personal_outbox_user'} = undef;
    }

    return $c->rorm->resultset('Stream')->search(
        $search,
        {
            join => { moderators => ['stream'] },
        }
    )->all;
}

# get all users that have a configuration attribute set to a certain value
sub _users_by_config_val {
    my ($c, $k, $val) = @_;

    $k = "_config_$k" unless $k =~ /^_config_/;

    return $c->rorm->resultset("User")->search(
        {
            "attributes.k" => $k,
            "vals.v"       => $val,
        },
        {
            join => {
                attributes => {
                    vals => "attribute",
                },
            },
            distinct => 1,
        }
    )->all;
}

# takes a list of stream unique_ids and returns audience size
sub _subscriber_count {
    my ($c, @streams) = @_;

    return $c->rorm->resultset('User')->search(
        {
            'stream.unique_id' => [@streams],
        },
        {
            join     => { subscriptions => ['stream'] },
            distinct => 1,
        }
    )->count;
}

# takes a hashref similar to DBIx->create({});
sub _add_user_with_streams {
    my ($controller, $opts) = @_;

    my $config = $controller->app->config;
    my $model  = $controller->app->m;

    # let's make sure the user doesn't already exist.
    my $user = $model->resultset('User')->search(
        {
            userid => $opts->{userid},
        }
    )->first;

    if ($user) {
        print "[error]: record already exists as userid " . $user->id . "\n";
        return;
    }

    # we have problems if there's weird spacing, so I'm going to clean these just in case...
    my $userid = $opts->{userid};
    my $cn     = $opts->{common_name};

    # get rid of leading and trailing whitespace from usernames.
    $userid =~ s/^\s*(.+?)\s*$/$1/;

    # get rid of any instances of multiple space characters in the username
    $userid =~ s/(\s)\s+/$1/g;

    # same things with the common_name
    $cn =~ s/^\s*(.+?)\s*$/$1/;
    $cn =~ s/(\s)\s+/$1/g;

    $opts->{email_address}     //= '';
    $opts->{identity_resource} //= "unknown:$userid";

    # finally create the user.
    $user = $model->resultset('User')->create(
        {
            userid            => $userid,
            common_name       => $cn,
            identity_resource => $opts->{identity_resource},
            unique_id         => $controller->app->new_uuid,
            email_address     => $opts->{email_address},
            title             => $opts->{title},
        }
    );

    my $free_url_name;
    my $proposed_url_name = $user->userid;
    until ($free_url_name) {
        if ($model->resultset('Stream')->find({ url_name => $proposed_url_name })) {
            my (@nc) = split(/-/, $proposed_url_name);
            if (scalar(@nc) > 1) {
                if ($nc[$#nc] =~ /^\d+$/) {
                    # increment the last "component" if it's a digit.
                    $nc[$#nc]++;
                    $proposed_url_name = join('-', @nc);
                } else {
                    # add the last component as a digit.  there are other hyphen components.  cool.
                    $proposed_url_name = join('-', @nc, 1);
                }
            } else {
                # no other hyphen components, append the last one as a string.
                $proposed_url_name = "$proposed_url_name-1";
            }
        } else {
            $free_url_name = $proposed_url_name;
        }
    }

    # create the user's personal_outbox.
    my $outbox = $model->resultset('Stream')->create(
        {
            common_name                   => $user->common_name,
            url_name                      => $free_url_name,
            unique_id                     => $controller->app->new_uuid,
            creator                       => $user->id,
            single_author                 => 1,
            requires_author_authorization => 1,
            personal_outbox_user          => $user->id,
            type                          => 'system',
        }
    );

    # stream permissions
    $model->resultset('Stream::Moderator')->create(
        {
            meritcommons_user => $user->id,
            stream         => $outbox->id,
            added_by       => 1,             # the system user.
        }
    );

    $model->resultset('Stream::Author')->create(
        {
            meritcommons_user => $user->id,
            stream         => $outbox->id,
            authorized     => 1,
            allow_edit     => 1,
            added_by       => 1,             # the system user.
        }
    );

    # subscribe them to their own stream
    $model->resultset('Stream::Subscriber')->create(
        {
            meritcommons_user => $user->id,
            stream         => $outbox->id,
            authorized     => 1,
            allow_history  => 1,
            added_by       => 1,             # the system user.
        }
    );

    $controller->add_stream_index($outbox);

    # create the user's personal_inbox.
    my $inbox = $model->resultset('Stream')->create(
        {
            common_name                   => '_' . $user->userid,
            unique_id                     => $controller->app->new_uuid,
            creator                       => $user->id,
            single_subscriber             => 1,
            requires_author_authorization => 0,
            personal_inbox_user           => $user->id,
            type                          => 'system',
        }
    );

    # stream permissions
    $model->resultset('Stream::Moderator')->create(
        {
            meritcommons_user => $user->id,
            stream         => $inbox->id,
            added_by       => 1,            # the system user.
        }
    );

    # subscribe them to their own stream
    $model->resultset('Stream::Subscriber')->create(
        {
            meritcommons_user => $user->id,
            stream         => $inbox->id,
            authorized     => 1,
            allow_history  => 1,
            added_by       => 1,            # the system user.
        }
    );

    # create the user's notification_inbox.
    my $notification_inbox = $model->resultset('Stream')->create(
        {
            common_name                   => '__' . $user->userid,
            unique_id                     => $controller->app->new_uuid,
            creator                       => $user->id,
            single_subscriber             => 1,
            requires_author_authorization => 0,
            notification_inbox_user       => $user->id,
            type                          => 'system',
        }
    );

    # stream permissions
    $model->resultset('Stream::Moderator')->create(
        {
            meritcommons_user => $user->id,
            stream         => $notification_inbox->id,
            added_by       => 1,                         # the system user.
        }
    );

    # subscribe them to their own stream
    $model->resultset('Stream::Subscriber')->create(
        {
            meritcommons_user => $user->id,
            stream         => $notification_inbox->id,
            authorized     => 1,
            allow_history  => 1,
            added_by       => 1,                         # the system user.
        }
    );

    # update the user with the new streams in their respective roles.
    $user->personal_inbox($inbox->id);
    $user->personal_outbox($outbox->id);
    $user->notification_inbox($notification_inbox->id);
    $user->update;

    # subscribe them to stream 1, the system stream.
    $model->resultset('Stream::Subscriber')->create(
        {
            meritcommons_user => $user->id,
            stream         => 1,
            authorized     => 1,
            allow_history  => 1,
            added_by       => 1,           # the system user.
        }
    );

    # finally, add this user to sphinx!
    $controller->add_user_index($user);

    # run event hooks
    $controller->app->emit('created_user', $user);

    # log it
    $controller->audit_log("created new user @{[$user->userid]} (@{[$user->unique_id]}) with streams");

    return $user;
}

# figure out if we're a stream or a user (or we want it to get active_user)
sub _profile_picture_url_for {
    my ($self, $obj, $size) = @_;

    if (ref $obj eq "MeritCommons::Model::Stream") {
        return $self->util->profile_picture_url_for_stream($obj, $size);
    }

    return $self->util->profile_picture_url_for_user($obj, $size);
}

# get the right profile url, every time!
sub _profile_picture_url_for_stream {
    my ($self, $stream, $size) = @_;
    return undef unless $stream;
    $size = "small" unless $size;

    my $purl;
    if ($stream) {
        if (my $pp = $stream->profile_picture) {
            $purl = $pp->url($size);
        } else {
            $purl = $self->asset_url("img/no_profile_${size}.png");
        }
    }

    if ($purl) {
        return $purl;
    }
    return undef;
}

# get the right profile url, every time!
sub _profile_picture_url_for_user {
    my ($self, $user, $size) = @_;
    $user = $self->active_user unless $user;
    $size = "small"            unless $size;
    my $g_method = "gravatar_${size}_url";

    my $purl;
    if ($user) {
        if (my $pp = $user->profile_picture) {
            $purl = $pp->url($size);
        } elsif (my $gurl = $user->$g_method) {
            $purl = $gurl;
        } else {
            $purl = $self->asset_url("img/no_profile_${size}.png");
        }
    }

    if ($purl) {
        return $purl;
    }
    return undef;
}

sub _resolve_session_created_from {
    my ($self, $session) = @_;
    
    # resolve this to its cached lookup if it was too big to fit in the column...
    my $cf = $session->created_from;
    
    if ($cf) {
        if ($cf =~ /,/) {
            return $cf;
        } else {
            return $self->cache->get($cf);
        }
    }
    return undef;
}

sub _sync_role_streams {
    my ($self, $c, $session) = @_;

    if (my $user = $session->meritcommons_user) {

        # get the roles this user has!!
        my @roles = map { $_->common_name } $user->roles;

        foreach my $role (@roles) {

            # see if this stream exists already.
            my $stream = $self->m->resultset('Stream')->single(
                {
                    common_name => ucfirst($role),
                    type        => "role",
                }
            );

            # create it if we couldn't find it!
            unless ($stream) {
                my ($badge_name) = $role =~ /^([^\s]{1,4})/;
                $stream = $self->m->resultset('Stream')->create(
                    {
                        common_name => ucfirst($role),
                        unique_id   => $self->app->new_uuid,
                        creator    => 1,              # Hard-coded to MeritCommons System, which should always be id 1!
                        short_name => $badge_name,
                        url_name   => "role:$role",
                        description                       => "Stream for the '$role' role",
                        show_publicly                     => 0,
                        display_subscribers               => 0,
                        type                              => 'role',
                        requires_author_authorization     => 1,
                        requires_subscriber_authorization => 1,
                        private                           => 1,
                        allow_unsubscribe                 => 0,
                    }
                );
            }

            unless ($user->is_subscriber($stream)) {

                # give this user access to these streams.
                $c->grant_subscription($self->user(1), $user, $stream, 1);
            }
        }

        foreach my $sub (
            $user->subscriptions->search({ 'stream.type' => 'role' }, { join => 'stream', prefetch => 'stream' })) {
            my $has_role;
            foreach my $role (@roles) {
                if (ucfirst($role) eq $sub->stream->common_name) {
                    $has_role = 1;
                    last;
                }
            }

            unless ($has_role) {
                $sub->delete;
            }
        }
    }
}

sub _add_inbound_message {
    my ($self, $actor, $content) = @_;

    my $data = { success => 1 };
    if ($actor) {
        if ($content->body) {

            if ($self->global_config->{inbound_debug}) {
                $self->app->log->info("[inbound_debug] as received by inbound " . $content->body);
            }

            # THE ONE CHANGE WE MAKE UNIVERSALLY....
            # get rid of <'s, replace with &lt;
            $content->{body} =~ s/</&lt;/g;

            # Ensure that replies are assigned the same streams and public attributes of the parent.
            # Also, translate the in_reply_to value from a unique_id to an id
            if ($content->in_reply_to) {
                my $reply_msg = $self->app->m->resultset('Stream::Message')->search(
                    {
                        unique_id => $content->in_reply_to
                    }
                )->first;

                if ($reply_msg) {
                    $content->{attempted_streams} = [ $reply_msg->streams ];
                    $content->{public}            = $reply_msg->public;
                    $content->{thread_id}         = $reply_msg->thread_id;
                } else {
                    $content->{in_reply_to} = undef;
                }
            }

            # Execute the content driver stack before checking source perms, as some drivers will extrapolate sources from
            # the content.
            $content = $self->cd_inbound($content, $actor);

            if ($self->global_config->{inbound_debug}) {
                $self->app->log->info("[inbound_debug] after content drivers " . $content->body);
            }

            # compute the cost of sending the message right here.
            my $total_cost = $self->subscriber_count(map { $_->unique_id } @{ $content->{attempted_streams} });
            my $meritcommonscoin_balance = $actor->meritcommonscoin_balance;
            my $used_meritcommonscoins;

            # now for permish.
            foreach my $stream (@{ $content->attempted_streams }) {

                # skip streams we couldn't find.
                next unless $stream;

                if ($content->in_reply_to) {

                    # Authorization is bypassed for replies.  This will later be expanded
                    # to also require that the stream is configured to allow open replies.
                    push(@{ $content->streams }, $stream);
                } else {

                    # Verify that the user can write to the stream
                    if ($actor->can_write($stream)) {
                        push(@{ $content->streams }, $stream);
                    } else {
                        if ($meritcommonscoin_balance >= $total_cost) {
                            if ($stream->id != 1) {
                                push(@{ $content->streams }, $stream);
                                $used_meritcommonscoins = 1;
                                push(
                                    @{ $data->{sent} },
                                    {
                                        stream_id   => $stream->unique_id,
                                        stream_name => $stream->common_name,
                                        reason      => $actor->userid . " paid meritcommonscoins to send this message.",
                                    }
                                );
                            }
                        } else {
                            push(
                                @{ $data->{not_sent} },
                                {
                                    stream_id   => $stream->unique_id,
                                    stream_name => $stream->common_name,
                                    reason      => $actor->userid . " not authorized to send to stream.",
                                }
                            );
                        }
                    }
                }
            }

            # if the balance in the db changed during this check, let's just quit.  someone's being weird.
            return undef unless $meritcommonscoin_balance == $actor->meritcommonscoin_balance;

            # if the user was denied access to any of the targeted streams, let's see if they have the coin to
            # bend the rules a little *wink*, *wink*.
            if ($used_meritcommonscoins) {

                # make sure we charge them for the privilege...
                $actor->meritcommonscoin_balance($meritcommonscoin_balance - $total_cost);
                $actor->update();

                # and make a record of our dealings...
                $actor->meritcommonscoin_transactions->create(
                    {
                        previous_balance  => $meritcommonscoin_balance,
                        resulting_balance => $meritcommonscoin_balance - $total_cost,
                        amount            => $total_cost,
                        transaction_type  => 'spend',
                        role              => 'buyer',
                        transaction_id    => $self->new_uuid,
                    }
                );

                my $a_personal_inbox = $actor->personal_inbox;

                # add the submitter's personal inbox so they can see and interact with the conversation.
                unless (grep { $_->unique_id eq $a_personal_inbox->unique_id } @{ $content->streams }) {
                    push(@{ $content->streams }, $a_personal_inbox);
                }
            }

            if (scalar(@{ $content->streams })) {
                my $unique_id = $self->app->new_uuid;

                # put the message in the database, if there's at least one legit stream attached
                my $msg = $self->app->m->resultset('Stream::Message')->create(
                    {
                        submitter          => $actor->id,
                        body               => $content->body,
                        render_as          => $content->render_as,
                        unique_id          => $unique_id,
                        public             => $content->public,
                        serialized         => $content->serialized,
                        serialized_payload => $content->serialized_payload,
                        original_body      => $content->original_body,
                        external_url       => $content->external_url,
                        external_unique_id => $content->external_unique_id,
                        in_reply_to        => $content->in_reply_to,
                        thread_id          => $content->thread_id,
                        subject            => $content->subject,
                        submitter_mask     => $content->submitter_mask,
                        read_only          => $content->read_only,
                    }
                );

                # set up notifications for the comment and the thread now, since we're participating.
                if ($content->in_reply_to) {
                    my $watching_thread;
                    foreach my $w ($actor->watched_messages->search({ target => $content->thread_id })) {
                        if ($w->target->unique_id eq $content->thread_id) {
                            $watching_thread = 1;
                            last;
                        }
                    }

                    if (!$watching_thread) {

                        # the actor should be watching this thread for notifications now.
                        $self->app->m->resultset('MeritCommons::Model::Stream::Message::Watcher')->create(
                            {
                                target  => $content->thread_id,
                                watcher => $actor,
                            }
                        );
                    }
                } else {
                    $msg->thread_id($msg->unique_id);
                    $msg->update;
                }

                # now pass through creating all the stream relationships.
                foreach my $stream (@{ $content->streams }) {
                    $self->app->m->resultset('Stream::MessageStream')->create(
                        {
                            stream  => $stream->id,
                            message => $msg->id,
                        }
                    );
                    push(
                        @{ $data->{sent} },
                        {
                            stream_id   => $stream->unique_id,
                            stream_name => $stream->common_name,
                            message_id  => $msg->unique_id
                        }
                    );
                }

                # generate notifications about this event.
                $self->app->notifier_write($msg, "m." . $msg->thread_id, $actor, @{ $content->streams }, "comment");

                # add the message to the Sphinx index
                $self->app->add_message_index($msg);

                # and finally, the actor should be watching this message for notifications from here on out..
                $self->app->m->resultset('MeritCommons::Model::Stream::Message::Watcher')->create(
                    {
                        target  => $msg->unique_id,
                        watcher => $actor,
                    }
                );

                my @to_publisher;

                # finally write to the publisher!
                foreach my $stream (@{ $content->streams }) {
                    push(@to_publisher, join(" ", $stream->unique_id, $msg->unique_id));
                }

                if ($msg->thread_id ne $msg->unique_id) {
                    push(@to_publisher, join(" ", $msg->thread_id, $msg->unique_id));
                }

                $self->audit_log(
                    qq/inbound message @{[$msg->unique_id]} added by @{[$msg->submitter->userid]} sent to [/ .
                      join(', ', map { "'@{[$_->common_name]}' (@{[$_->unique_id]})" } @{ $content->streams }) . "]");

                # write this all at once
                $self->app->pub_write(@to_publisher);
            }

            unless (exists($data->{sent}) || exists($data->{not_sent})) {
                $data->{error}   = "No valid streams found";
                $data->{success} = 0;
            }
        } else {
            $data->{error}   = "No message body found";
            $data->{success} = 0;
        }
    } else {
        $data->{error}   = "Access Denied";
        $data->{success} = 0;
    }

    return $data;
}

sub _edit_inbound_message {
    my ($self, $actor, $content) = @_;

    # This method is very similar to add_inbound_message.
    # Although, it simply updates the body of the message,
    # as well as some attributes.

    if ($actor) {
        if ($content->message_id) {
            if (my $msg = $self->m->resultset('Stream::Message')->find({ unique_id => $content->message_id })) {

                # see if we can moderate any of the streams this message belongs to
                my @m_streams = ();
                foreach my $stream ($msg->streams) {
                    if ($actor->can_moderate($stream)) {
                        push(@m_streams, $stream);
                    }
                }
                if ($actor->id == $msg->submitter->id ||
                    scalar(grep(!$_->personal_inbox_user, @m_streams)) ||
                    $actor->is_admin) {
                    if ($content->body) {
                        if ($self->global_config->{inbound_debug}) {
                            $self->app->log->info(
                                "[inbound_debug/EDIT] as received as received by inbound " . $content->body);
                        }

                        # THE ONE CHANGE WE MAKE UNIVERSALLY....
                        # get rid of <'s, replace with &lt;
                        $content->{body} =~ s/</&lt;/g;

                        # Execute the content driver stack before checking source perms, as some drivers will extrapolate sources from
                        # the content.
                        $content = $self->cd_inbound($content, $actor);

                        if ($self->global_config->{inbound_debug}) {
                            $self->app->log->info("[inbound_debug/EDIT] after content drivers " . $content->body);
                        }

                        my $msg_json = encode_json($msg->as_hashref); # the original state of the message before updating

                        # update our message (so far body and subject can be modified)
                        $msg->body($content->body);
                        $msg->original_body($content->original_body);
                        $msg->subject($content->subject);
                        $msg->read_only($content->read_only);
                        $msg->update();

                        $self->audit_log("message @{[$msg->unique_id]} updated by @{[$actor->userid]}");

                        # write to changelog
                        $self->app->m->resultset('Stream::Message::ChangeLog')->create(
                            {
                                actor     => $actor->id,
                                message   => $msg->id,
                                undo_data => $msg_json,
                                title     => "Message updated",
                            }
                        );

                        # notify the message's original author of the change
                        if ($msg->submitter->id != $actor->id) {
                            $self->notifier_write(
                                $actor,
                                $msg->submitter,
                                'verbatim',
                                "/m/@{[$msg->unique_id]}",
                                encode_base64(
                                    qq|<a href="/u/@{[$actor->userid]}/">@{[$actor->common_name]}</a> has edited your <a href="/m/@{[$msg->unique_id]}">message</a>.|,
                                    ''
                                )
                            );
                        }
                    } else {
                        return {
                            error   => "This message doesn't have a body! Maybe you want to delete this message?",
                            success => 0,
                        };
                    }
                } else {
                    return {
                        error   => "You do not have permission to edit this message.",
                        success => 0,
                    };
                }
            } else {
                return {
                    error   => "Message (" . $content->message_id . ") could not be found.",
                    success => 0,
                };
            }
        } else {
            return {
                error   => "No message id specified.",
                success => 0,
            };
        }
    } else {
        return {
            error   => "Access denied.",
            success => 0,
        };
    }

    return { success => 1 };
}

sub _add_identity_to_user {
    my ($controller, $user, $identity, $multiplier) = @_;
    $user = $controller->app->user($user) unless ref $user;

    # doing a lot with the model, so pull it out
    my $m       = $controller->app->m;
    my $id_hash = crc32_hex($identity);

    if (my $id_obj = $m->resultset('User::Identity')->find({ identity => $id_hash })) {
        foreach my $id ($user->identities) {
            if ($id->id == $id_obj->id) {
                return { error => "User already has identity $identity" };
            }
        }
        return $m->resultset('User::IdentityUser')->create({ meritcommons_user => $user->id, identity => $id_obj->id });
    } else {
        $multiplier = 1 unless $multiplier;
        my $id_obj = $m->resultset('User::Identity')->create({ identity => $id_hash, multiplier => $multiplier });
        return $m->resultset('User::IdentityUser')->create({ meritcommons_user => $user->id, identity => $id_obj->id });
    }
}

sub _truncate {
    my ($controller, $data, $len) = @_;
    $truncate->chars($len);
    my $truncated;
    eval { $truncated = $truncate->truncate($data); };

    if (!$@ && $truncated) {
        $truncated =~ s/\n//g;
    } else {
        warn "Error in truncate: $@\n";
    }

    return $truncated;
}

sub _htmlstrip {
    my ($controller, $data) = @_;

    # we're going to strip out html and formatting, and replace it with whitespace.  This should do the trick..
    $data =~ s/\<[\\A-Za-z0-9\/\=\+\"\'\%\s\_\-\?\!\,\.\&:;]+\>//g;

    # get rid of any leading or trailing whitespace...
    $data =~ s/^\s+//g;
    $data =~ s/\s+$//g;

    return $data;
}

sub _truncate_htmlstrip {
    my ($controller, $data, $len, $bow) = @_;

    # we're going to strip out html and formatting, and replace it with whitespace.  This should do the trick..
    $data =~ s/\<[\\A-Za-z0-9\/\=\+\"\'\%\s\_\-\?\!\,\.\&:;]+\>//g;

    # get rid of any leading or trailing whitespace...
    $data =~ s/^\s+//g;
    $data =~ s/\s+$//g;

    # return data if the length of all the data is less than the length
    if (length($data) < $len) {

        # it's already stripped!
        return $data;
    }

    if ($bow) {

        # prepare the return value...
        my $return_value;
        my @words = split(/\s+/, $data);
        my $word = 1;
        $return_value = $words[0];

        # add words until we exceed the specified length or run out of words
        while (length($return_value) < $len) {
            $return_value .= " $words[$word]";
            last if $word == $#words;
            ++$word;
        }

        # and return! (w/ yadda yadda yadda)
        return $return_value . "...";
    } else {
        return substr($data, 0, $len);
    }
}

sub _prepare_payload {
    my ($controller, $msg_obj, $user, $group_by_thread) = @_;

    # Collections of messages should go through prepare_payload_collection so that
    # queries are grouped to increase performance
    if (ref($msg_obj) eq 'ARRAY') {
        return $controller->app->messages->prepare_collection($msg_obj, $user, $group_by_thread);
    } else {
        return $controller->app->msg->prepare($msg_obj, $user);
    }
}

sub _prepare_payload_single {
    my ($controller, $msg_obj, $user) = @_;

    my $payload = $controller->app->msg->attributes($msg_obj, $user);
    $payload->{in_reply_to}       = $msg_obj->get_column('in_reply_to');
    $payload->{number_of_replies} = $msg_obj->replies->count;

    # is this message marked as read?
    if ($msg_obj->is_read_by($user)) {
        $payload->{read} = 1;
    }

    # stash the message tags.
    $payload->{tags} = [ map { ref($_) && $_->tag } $msg_obj->tags->search({ meritcommons_user => $user->id }) ];

    # Check streams of thread
    foreach my $stream ($msg_obj->streams) {
        if ($user && ($stream->common_name eq "_" . $user->userid)) {
            push(
                @{ $payload->{streams} },
                {
                    stream_id        => $stream->unique_id,
                    stream_name      => $user->userid,
                    stream_name_abbr => "\@@{[$user->userid]}",
                    no_dropdown      => 1,
                    mention          => 1,
                    link             => "/u/@{[$user->userid]}/",
                }
            );
        } elsif ($user && ($stream->common_name eq "__" . $user->userid)) {
            push(
                @{ $payload->{streams} },
                {
                    stream_id        => $stream->unique_id,
                    stream_name      => $user->common_name . "'s Notification Inbox",
                    no_dropdown      => 1,
                    stream_name_abbr => "Notifications",
                }
            );
        } elsif ($stream->common_name =~ /^_(\w+)$/) {
            my $userid = $1;

            # enumerate participants in a conversation
            push(
                @{ $payload->{streams} },
                {
                    stream_id        => $stream->unique_id,
                    stream_name      => $userid,
                    stream_name_abbr => "\@$userid",
                    mention          => 1,
                    no_dropdown      => 1,
                    link             => "/u/$userid/",
                }
            );
        } elsif ($stream->common_name !~ /^_/) {
            my ($stream_name_abbr) = $stream->common_name =~ /^([^\s]{1,4})/;
            my $stream_payload = {
                stream_id        => $stream->unique_id,
                stream_name      => $stream->common_name,
                stream_name_abbr => $stream->short_name || $stream_name_abbr,
            };
            if ($stream->personal_outbox_user) {
                $stream_payload->{link} = "/u/@{[$stream->personal_outbox_user->userid]}/";
            } else {
                $stream_payload->{link} =
                  $controller->app->url_for('get_stream',
                    stream_identifier => $stream->url_name || $stream->common_name)->to_string();
            }
            push(@{ $payload->{streams} }, $stream_payload);
        }
    }

    # sort and summarize streams, no need to do this for notifications though as they are only sent to notification inboxes
    if (ref($payload->{streams}) eq "ARRAY") {
        @{ $payload->{streams} } = sort { $a->{stream_name} cmp $b->{stream_name} } @{ $payload->{streams} };
    } else {
        $payload->{streams} = [];
    }

    if ($msg_obj->thread_id && $msg_obj->thread_id eq $msg_obj->unique_id) {
        my $stream_count = scalar(@{ $payload->{streams} });
        if ($stream_count == 1) {
            $payload->{stream_summary} = $payload->{streams}->[0]->{stream_name};
        } else {
            $payload->{stream_summary} = "$stream_count streams";
        }
    }

    return $payload;
}

sub _prepare_payload_collection {
    my ($controller, $messages, $user, $group_by_thread) = @_;

    # Collect id sets used for subsequent queries
    my @merged_message_unique_ids = map { $_->unique_id } @{$messages};
    my @merged_message_parent_ids = map { $_->id } @{$messages};

    # Get replies in bulk and associate them to the messages in code.  It's cheaper than
    # doing deep/large joins or doing numerous individual queries
    my @merged_message_thread_replies = $controller->app->m->resultset('Stream::Message')->search(
        {
            'me.thread_id'   => [@merged_message_unique_ids],
            'me.in_reply_to' => { '!=' => undef }
        },
        {
            prefetch => ['submitter'],
        }
    );

    # Get stream_messages and stream data in bulk for parent messages, but return it as a hash since we can save
    # a lot of resources by not instantiating these records as objects
    my $parent_message_stream_resultset = $controller->app->m->resultset('Stream::MessageStream')->search(
        {
            'me.message' => [@merged_message_parent_ids]
        },
        {
            prefetch => {
                'stream' => 'personal_outbox_user',
            },
        }
    );

    $parent_message_stream_resultset->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my @parent_message_streams = $parent_message_stream_resultset->all;

    # Index the hash by message id
    my %parent_message_streams;
    foreach my $parent_message_stream (@parent_message_streams) {
        push(@{ $parent_message_streams{ $parent_message_stream->{message} } }, $parent_message_stream->{stream});
    }

    # Get tags in bulk
    my @merged_message_reply_ids = map { $_->id } @merged_message_thread_replies;
    my @merged_message_ids = (@merged_message_parent_ids, @merged_message_reply_ids);

    my @merged_message_tags = $controller->app->m->resultset('Stream::Message::Tag')->search(
        {
            'me.message'        => [@merged_message_ids],
            'me.meritcommons_user' => $user->id
        }
    );

    my %message_tags;

    foreach my $message_id (@merged_message_ids) {
        $message_tags{$message_id} = [];
    }

    foreach my $message_tag (@merged_message_tags) {
        push(@{ $message_tags{ $message_tag->get_column('message') } }, $message_tag->tag);
    }

    # Assemble a hash of the relationship of threads and replies, also keep track of all
    # streams and number of replies
    my %threads;
    my @message_stream_ids;
    my %number_of_replies;
    foreach my $thread_message (@{$messages}) {
        $threads{ $thread_message->unique_id }->{parent}   = $thread_message;
        $threads{ $thread_message->unique_id }->{children} = [];

        foreach my $message_stream (@{ $parent_message_streams{ $thread_message->id } }) {
            push(@message_stream_ids, $message_stream->{id});
        }
    }

    foreach my $thread_reply (@merged_message_thread_replies) {
        $number_of_replies{ $thread_reply->get_column('in_reply_to') }++;

        push(@{ $threads{ $thread_reply->thread_id }->{children} }, $thread_reply);
    }

    # Of all of the unique streams that are references, determine which ones the user is
    # authorized to view
    @message_stream_ids = uniq(@message_stream_ids);
    my @authorized_message_streams = $user->authorized_streams_filter(@message_stream_ids);
    my @authorized_message_stream_ids = map { $_->id } @authorized_message_streams;

    # Now run prepare payload on the threads and the replies
    my @payloads;
    while ((my $message_id, my $thread) = each %threads) {
        my $parent_payload = $controller->app->msg->attributes($thread->{parent}, $user);

        @{ $parent_payload->{thread_replies} } = ();

        # Check streams of thread
        foreach my $stream (@{ $parent_message_streams{ $thread->{parent}->id } }) {
            if ($user && ($stream->{common_name} eq "_" . $user->userid)) {
                push(
                    @{ $parent_payload->{streams} },
                    {
                        stream_id        => $stream->{unique_id},
                        stream_name      => $user->userid,
                        stream_name_abbr => "\@@{[$user->userid]}",
                        no_dropdown      => 1,
                        mention          => 1,
                        link             => "/u/@{[$user->userid]}/",
                    }
                );
            } elsif ($user && ($stream->{common_name} eq "__" . $user->userid)) {
                push(
                    @{ $parent_payload->{streams} },
                    {
                        stream_id        => $stream->{unique_id},
                        stream_name      => $user->common_name . "'s Notification Inbox",
                        no_dropdown      => 1,
                        stream_name_abbr => "Notifications",
                    }
                );
            } elsif ($stream->{common_name} =~ /^_(\w+)$/) {

                # enumerate participants in a conversation
                my $userid = $1;
                push(
                    @{ $parent_payload->{streams} },
                    {
                        stream_id        => $stream->{unique_id},
                        stream_name      => $userid,
                        stream_name_abbr => "\@$userid",
                        mention          => 1,
                        no_dropdown      => 1,
                        link             => "/u/$userid/",
                    }
                );
            } elsif ($stream->{common_name} !~ /^_/) {
                my ($stream_name_abbr) = $stream->{common_name} =~ /^([^\s]{1,4})/;
                chomp($stream_name_abbr);
                my $stream_payload = {
                    stream_id        => $stream->{unique_id},
                    stream_name      => $stream->{common_name},
                    stream_name_abbr => $stream->{short_name} || $stream_name_abbr,
                };
                if (exists $stream->{personal_outbox_user}->{userid}) {
                    $stream_payload->{link} = "/u/@{[$stream->{personal_outbox_user}->{userid}]}/";
                } else {
                    $stream_payload->{link} =
                      $controller->app->url_for('get_stream',
                        stream_identifier => $stream->{url_name} || $stream->{common_name})->to_string();
                }
                push(@{ $parent_payload->{streams} }, $stream_payload);
            }
        }

        # sort by name
        if (ref($parent_payload->{streams}) eq "ARRAY") {
            @{ $parent_payload->{streams} } =
              sort { $a->{stream_name} cmp $b->{stream_name} } @{ $parent_payload->{streams} };
            my $stream_count = scalar(@{ $parent_payload->{streams} });
            if ($stream_count == 1) {
                $parent_payload->{stream_summary} = $parent_payload->{streams}->[0]->{stream_name};
            } else {
                $parent_payload->{stream_summary} = "$stream_count streams";
            }
        } else {
            $parent_payload->{streams}        = [];
            $parent_payload->{stream_summary} = "0 streams";
        }

        if (grep $_ eq "_read", @{ $message_tags{ $thread->{parent}->id } }) {
            $parent_payload->{read} = 1;
        } else {
            $parent_payload->{read} = 0;
        }

        # stash the tags in the parent as "tags"
        $parent_payload->{tags} = $message_tags{ $thread->{parent}->id };

        foreach my $child (@{ $thread->{children} }) {
            my $child_payload = $controller->app->msg->attributes($child, $user);

            if (grep $_ eq "_read", @{ $message_tags{ $child->id } }) {
                $child_payload->{read} = 1;
            } else {
                $child_payload->{read} = 0;
            }

            # stash the tags in the child as "tags"
            $child_payload->{tags} = $message_tags{ $child->id };

            # If there is not a non-standard in_reply_to set by prepare_payload, use the
            # parent unique_id
            if (!$child_payload->{in_reply_to}) {
                $child_payload->{in_reply_to} = $child->get_column('in_reply_to');
            }

            $child_payload->{number_of_replies} =
              ($number_of_replies{ $child->id }) ? $number_of_replies{ $child->id } : 0;

            if ($group_by_thread) {
                push(@{ $parent_payload->{thread_replies} }, $child_payload);
            } else {
                push(@payloads, $child_payload);
            }
        }

        # sort thread replies by date
        @{ $parent_payload->{thread_replies} } =
          sort { $a->{post_time} cmp $b->{post_time} } @{ $parent_payload->{thread_replies} };

        $parent_payload->{number_of_replies} = scalar(@{ $thread->{children} });
        push(@payloads, $parent_payload);
    }

    # these are in the right order, so put them in this array's order.
    my $i = 0;
    my %order_hash = map { $_ => $i++ } @merged_message_unique_ids;
    @payloads = sort { $order_hash{ $a->{message_id} } <=> $order_hash{ $b->{message_id} } } @payloads;

    return @payloads;
}

# NOTIFICATIONS!  Get notifications for a user.
sub _notifications {
    my ($controller, $opts) = @_;

    my $before = $opts->{before} || time;
    my $lim    = $opts->{limit}  || 50;
    my $user   = $opts->{user};

    my $message_streams = $controller->app->m->resultset('Stream::MessageStream')->search(
        {
            'me.stream' => [ $user->notification_inbox->id ],
        }
    );

    # Get messages, filtering the message subquery by a record limit and message offset
    my @notifications = $controller->app->m->resultset('Stream::Message')->search(
        {
            -and => [
                'me.post_time' => { '<' => $before },
                'me.id'        => {
                    -in => $message_streams->get_column('message')->as_query
                },
                'me.render_as' => 'notification',
            ]
        },
        {
            prefetch => ['submitter'],
            rows     => $lim,
            order_by => {
                "-desc" => ['me.post_time']
            },
        }
    );

    return $controller->messages->prepare(\@notifications, $user);
}

# TODO.. please implement.
# Merged Messages Structure:
# {
#     messages => {
#         '8D5647BF-072E-4921-94A6-ED29E4601E4C' => {
#             # actual message ...
#         }
#     },
#     streams => {
#         'all' => [
#             # references to all merged 'messages'.
#         ],
#         'CA58F3EA-26C0-417C-B4BC-59EAF4072CD9' => [
#             # references to only messages that are in this stream..
#         ],
#     },
# }
sub _collated_messages {
    my ($c, $opts, $callback) = @_;

}

# aware of multiple scenarios...
sub _prepare_payload_message_attributes {
    my ($c, $message, $user) = @_;

    my $msg_id;
    if (ref($message) eq "HASH") {
        $msg_id = $message->{unique_id};
        $message->{message_id} = $msg_id;
    } elsif (ref($message) eq "MeritCommons::Model::Stream::Message") {
        $msg_id = $message->unique_id;
    }

    my $content = MeritCommons::Content->new($message);

    # run the content through the driver stack...
    $content = $c->cd_outbound($content, $user);

    # return the payload.
    return $content->as_hashref(1);
}

# Merged Messages!  Get all messages for all subscriptions for a user limited by the first argument
sub _merged_messages {
    my ($controller, $opts, @streams) = @_;

    my $after    = $opts->{after}    || time;
    my $after_id = $opts->{after_id} || 9223372036854775807;
    my $lim      = $opts->{limit}    || 50;
    my $replica  = $opts->{replica};
    my $user     = $opts->{user};

    return undef unless $user;

    # get replica if we're allowed to use it, otherwise get model.
    my $model = $replica ? $controller->app->rorm : $controller->app->m;

    ##########
    # TIMING #
    ##########
    my $db_query_start     = Time::HiRes::time;
    my $db_query_last_step = $db_query_start;
    ###########
    # /TIMING #
    ###########

    # Get either the passed streams, filtered by what the user has access to search on,
    # or default to all subscribed streams
    my @merge_streams =
      scalar(@streams)
      ? $user->authorized_streams_filter(map { $_->id } @streams)
      : $user->authorized_subscribed_streams;

    ##########
    # TIMING #
    ##########
    if ($ENV{MERITCOMMONS_TIMING}) {
        $db_query_last_step = Time::HiRes::time;
        printf("[timing] authorized stream filter: %.4f\n", $db_query_last_step - $db_query_start);
    }
    ###########
    # /TIMING #
    ###########

    my @stream_ids = map { $_->id } @merge_streams;

    # Create a subquery of the total population of applicable messages (before they are filtered)
    my $message_streams = $model->resultset('Stream::MessageStream')->search(
        {
            'me.stream' => [@stream_ids],
        }
    );

    ##########
    # TIMING #
    ##########
    if ($ENV{MERITCOMMONS_TIMING}) {
        $db_query_last_step = Time::HiRes::time;
        printf("[timing] obtain message streams: %.4f\n", $db_query_last_step - $db_query_start);
    }
    ###########
    # /TIMING #
    ###########

    # Get messages, filtering the message subquery by a record limit and message offset
    my @merged = $model->resultset('Stream::Message')->search(
        {
            -and => [
                'me.id'        => { '<' => $after_id },
                'me.post_time' => { '<' => $after },
                'me.id'        => {
                    -in => $message_streams->get_column('message')->as_query
                },
                'me.in_reply_to' => undef,
                'me.render_as'   => { '!=' => 'notification' },
            ]
        },
        {
            rows     => $lim,
            order_by => {
                "-desc" => [ 'me.post_time', 'me.id' ]
            },
            prefetch => [
                'submitter'    # required, since it's mapped by default in MeritCommons::Content
            ],
        }
    );

    ##########
    # TIMING #
    ##########
    if ($ENV{MERITCOMMONS_TIMING}) {
        $db_query_last_step = Time::HiRes::time;
        printf("[timing] obtain message objects: %.4f\n", $db_query_last_step - $db_query_start);
    }
    ###########
    # /TIMING #
    ###########

    my @payloads = $controller->messages->prepare(\@merged, $user, 1);

    ##########
    # TIMING #
    ##########
    if ($ENV{MERITCOMMONS_TIMING}) {
        $db_query_last_step = Time::HiRes::time;
        printf("[timing] prepared payloads: %.4f\n", $db_query_last_step - $db_query_start);
    }
    ###########
    # /TIMING #
    ###########

    return @payloads;
}

# Messages from one stream!  Get all messages for one stream limited by the first argument
sub _single_stream_messages {
    my ($controller, $user, $stream, $lim, $after) = @_;

    $after = time unless $after;
    $lim   = 50   unless $lim;

    # merged messages returns payloads!
    return $controller->app->merged_messages(
        {
            user  => $user,
            limit => $lim,
            after => $after
        },
        $stream
    );
}

# Messages from multiple streams!
sub _multiple_stream_messages {
    my ($controller, $user, $streams, $lim, $after) = @_;

    $after = time unless $after;
    $lim   = 50   unless $lim;

    # merged messages returns payloads!
    # merged messages returns payloads!
    return $controller->app->merged_messages(
        {
            user       => $user,
            limit      => $lim,
            after      => $after,
            sort_order => "desc",
        },
        @$streams
    );
}

# Generate a unique URL name from a string
sub _stream_generate_url_name {
    my ($controller, $string) = @_;

    $string =~ s/\s+/_/g;
    $string = lc($string);
    $string =~ s/[^a-z0-9_]+//g;    # reduce to alphanumeric and underscores
    $string =~ s/(_)\1+/$1/g;       # remove repeated underscores

    my $proposed_url_name = $string;

    # Evaluate stream names, adding an incremented suffix if needed, until there's a unique URL name identified that can be used
    my $counter = 1;
    my $match;
    while ($match = $controller->app->m->resultset('Stream')->search({ url_name => $proposed_url_name })->first) {
        $proposed_url_name = $string . $counter;
        $counter++;
    }

    return $proposed_url_name;
}

# User Messages!  Get all messages for a user limited by the first argument
sub _user_messages {
    my ($controller, $user, $lim, $after) = @_;
    $lim = 50 unless $lim;

    my @merged = $controller->app->m->resultset('Stream::Message')->search(
        {
            -and => [
                'submitter' => $user->id
            ],
        },
        {
            prefetch => [ { message_streams => 'stream', }, 'submitter', ],
            distinct => 1,
            rows     => $lim,
            order_by => { "-desc" => [ 'me.post_time', 'me.id' ] },
        }
    );

    # return them as payloads!
    return map { $controller->app->msg->attributes($_, $user) } @merged;
}

# Authors!
# automatically sets authorization flag, and optionally allow_edit
sub _grant_authorship {
    my ($controller, $actor, $user, $stream, $allow_edit, $mute_notification) = @_;

    # retrofitted named arguments
    if (ref($actor) eq "HASH") {
        $user              = $actor->{user};
        $stream            = $actor->{stream};
        $allow_edit        = $actor->{allow_edit};
        $mute_notification = $actor->{mute_notification};
        $actor             = $actor->{actor};
    }

    $allow_edit = 0 unless $allow_edit;

    my $data = {};
    if ($actor->can_moderate($stream) || !$stream->requires_author_authorization) {
        my $aut = $user->authorships->find({ stream => $stream });
        unless ($aut) {
            $aut = $controller->add_authorship(
                {
                    actor             => $actor,
                    user              => $user,
                    stream            => $stream,
                    mute_notification => $mute_notification,
                }
            )->{authorship};
        }

        $controller->authorize_authorship($actor, $user, $stream, $allow_edit, $mute_notification);
        $data->{authorship} = $aut;
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# does not set authorization flag
sub _add_authorship {
    my ($controller, $actor, $user, $stream, $mute_notification) = @_;

    # retrofitted named arguments
    if (ref($actor) eq "HASH") {
        $user              = $actor->{user};
        $stream            = $actor->{stream};
        $mute_notification = $actor->{mute_notification};
        $actor             = $actor->{actor};
    }

    # the root user doesn't generate notifications
    if ($actor->id == 1) {
        $mute_notification = 1;
    }

    my $data = {};
    if ($actor->can_moderate($stream) || $actor->id == $user->id) {
        my $aut = $user->authorships->find({ stream => $stream });
        unless ($aut) {
            $aut = $controller->app->m->resultset('Stream::Author')->create(
                {
                    meritcommons_user => $user->id,
                    stream         => $stream->id,
                    authorized     => $stream->requires_author_authorization ? 0 : 1,
                    added_by       => $actor->id,
                }
            );

            $controller->audit_log(
                "authorship added for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");
            unless ($mute_notification) {
                if ($stream->requires_author_authorization) {
                    foreach my $mod ($stream->moderators) {
                        next unless $mod && $actor;
                        my $mod_user = $mod->meritcommons_user;

                        # skip MeritCommons System
                        next if $mod_user->id == 1;
                        my $userid             = $actor->userid;
                        my $common_name        = $actor->common_name;
                        my $stream_common_name = $stream->common_name;
                        my $stream_url_name    = $stream->url_name;
                        $controller->notifier_write(
                            $actor,
                            $mod_user,
                            $stream,
                            'verbatim',
                            "/s/$stream_url_name/m",
                            encode_base64(
                                qq|<a href="/u/$userid/">$common_name</a> has applied for authorship on <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                                ''
                            )
                        );
                    }
                }
            }
        }

        $data->{authorship} = $aut;
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# sets the authorized flag to true!
sub _authorize_authorship {
    my ($controller, $actor, $user, $stream, $allow_edit, $mute_notification) = @_;
    $allow_edit = 0 unless $allow_edit;

    my $data = {};
    if ($actor->can_moderate($stream)) {
        my $aut = $user->authorships->find({ stream => $stream });
        if ($aut) {
            $aut->authorized(1);
            $aut->allow_edit($allow_edit);
            $aut->update;

            $controller->audit_log(
                "authorship authorized for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");

            unless ($mute_notification) {
                my $userid             = $actor->userid;
                my $common_name        = $actor->common_name;
                my $stream_common_name = $stream->common_name;
                my $stream_url_name    = $stream->url_name;
                $controller->notifier_write(
                    $actor,                   # from
                    $user,                    # to
                    $stream,                  # regarding
                    'verbatim',               # type
                    "/s/$stream_url_name",    # href
                    encode_base64(
                        qq|<a href="/u/$userid/">$common_name</a> authorized your authorship access for <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                        ''
                    )
                );
            }

            $data->{authorship} = $aut;
        } else {
            $data->{error} = "Can't find existing authorship for " . $user->userid . " to " . $stream->common_name;
        }
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# sets the authorized flag to false!
sub _deauthorize_authorship {
    my ($controller, $actor, $user, $stream) = @_;

    my $data = {};
    if ($actor->can_moderate($stream)) {
        unless ($stream->id == $user->personal_outbox->id) {    # Stuff from which you can't remove authorship
            my $aut = $user->authorships->find({ stream => $stream });
            if ($aut) {
                $aut->authorized(0);
                $aut->allow_edit(0);
                $aut->update;
                my $userid             = $actor->userid;
                my $common_name        = $actor->common_name;
                my $stream_common_name = $stream->common_name;
                my $stream_url_name    = $stream->url_name;
                $controller->notifier_write(
                    $actor,                                     # from
                    $user,                                      # to
                    $stream,                                    # regarding
                    'verbatim',                                 # type
                    "/s/$stream_url_name",                      # href
                    encode_base64(
                        qq|<a href="/u/$userid/">$common_name</a> denied your author access to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                        ''
                    )
                );
                $controller->audit_log(
                    "authorship deauthorized for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");
                $data->{authorship} = $aut;
            } else {
                $data->{error} = "Can't find existing authorship for " . $user->userid . " to " . $stream->common_name;
            }
        } else {
            $data->{error} = "Can't deauthorize authorship for " . $user->userid . " to " . $stream->common_name;
        }
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# gets rid of an authorship
sub _remove_authorship {
    my ($controller, $actor, $user, $stream) = @_;

    my $data = {};
    if ($actor->can_moderate($stream) || $actor->id == $user->id) {
        unless ($stream->id == $user->personal_outbox->id) {    # Stuff from which you can't remove authorship
            my $aut = $user->authorships->find({ stream => $stream });
            if ($aut) {
                my $userid             = $actor->userid;
                my $common_name        = $actor->common_name;
                my $stream_common_name = $stream->common_name;
                my $stream_url_name    = $stream->url_name;
                $controller->notifier_write(
                    $actor,                                     # from
                    $user,                                      # to
                    $stream,                                    # regarding
                    'verbatim',                                 # type
                    "/s/$stream_url_name",                      # href
                    encode_base64(
                        qq|<a href="/u/$userid/">$common_name</a> denied your author access to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                        ''
                    )
                );
                $aut->delete;

                $controller->audit_log(
                    "authorship removed for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");
                $data->{authorship} = undef;
            } else {
                $data->{error} = "Can't find existing authorship for " . $user->userid . " to " . $stream->common_name;
            }
        } else {
            $data->{error} = "Can't remove authorship for " . $user->userid . " to " . $stream->common_name;
        }
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# Subscriptions!

# automatically sets authorization flag, and optionally allow_history
sub _grant_subscription {
    my ($controller, $actor, $user, $stream, $allow_history, $mute_notification) = @_;

    # retrofitted named arguments
    if (ref($actor) eq "HASH") {
        $user              = $actor->{user};
        $stream            = $actor->{stream};
        $allow_history     = $actor->{allow_history};
        $mute_notification = $actor->{mute_notification};
        $actor             = $actor->{actor};
    }

    $allow_history = 0 unless $allow_history;
    my $data = {};
    if ($actor->can_moderate($stream) || !$stream->requires_subscriber_authorization) {

        if (my $pou = $stream->personal_outbox_user) {
            my $userid      = $actor->userid;
            my $common_name = $actor->common_name;
            my $pou_userid  = $pou->userid;
            $controller->notifier_write(
                $actor, $pou, $stream,
                'verbatim',
                "/u/$userid/",
                encode_base64(
                    qq|<a href="/u/$userid/">$common_name</a> is now following your <a href="/u/$pou_userid/">personal stream</a>.|,
                    ''
                )
            );
        }

        my $sub = $user->subscriptions->find({ stream => $stream });
        unless ($sub) {
            $sub = $controller->add_subscription(
                {
                    actor             => $actor,
                    user              => $user,
                    stream            => $stream,
                    mute_notification => $mute_notification,
                }
            )->{subscription};
        }
        if ($sub) {
            $controller->authorize_subscription($actor, $user, $stream, $allow_history, $mute_notification);
            $data->{subscription} = $sub;
        } else {
            $data->{error} = "Access denied!";
        }
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# same as above but does not set authorization flag to true
sub _add_subscription {
    my ($controller, $actor, $user, $stream, $mute_notification) = @_;

    # retrofitted named arguments
    if (ref($actor) eq "HASH") {
        $user              = $actor->{user};
        $stream            = $actor->{stream};
        $mute_notification = $actor->{mute_notification};
        $actor             = $actor->{actor};
    }

    # the root user doesn't generate notifications
    if ($actor->id == 1) {
        $mute_notification = 1;
    }

    my $data = {};
    if ($actor->can_moderate($stream) || $actor->id == 1 || $actor->id == $user->id) {
        my $sub = $user->subscriptions->find({ stream => $stream });
        unless ($sub) {
            $sub = $controller->app->m->resultset('Stream::Subscriber')->create(
                {
                    meritcommons_user => $user->id,
                    stream         => $stream->id,
                    authorized     => $stream->requires_subscriber_authorization ? 0 : 1,
                    added_by       => $actor->id,
                }
            );

            $controller->audit_log(
                "subscription added for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");

            unless ($mute_notification) {
                if ($stream->requires_subscriber_authorization) {
                    foreach my $mod ($stream->moderators) {
                        next unless $mod && $actor;
                        my $mod_user = $mod->meritcommons_user;

                        # skip MeritCommons System
                        next if $mod_user->id == 1;
                        my $userid             = $actor->userid;
                        my $common_name        = $actor->common_name;
                        my $stream_common_name = $stream->common_name;
                        my $stream_url_name    = $stream->url_name;
                        $controller->notifier_write(
                            $actor,
                            $mod_user,
                            $stream,
                            'verbatim',
                            "/s/$stream_url_name/m",
                            encode_base64(
                                qq|<a href="/u/$userid/">$common_name</a> has applied for subscribership on <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                                ''
                            )
                        );
                    }
                }
            }
        }

        $data->{subscription} = $sub;
    } else {
        $data->{error} = "Access denied!";
    }
    return $data;
}

# sets the authorized flag to true!
sub _authorize_subscription {
    my ($controller, $actor, $user, $stream, $allow_history, $mute_notification) = @_;
    $allow_history = 0 unless $allow_history;

    my $data = {};
    if ($actor->can_moderate($stream)) {
        my $sub = $user->subscriptions->find({ stream => $stream });
        if ($sub) {
            $sub->authorized(1);
            $sub->allow_history($allow_history);
            $sub->update;
            unless ($mute_notification) {
                my $userid             = $actor->userid;
                my $common_name        = $actor->common_name;
                my $stream_common_name = $stream->common_name;
                my $stream_url_name    = $stream->url_name;
                $controller->notifier_write(
                    $actor,                   # from
                    $user,                    # to
                    $stream,                  # regarding
                    'verbatim',               # type
                    "/s/$stream_url_name",    # href
                    encode_base64(
                        qq|<a href="/u/$userid/">$common_name</a> authorized your subscription to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                        ''
                    )
                );
            }

            $controller->audit_log(
                "subscription authorized for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");
            $data->{subscription} = $sub;
        } else {
            $data->{error} =
              "Can't find existing subscription for " . $user->userid . " to " . $stream->common_name . "\n";
        }
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# sets the authorized flag to false!
sub _deauthorize_subscription {
    my ($controller, $actor, $user, $stream) = @_;

    my $data = {};
    if ($actor->can_moderate($stream)) {
        unless ($stream->id == $user->personal_inbox->id ||
            $stream->id == $user->personal_outbox->id ||
            $stream->id == 1) {    # Stuff for which a user cannot have a unauthorized subscription
            my $sub = $user->subscriptions->find({ stream => $stream });
            if ($sub) {
                $sub->authorized(0);
                $sub->allow_history(0);
                $sub->update;
                my $userid             = $actor->userid;
                my $common_name        = $actor->common_name;
                my $stream_common_name = $stream->common_name;
                my $stream_url_name    = $stream->url_name;
                $controller->notifier_write(
                    $actor,                   # from
                    $user,                    # to
                    $stream,                  # regarding
                    'verbatim',               # type
                    "/s/$stream_url_name",    # href
                    encode_base64(
                        qq|<a href="/u/$userid/">$common_name</a> denied your subscription access to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                        ''
                    )
                );

                $controller->audit_log(
                    "subscription deauthorized for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}"
                );
                $data->{subscription} = $sub;
            } else {
                $data->{error} =
                  "Can't find existing subscription for " . $user->userid . " to " . $stream->common_name;
            }
        } else {
            $data->{error} = "Can't deauthorize subscription for " . $user->userid . " to " . $stream->common_name;
        }
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

# gets rid of a subscription
sub _remove_subscription {
    my ($controller, $actor, $user, $stream) = @_;

    my $data = {};
    if ($actor->can_moderate($stream) || $actor->id == $user->id) {
        unless ($stream->id == $user->personal_inbox->id ||
            $stream->id == $user->personal_outbox->id ||
            $stream->id == 1 ||
            $stream->type eq "role") {    # Stuff for which a user cannot be unsubscribed
            my $sub = $user->subscriptions->find({ stream => $stream });
            if ($sub) {
                my $userid             = $actor->userid;
                my $common_name        = $actor->common_name;
                my $stream_common_name = $stream->common_name;
                my $stream_url_name    = $stream->url_name;
                $controller->notifier_write(
                    $actor,                   # from
                    $user,                    # to
                    $stream,                  # regarding
                    'verbatim',               # type
                    "/s/$stream_url_name",    # href
                    encode_base64(
                        qq|<a href="/u/$userid/">$common_name</a> denied your subscription access to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                        ''
                    )
                );

                $sub->delete;

                $controller->audit_log(
                    "subscription removed for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");
                $data->{subscription} = undef;
            } else {
                $data->{error} =
                  "Can't find existing subscription for " . $user->userid . " to " . $stream->common_name;
            }
        } else {
            $data->{error} = "Can't unsubscribe " . $user->userid . " from " . $stream->common_name;
        }
    } else {
        $data->{error} = $actor->userid . " is not a moderator of " . $stream->common_name;
    }
    return $data;
}

sub _check_valid_stream_url_name {
    my ($c, $url_name) = @_;

    # let's check if this stream name is one of our reserved names
    my $stream_exists;
    if ($c->global_config->{stream_reserved_names}) {
        my @stream_reserved_names = (qr/^_/, @{ $c->global_config->{stream_reserved_names} });

        foreach my $stream_reserved_name (@stream_reserved_names) {
            if (ref $stream_reserved_name eq "Regexp") {
                if ($url_name =~ $stream_reserved_name) {
                    $stream_exists = 1;
                }
            } else {
                if ($url_name eq $stream_reserved_name) {
                    $stream_exists = 1;
                }
            }
        }
    }

    # if it's not one of our reserved names, let's check if a stream with this url already exists
    if (!$stream_exists) {
        $stream_exists = $c->m->resultset('Stream')->count({ url_name => $url_name });
    }

    return $stream_exists ? 0 : 1;
}

sub _create_stream {
    my ($c, $stream_settings, $user) = @_;

    unless ($c->check_valid_stream_url_name($stream_settings->{url_name})) {

        # the stream url exists, don't create it
        return { error => "Stream URL is taken." };
    }

    my $stream = $c->app->m->resultset('Stream')->create(
        {
            common_name                       => $stream_settings->{common_name},
            unique_id                         => $stream_settings->{unique_id},
            creator                           => $stream_settings->{creator},
            url_name                          => $stream_settings->{url_name},
            description                       => $stream_settings->{description},
            keywords                          => $stream_settings->{keywords} ? lc($stream_settings->{keywords}) : '',
            show_publicly                     => $stream_settings->{show_publicly},
            private                           => $stream_settings->{private},
            display_subscribers               => $stream_settings->{display_subscribers},
            type                              => $stream_settings->{type},
            requires_author_authorization     => $stream_settings->{requires_author_authorization},
            requires_subscriber_authorization => $stream_settings->{requires_subscriber_authorization},
            members_can_invite                => $stream_settings->{members_can_invite},
            membership_requires_moderator_approval => $stream_settings->{membership_requires_moderator_approval},
        }
    );

    if ($stream) {

        # stream creation successful
        $c->add_stream_index($stream);

        $c->grant_moderatorship($c->user(1), $user, $stream, 1);
        $c->grant_subscription($user, $user, $stream, 1);
        $c->grant_authorship($user, $user, $stream, 1);
        $c->audit_log("new stream @{[$stream->unique_id]} created by @{[$user->userid]}");

        return { url => $c->url_for("/s/")->to_abs . $stream->url_name };
    }

    # error creating the stream (default)
    return { error => "Stream creation failed." };
}

# returns a hashref
sub _update_stream {
    my ($c, $actor, $stream_settings, $user, $stream) = @_;

    # passing stream is optional, but make sure you specify the stream's unique_id

    if (ref($stream_settings) ne "HASH") {
        return { error => "Stream settings passed incorrectly." };
    }

    if (!$stream) {    # no stream arg? let's see if your hash has something we can work with
        if ($stream_settings->{unique_id}) {
            $stream = $c->m->resultset('Stream')->find({ unique_id => $stream_settings->{unique_id} });
        } else {
            return { error => "Stream not provided." };
        }
    }

    if ($stream) {
        if ($stream->url_name ne $stream_settings->{url_name}) {

            unless ($c->check_valid_stream_url_name($stream_settings->{url_name})) {

                # the stream url exists, don't create it
                return { error => "Stream URL is taken." };
            }
        }

        if ($actor->can_moderate($stream)) {
            my $stream_json = encode_json($stream->as_hashref);    # stream state before update

            $stream->common_name($stream_settings->{common_name});
            $stream->url_name($stream_settings->{url_name});
            $stream->description($stream_settings->{description});
            $stream->keywords($stream_settings->{keywords} ? lc($stream_settings->{keywords}) : '');
            $stream->show_publicly($stream_settings->{show_publicly});
            $stream->private($stream_settings->{private});
            $stream->display_subscribers($stream_settings->{display_subscribers});
            $stream->requires_author_authorization($stream_settings->{requires_author_authorization});
            $stream->requires_subscriber_authorization($stream_settings->{requires_subscriber_authorization});
            $stream->members_can_invite($stream_settings->{members_can_invite});
            $stream->membership_requires_moderator_approval($stream_settings->{membership_requires_moderator_approval});

            $stream->update;

            $c->app->m->resultset('Stream::ChangeLog')->create(
                {
                    actor     => $actor->id,
                    stream    => $stream->id,
                    undo_data => $stream_json,
                    title     => "Stream updated",
                }
            );

            $c->audit_log("stream @{[$stream->unique_id]} updated by @{[$user->userid]}");

            return {
                url     => $c->url_for("/s/")->to_abs . $stream->url_name,
                success => 1,
            };
        } else {
            return { error => "You do not have permission to modify this stream." };
        }
    } else {
        return { error => "Stream not found." };
    }
}

# INVITES!

sub _invite {
    my ($controller, $invitee, $stream) = @_;

    if (my $invite = $invitee->invites->find({ stream => $stream })) {
        return $invite;
    }

    return undef;
}

sub _approve_invite {
    my ($controller, $inviter, $invitee, $stream) = @_;

    my $data;
    my $inv;
    if ($inv = $controller->invite($invitee, $stream)) {
        my $is_mod = $inviter->can_moderate($stream);

        if ($is_mod) {
            $inv->approved(1);
            $inv->update;
            $controller->audit_log(
                "invite to @{[$stream->unique_id]} for @{[$invitee->userid]} APPROVED by @{[$inviter->userid]}");
        }

        my $inviter_id         = $inv->inviter->userid;
        my $inviter_name       = $inv->inviter->common_name;
        my $stream_common_name = $stream->common_name;
        my $stream_url_name    = $stream->url_name;
        $controller->notifier_write(
            $inv->inviter,
            $invitee, $stream,
            'verbatim',
            "/s/$stream_url_name",
            encode_base64(
                qq|<a href="/u/$inviter_id/">$inviter_name</a> has invited you to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                ''
            )
        );

        $data->{invite} = $inv;

        return $data;
    }

    return undef;
}

sub _respond_to_invite {
    my ($controller, $invitee, $stream, $response) = @_;

    my $data->{response} = $response;
    my $inv;
    if ($inv = $controller->invite($invitee, $stream)) {
        my $invitee_id         = $invitee->userid;
        my $invitee_name       = $invitee->common_name;
        my $stream_common_name = $stream->common_name;
        my $stream_url_name    = $stream->url_name;
        my $response           = $response eq "accept" ? "accepted" : "declined";
        $controller->notifier_write(
            $invitee,
            $inv->inviter,
            $stream,
            'verbatim',
            "/s/$stream_url_name",
            encode_base64(
                qq|<a href="/u/$invitee_id/">$invitee_name</a> has $response your invite to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                ''
            )
        );

        if ($response eq "accepted") {
            $controller->audit_log("invite to @{[$stream->unique_id]} ACCEPTED by @{[$invitee->userid]}");
        } else {
            $controller->audit_log("invite to @{[$stream->unique_id]} DECLINED by @{[$invitee->userid]}");
        }

        $inv->delete;

        return $data;
    }

    return undef;
}

sub _invite_to_stream {
    my ($controller, $inviter, $invitee, $stream) = @_;
    my $data = {};

    my $is_mod = $inviter->can_moderate($stream);

    my $inv;
    if ($inv = $controller->invite($invitee, $stream)) {
        $data->{error} = "Someone has already invited " . $invitee->userid . " to stream " . $stream->common_name;
    } else {
        my $approved = 0;
        if ($is_mod || !$stream->membership_requires_moderator_approval) {
            $approved = 1;
        }
        $inv = $controller->app->m->resultset('Stream::Invite')->create(
            {
                inviter  => $inviter->id,
                invitee  => $invitee->id,
                stream   => $stream->id,
                approved => $approved,
            }
        );

        $data->{invite} = $inv->id;

        $controller->audit_log(
            "invite sent for @{[$invitee->userid]} to @{[$stream->unique_id]} by @{[$inviter->userid]}");

        if ($stream->membership_requires_moderator_approval && !$is_mod) {
            foreach my $mod ($stream->moderators) {
                next unless $mod && $inviter;
                my $mod_user = $mod->meritcommons_user;

                # skip MeritCommons System
                next if $mod_user->id == 1;
                my $inviter_id         = $inviter->userid;
                my $inviter_name       = $inviter->common_name;
                my $invitee_id         = $invitee->userid;
                my $invitee_name       = $invitee->common_name;
                my $stream_common_name = $stream->common_name;
                my $stream_url_name    = $stream->url_name;
                $controller->notifier_write(
                    $inviter,
                    $mod_user,
                    $stream,
                    'verbatim',
                    "/s/$stream_url_name/m",
                    encode_base64(
                        qq|<a href="/u/$inviter_id/">$inviter_name</a> would like to invite <a href="/u/$invitee_id">$invitee_name</a> to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                        ''
                    )
                );
            }
        } else {
            my $inviter_id         = $inviter->userid;
            my $inviter_name       = $inviter->common_name;
            my $stream_common_name = $stream->common_name;
            my $stream_url_name    = $stream->url_name;
            $controller->notifier_write(
                $inviter, $invitee, $stream,
                'verbatim',
                "/s/$stream_url_name",
                encode_base64(
                    qq|<a href="/u/$inviter_id/">$inviter_name</a> has invited you to <a href="/s/$stream_url_name">$stream_common_name</a>.|,
                    ''
                )
            );
        }
    }

    return $data;
}

# MODERATORSHIPS!

# Adds a moderatorship with optional allow_add_moderator
sub _add_moderatorship {
    my ($controller, $actor, $user, $stream, $allow_add_moderator) = @_;
    $allow_add_moderator = 0 unless $allow_add_moderator;

    my $data = {};
    if (($actor->is_moderator($stream) && $actor->is_moderator($stream)->allow_add_moderator) || $actor->is_admin) {
        my $mod = $user->moderatorships->find({ stream => $stream });
        if ($mod) {
            $data->{error} = $user->userid . " is already a moderator of " . $stream->common_name;
        } else {
            $mod = $controller->app->m->resultset('Stream::Moderator')->create(
                {
                    meritcommons_user => $user->id,
                    stream         => $stream->id,
                    added_by       => $actor->id,
                }
            );

            if ($stream->moderators->count == 1) {
                $mod->allow_add_moderator(1);
                $data->{forced_allow_add_moderator} = 1;
            } else {
                $mod->allow_add_moderator($allow_add_moderator);
            }
            $mod->update;

            $controller->audit_log(
                "moderatorship added for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");
            $data->{moderatorship} = $mod;
        }
    } else {
        $data->{error} =
          $actor->userid .
          " is not a moderator of, or does not have permission to add moderators to " . $stream->common_name;
    }
    return $data;
}

sub _set_allow_add_moderator {
    my ($controller, $actor, $user, $stream, $new_allow_add_moderator_value) = @_;

    my $data = {};
    if (($actor->is_moderator($stream) && $actor->is_moderator($stream)->allow_add_moderator) || $actor->is_admin) {
        my $mod = $user->moderatorships->find({ stream => $stream });
        if ($mod) {
            $controller->audit_log(
                "allow_add_moderator flag for @{[$user->userid]} on @{[$stream->unique_id]} changed from " .
                  "'@{[$mod->allow_add_moderator]}' to '$new_allow_add_moderator_value' by @{[$actor->userid]}");

            $mod->allow_add_moderator($new_allow_add_moderator_value);
            $mod->update;
            $data->{moderatorship} = $mod;
        } else {
            $data->{error} =
              "Can't find existing moderatorship for " . $user->userid . " of " . $stream->common_name . "\n";
        }
    } else {
        $data->{error} =
          $actor->userid .
          " is not a moderator of, or does not have permission to alter moderators to " . $stream->common_name;
    }
    return $data;
}

sub _add_allow_add_moderator {
    my ($controller, $actor, $user, $stream) = @_;

    return _set_allow_add_moderator($controller, $actor, $user, $stream, 1);
}

sub _remove_allow_add_moderator {
    my ($controller, $actor, $user, $stream) = @_;

    return _set_allow_add_moderator($controller, $actor, $user, $stream, 0);
}

sub _remove_moderatorship {
    my ($controller, $actor, $user, $stream) = @_;

    my $data = {};
    if (
        ($actor->is_moderator($stream) && $actor->is_moderator($stream)->allow_add_moderator) || # they're a mod with adding privs, or...
        $actor->id == $user->id ||    # they're removing themselves.
        $actor->is_admin              # they're an admin
      ) {
        my $mod = $user->moderatorships->find({ stream => $stream });
        if ($mod) {
            my @stream_moderators = $stream->moderators;
            if (scalar(@stream_moderators) > 1) {
                $mod->delete;
                $data->{moderatorship} = undef;
                $controller->audit_log(
                    "moderatorship removed for @{[$user->userid]} to @{[$stream->unique_id]} by @{[$actor->userid]}");
            } else {
                $data->{error} = "Can't remove last moderator for " . $stream->common_name . "\n";
            }
        } else {
            $data->{error} =
              "Can't find existing moderatorship for " . $user->userid . " of " . $stream->common_name . "\n";
        }
    } else {
        $data->{error} =
          $actor->userid .
          " is not a moderator of, or does not have permission to remove moderators from " . $stream->common_name;
    }
    return $data;
}

# shortstyle stream(), message(), and user() lookup utilities
sub _stream {
    my ($controller, $stream_string, $model) = @_;

    return undef unless $stream_string;

    unless ($model) {
        if ($controller->can('app')) {
            $model = $controller->app->m;
        } else {
            $model = $controller->m;
        }
    }

    my $stream;

    # if we have a hex value, search for stream based on unique_id.
    if ($stream_string =~ /^[0-9a-fA-F\-]+$/) {
        unless ($stream = $model->resultset('Stream')->find({ unique_id => $stream_string })) {
            if ($stream_string =~ /^\d+$/) {
                $stream = $model->resultset('Stream')->find({ url_name => $stream_string });
                unless ($stream) {
                    $stream = $model->resultset('Stream')->find({ common_name => $stream_string });
                    unless ($stream) {
                        $stream = $model->resultset('Stream')->find({ id => $stream_string });
                    }
                }
            } else {
                unless ($stream = $model->resultset('Stream')->find({ 'LOWER(me.url_name)' => lc($stream_string) })) {
                    $stream =
                      $model->resultset('Stream')->find({ 'LOWER(me.common_name)' => lc($stream_string) });
                }
            }
        }
    } else {
        unless ($stream = $model->resultset('Stream')->find({ 'LOWER(me.url_name)' => lc($stream_string) })) {
            $stream =
              $model->resultset('Stream')->find({ 'LOWER(me.common_name)' => lc($stream_string) });
        }
    }

    if ($stream) {
        return $stream;
    } else {
        warn "[debug] Stream search for $stream_string proved fruitless.\n" if $ENV{MERITCOMMONS_DEBUG};
        return undef;
    }
}

# replica-pointing version of _stream...
sub _stream_ro {
    my ($controller, $stream_string) = @_;

    return $controller->stream($stream_string, $controller->replica);
}

sub _message {
    my ($controller, $message_string, $model) = @_;

    return undef unless $message_string;

    unless ($model) {
        if ($controller->can('app')) {
            $model = $controller->app->m;
        } else {
            $model = $controller->m;
        }
    }

    my $msg;

    # if we have a hex value, search for message based on unique_id.
    if ($message_string =~ /^[0-9a-fA-F\-]+$/) {
        unless ($msg = $model->resultset('Stream::Message')->find({ unique_id => $message_string })) {
            if ($message_string =~ /^\d+$/) {
                $msg = $model->resultset('Stream::Message')->find({ id => $message_string });
            }
        }
    }

    return $msg;
}

# replica-pointing version of _message...
sub _message_ro {
    my ($controller, $message_string) = @_;

    return $controller->message($message_string, $controller->replica);
}

sub _user {
    my ($controller, $user_string, $model) = @_;

    return undef unless $user_string;

    unless ($model) {
        if ($controller->can('app')) {
            $model = $controller->app->m;
        } else {
            $model = $controller->m;
        }
    }

    # Resolve order unique_id -> userid -> identity_resource -> common_name
    my $user;

    # if we have a hex value, search for user based on unique_id, exception for WSU AccessID Format
    if ($user_string =~ /^[0-9a-fA-F\-]{36}$/) {
        $user = $model->resultset('User')->find({ unique_id => $user_string });
    } elsif ($user_string =~ /^\d+$/) {
        $user = $model->resultset('User')->find({ id => $user_string });
    } elsif ($user_string =~ /\@/) {
        $user = $model->resultset('User')->find({ email_address => $user_string });
    } elsif ($user_string =~ /:/) {
        $user = $model->resultset('User')->find({ public_key_fingerprint => $user_string });
    } else {
        unless ($user = $model->resultset('User')->find({ userid => $user_string })) {
            unless ($user = $model->resultset('User')->find({ identity_resource => $user_string })) {
                $user = $model->resultset('User')->find({ common_name => $user_string });
            }
        }
    }

    return $user;
}

# replica-pointing version of _user...
sub _user_ro {
    my ($controller, $user_string) = @_;

    return $controller->user($user_string, $controller->replica);
}

sub _get_permissions {
    my ($controller, $user, $stream, $relationship, $page, $rows) = @_;
    unless ($rows) {
        $rows = 10;    # This is default but being explicit
    }

    if ($user) {
        if (my $mod = $user->can_moderate($stream)) {
            if ($relationship eq 'moderators') {
                unless ($mod->allow_add_moderator) {
                    return [];
                }
            } elsif (!($relationship eq 'subscribers' || $relationship eq 'authors' || $relationship eq 'invites')) {
                return [];
            }

            my $rs;

            if ($relationship eq 'invites') {
                $rs = $stream->search_related(
                    $relationship,
                    {},
                    {
                        prefetch => [ 'inviter', 'invitee', 'stream' ],
                        rows     => $rows,
                    }
                )->page($page);
            } else {
                $rs = $stream->search_related(
                    $relationship,
                    {},
                    {
                        prefetch => [ 'meritcommons_user', 'stream' ],
                        rows     => $rows,
                    }
                )->page($page);
            }
            $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
            my @results = $rs->all;

            if ($relationship eq 'moderators') {
                my @supermods = $stream->search_related(
                    'moderators',
                    {
                        allow_add_moderator => 1
                    }
                )->all;
                my $last_moderator = -1;
                if (scalar(@supermods) == 1) {
                    $last_moderator = $supermods[0]->id;
                }

                for my $result (@results) {
                    $result->{my_own_mod}     = $result->{meritcommons_user}->{id} == $user->id ? 1 : 0;
                    $result->{last_moderator} = $result->{id} == $last_moderator             ? 1 : 0;
                }
            }

            return (scalar(@results) ? \@results : [], $rs->pager->total_entries, $rows);
        } else {
            return [];
        }
    } else {
        return [];
    }

}

sub _audit_log {
    my ($self, $message) = @_;
    my $c = $self->global_config;
    my $line = "[" . strftime("%d/%b/%Y:%H:%M:%S %z", localtime) . "] - $message";
    my $audit_log;

    if ($c->{log_to_publisher}) {
        $self->pub_write("LOG AUDIT_LOG " . $self->instance_id . " $line");
    } elsif ($c->{audit_log_syslog}) {
        foreach my $logger (@{ $self->audit_log_syslog }) {
            eval { $logger->send("@{[$self->instance_id]} $line"); };
        }
    } else {
        if (exists($c->{audit_log})) {
            open $audit_log, '>>', $c->{audit_log} or warn "[error] can't open audit log $c->{auth_log}: $!\n";
        } else {
            open $audit_log, '>>', $ENV{MERITCOMMONS_HOME} . "/../var/log/audit.log"
              or warn "[error] can't open audit log: $!\n";
        }
        print $audit_log "$line\n";
        close($audit_log);
    }
}

# COINS!
sub _bank_balance {
    my ($c) = @_;
    
    # economy size defaults to 500 million coins
    return ($c->global_config->{economy_size} // 500000000) - $c->coins_in_circulation;
}

sub _coins_in_circulation {
    my ($c) = @_;
    
    return $c->rorm->resultset('User')->search({}, {
        select => [{ sum => "meritcommonscoin_balance" }],
        as => ['coins_in_circulation']
    })->first->get_column('coins_in_circulation');
}

sub _request_coins {
    my ($c, $user, $amount, $reason) = @_;

    my $request = $c->m->resultset('User::MeritCommonscoinRequest')->create(
        {
            amount_requested => $amount,
            reason           => $reason,
            requested_by     => $user->id,
            updated_by       => $user->id,
        }
    );

    # send notification to admins
    my @admins = $c->m->resultset('Stream::Moderator')->search(
        {
            'me.stream'         => 1,
            'me.meritcommons_user' => { '!=' => 1 },
        },
        {
            prefetch => ['meritcommons_user']
        }
    )->all;

    foreach my $admin (@admins) {
        $c->notifier_write($c->user(1), $admin->meritcommons_user, $admin->meritcommons_user->personal_inbox,
            'verbatim', "/coins/admin",
            encode_base64(qq|@{[$user->common_name]} has requested $amount MeritCommonscoins.|, ''));
    }

    $c->audit_log("@{[$user->userid]} made a coin request for @{[$amount]} coins");
    return { success => "Coins have been requested." };
}

sub _respond_to_coin_request {
    my ($c, $creditor, $request_id, $approve) = @_;

    if ($creditor->is_admin) {
        my $request = $c->m->resultset('User::MeritCommonscoinRequest')->find({ id => $request_id });

        if ($request && !$request->approved) {
            my $recipient = $request->requested_by;
            my $response;

            $request->updated_by($creditor->id);
            if ($approve) {
                my $recipient_previous_balance  = $recipient->meritcommonscoin_balance;
                my $recipient_resulting_balance = $recipient_previous_balance + $request->amount_requested;

                $recipient->meritcommonscoin_balance($recipient_resulting_balance);
                $recipient->update();

                my $recipient_transaction = $c->m->resultset('User::MeritCommonscoinTransaction')->create(
                    {
                        transaction_id    => $c->new_uuid,
                        previous_balance  => $recipient_previous_balance,
                        resulting_balance => $recipient_resulting_balance,
                        amount            => $request->amount_requested,
                        transaction_type  => 'credit',
                        role              => 'receiver',
                        meritcommons_user    => $recipient->id,
                    }
                );

                $request->approved(1);
                $response = "Request has been approved. Coins have been granted.";
                $c->audit_log(
                    "@{[$recipient->userid]}'s coin request for @{[$request->amount_requested]} coins was approved by @{[$creditor->userid]}"
                );
            } else {
                $request->approved(-1);
                $response = "Request has been denied. Coins were not granted.";
                $c->audit_log(
                    "@{[$request->requested_by->userid]}'s coin request for @{[$request->amount_requested]} coins was denied by @{[$creditor->userid]}"
                );
            }

            $request->updated_by($creditor->id);
            $request->update();

            # send notification
            my $amount = $request->amount_requested;
            my $status = $request->approved == 1 ? "approved" : "denied";
            $c->notifier_write($c->user(1), $recipient, $recipient->personal_inbox,
                'verbatim', "/coins", encode_base64(qq|Your request for $amount MeritCommonscoins has been $status.|, ''));

            return { success => $response };
        } else {
            return { error => "Request could not be found or has already been responded to." };
        }
    } else {
        return { error => "You do not have permission to do this." };
    }
}

sub _transfer_coins {
    my ($c, $actor, $sender, $recipient_id, $amount) = @_;

    if ($actor->id == $sender->id || $actor->is_admin) {
        my $recipient = $c->m->resultset('User')->find({ unique_id => $recipient_id });
        if ($recipient) {
            if ($sender->meritcommonscoin_balance >= $amount) {

                my $sender_previous_balance  = $sender->meritcommonscoin_balance;
                my $sender_resulting_balance = $sender_previous_balance - $amount;
                $sender->meritcommonscoin_balance($sender_resulting_balance);

                my $recipient_previous_balance  = $recipient->meritcommonscoin_balance;
                my $recipient_resulting_balance = $recipient_previous_balance + $amount;
                $recipient->meritcommonscoin_balance($recipient_resulting_balance);

                $sender->update();
                $recipient->update();

                my $recipient_transaction = $c->m->resultset('User::MeritCommonscoinTransaction')->create(
                    {
                        transaction_id    => $c->new_uuid,
                        previous_balance  => $recipient_previous_balance,
                        resulting_balance => $recipient_resulting_balance,
                        amount            => $amount,
                        transaction_type  => 'exchange',
                        role              => 'receiver',
                        meritcommons_user    => $recipient->id,
                        second_party      => $sender->id,
                    }
                );

                my $sender_transaction = $c->m->resultset('User::MeritCommonscoinTransaction')->create(
                    {
                        transaction_id      => $c->new_uuid,
                        previous_balance    => $sender_previous_balance,
                        resulting_balance   => $sender_resulting_balance,
                        amount              => $amount,
                        transaction_type    => 'exchange',
                        role                => 'sender',
                        meritcommons_user      => $sender->id,
                        second_party        => $recipient->id,
                        related_transaction => $recipient_transaction->id,
                    }
                );

                $recipient_transaction->update({ related_transaction => $sender_transaction->id });

                $c->audit_log("@{[$sender->userid]} transferred @{[$amount]} coins to @{[$recipient->userid]}");

                my $sender_name = $sender->common_name;
                $c->notifier_write($sender, $recipient, $recipient->personal_inbox,
                    'verbatim', "/coins", encode_base64(qq|$sender_name has sent you $amount MeritCommonscoins.|, ''));

                return { success => "Coins transferred succesfully." };
            } else {
                return { error => "Sender does not have enough coins to complete this transaction." };
            }
        } else {
            return { error => "Recipient does not exist." };
        }
    } else {
        return { error => "You do not have permission to complete this transaction." };
    }
}

sub _credit_coins {
    my ($c, $creditor, $amount, $recipient_id) = @_;

    if ($creditor->is_admin) {
        my $recipient = $c->m->resultset('User')->find({ unique_id => $recipient_id });
        if ($recipient) {
            my $recipient_previous_balance  = $recipient->meritcommonscoin_balance;
            my $recipient_resulting_balance = $recipient_previous_balance + $amount;
            $recipient->meritcommonscoin_balance($recipient_resulting_balance);
            $recipient->update();

            my $receipient_transaction = $c->m->resultset('User::MeritCommonscoinTransaction')->create(
                {
                    transaction_id    => $c->new_uuid,
                    previous_balance  => $recipient_previous_balance,
                    resulting_balance => $recipient_resulting_balance,
                    amount            => $amount,
                    transaction_type  => 'credit',
                    role              => 'receiver',
                    meritcommons_user    => $recipient->id,
                }
            );

            $c->audit_log("@{[$amount]} coins were creditted to @{[$recipient->userid]} by @{[$creditor->userid]}");

            $c->notifier_write($c->user(1), $recipient, $recipient->personal_inbox,
                'verbatim', "/coins", encode_base64(qq|You have been creditted $amount MeritCommonscoins.|, ''));

            return { success => "Coins creditted succesfully." };
        } else {
            return { error => "Recipient does not exist." };
        }
    } else {
        return { error => "You do not have permission to do this." };
    }
}

sub _render_user_info_string {
    my ($self, $user) = @_;
    
    my $rv = "Basic User Information\n";
    $rv .= "----------------------\n";

    $rv .= sprintf("%-22s: %-50s\n",
        "User Name", $user->common_name . " (" . ($user->is_admin ? "@" : '') . $user->userid . ")");
    $rv .= sprintf("%-22s: %-50s\n", "Roles", join(", ", map { $_->common_name } $user->roles));
    $rv .= sprintf("%-22s: %-50s\n", "UniqueID",      $user->unique_id);
    $rv .= sprintf("%-22s: %-50s\n", "Email Address", $user->email_address);
    if ($user->title && $user->organization) {
        $rv .= sprintf("%-22s: %-50s\n", "Title/Org", $user->title . ", " . $user->organization);
    }
    $rv .= sprintf("%-22s: %-50s\n", "User Loaded From", $user->identity_resource);
    $rv .= sprintf("%-22s: %-50s\n", "Profile Pic Set",  $user->profile_picture ? "Yes" : "No");
    $rv .= sprintf("%-22s: %-50s\n", "Open Sessions",    $user->sessions->count);
    $rv .= sprintf("%-22s: %-50s\n",
        "Link Identities",
        $user->identities->count . "; " . join(", ", map { $_->identity } $user->identities));
    $rv .= sprintf("%-22s: %-50s\n",
        "Last Login Time",
        $user->last_login_time ? scalar(localtime($user->last_login_time)) : "Never Logged In");
    $rv .= sprintf("%-22s: %-50s\n", "Create Time",        scalar(localtime($user->create_time)));
    $rv .= sprintf("%-22s: %-50s\n", "Submitted Messages", $user->submitted_messages->count);
    $rv .= sprintf("%-22s: %-50s\n", "Subscribed Streams", $user->subscriptions->search({ authorized => 1 })->count);
    $rv .= sprintf("%-22s: %-50s\n", "Authored Streams",   $user->authorships->search({ authorized => 1 })->count);
    $rv .= sprintf("%-22s: %-50s\n", "Created Streams",    $user->streams->count);
    $rv .= sprintf("%-22s: %-50s\n", "Moderatorships",     $user->moderatorships->count);
    $rv .= sprintf("%-22s: %-50s\n", "Aliases",            $user->aliases->count);

    if ($user->meritcommonscoin_balance || $user->meritcommonscoin_transactions->count) {
        $rv .= "\nPromotional Messaging Information\n";
        $rv .= "---------------------------------\n";
        my $balance = $user->meritcommonscoin_balance;
        $balance = 0 unless $balance;
        $rv .= sprintf("%-22s: %-50s\n", "MeritCommonscoin Balance", $balance);

        if ($user->meritcommonscoin_transactions->count) {
            $rv .= sprintf(
                "\n%-25s %-8s %-8s %-8s %-8s %-8s\n",
                "Transaction Time",
                "Type", "Role", "Cost", "PrevBal", "NewBal"
            );
            $rv .= join(' ', "-" x 25, "-" x 8, "-" x 8, "-" x 8, "-" x 8, "-" x 8) . "\n";
            foreach
              my $txn ($user->meritcommonscoin_transactions->search({}, { order_by => { "-desc" => 'create_time' } })->all) {
                $rv .= sprintf(
                    "%-25s %-8s %-8s %-8s %-8s %-8s\n",
                    scalar(localtime($txn->create_time)),
                    $txn->transaction_type, $txn->role, $txn->amount, $txn->previous_balance, $txn->resulting_balance
                );
            }
        }
    }

    my $self_identity = $user->identities->search({}, { order_by => { "-desc" => 'multiplier' } })->first;
    if ($self_identity) {
        $rv .= "\nLinks Clicked\n";
        $rv .= "-------------\n";
        my %links;

        foreach my $click ($self_identity->clicks) {
            my $link  = $click->link;
            my $title = $link->title;
            next unless $title;
            $links{$title} = $click->counter;
        }

        foreach my $link (sort { $links{$b} <=> $links{$a} } keys %links) {
            $rv .= sprintf("    %-50s: %-20s\n", $link, $links{$link});
        }
    }

    $rv .= "\nStream Information\n";
    $rv .= "------------------\n";
    $rv .= sprintf("%-22s: %-50s\n",
        "Personal Inbox",
        $user->personal_inbox->unique_id . " (" . $user->personal_inbox->messages->count . " messages)");
    $rv .= sprintf("%-22s: %-50s\n",
        "Personal Outbox",
        $user->personal_outbox->unique_id . " (" . $user->personal_outbox->messages->count . " messages)");
    $rv .= sprintf("%-22s: %-50s\n",
        "Notification Inbox",
        $user->notification_inbox->unique_id . " (" . $user->notification_inbox->messages->count . " messages)");
    $rv .= sprintf("%-22s: %-50s\n", "Followers", $user->personal_outbox->subscribers->count);

    $Text::Wrap::columns = 28;

    $rv .= "Moderator Of:\n";
    foreach my $stream (map { $_->stream } $user->moderatorships->all) {
        my @title = split(/\n/, wrap('', '', $stream->common_name));
        if (scalar(@title) == 1) {
            $rv .= sprintf("    %-30s (%32s)\n", $title[0], $stream->unique_id);
        } else {

            # print the first line of the title.
            $rv .= sprintf("    %-30s\n", $title[0]);

            # print all lines of the title after the first, before the last
            for (my $i = 1 ; $i < $#title ; $i++) {
                $rv .= sprintf("      %-28s\n", $title[$i]);
            }

            # print the last
            $rv .= sprintf("      %-28s (%32s)\n", $title[$#title], $stream->unique_id);
        }
    }

    $rv .= "Subscribed To:\n";
    foreach my $stream (map { $_->stream } $user->subscriptions->all) {
        my @title = split(/\n/, wrap('', '', $stream->common_name));
        if (scalar(@title) == 1) {
            $rv .= sprintf("    %-30s (%32s)\n", $title[0], $stream->unique_id);
        } else {

            # print the first line of the title.
            $rv .= sprintf("    %-30s\n", $title[0]);

            # print all lines of the title after the first, before the last
            for (my $i = 1 ; $i < $#title ; $i++) {
                $rv .= sprintf("      %-28s\n", $title[$i]);
            }

            # print the last
            $rv .= sprintf("      %-28s (%32s)\n", $title[$#title], $stream->unique_id);
        }
    }

    $rv .= "Author On:\n";
    foreach my $stream (map { $_->stream } $user->authorships->all) {
        my @title = split(/\n/, wrap('', '', $stream->common_name));
        if (scalar(@title) == 1) {
            $rv .= sprintf("    %-30s (%32s)\n", $title[0], $stream->unique_id);
        } else {

            # print the first line of the title.
            $rv .= sprintf("    %-30s\n", $title[0]);

            # print all lines of the title after the first, before the last
            for (my $i = 1 ; $i < $#title ; $i++) {
                $rv .= sprintf("      %-28s\n", $title[$i]);
            }

            # print the last
            $rv .= sprintf("      %-28s (%32s)\n", $title[$#title], $stream->unique_id);
        }
    }

    my $config = $user->config;
    if (scalar(keys %$config)) {
        $rv .= "\nUser Configuration Settings\n";
        $rv .= "---------------------------\n";

        foreach my $key (keys %$config) {
            $rv .= sprintf("%-32s: %-40s\n", $key, join(', ', @{ $config->{$key} }));
        }
    }

    if ($user->sessions->count >= 1) {
        $rv .= "\nSession/Client Attributes\n";
        $rv .= "--------------------------\n";
        my $session = $user->sessions->first;
        foreach my $attribute ($session->attributes->all) {
            $rv .= sprintf("%-32s: %-40s\n", $attribute->k, join(', ', map { $_->v } $attribute->vals));
        }
    }
    
    $rv .= "\n";
    
    return $rv;
}

1;

=pod

=head1 NAME

L<MeritCommons::Helper::DataUtil>

=head1 SYNOPSIS

A collection of utilities surrounding message data + retrieval including access control, streams, and string manipulation

=head1 AUTHOR

The MeritCommons Action Team <meritcommons@wayne.edu>

=head1 HELPERS

L<MeritCommons::Helper::DataUtil> provides the following B<HELPERS> to MeritCommons

=over 2

B<message>, B<stream>, B<user> ( UNIQUEID )

These are convenience methods that return database objects.  They may be passed any known unique identifier for that data including but not limited to unique_id, database numeric id, username, or stream common_name.

    # in a template...
    % my $user = $self->user(2);
    <%= $user->common_name %> is awesome!

B<merged_messages> ( {OPTS}, (STREAMS) )

Retrieve messages by subscriptions or by a given list of streams for a user, limited by B<$opts-E<gt>{limit}>.  Messages are returned as "prepared payloads", messages that have been run through the content driver system.

B<OPTS> is a hashref containing one or more of:

 $opts = {
            after => '112345678', # A time boundry in UNIX TIME, default time() (now)
            after_id => '500', # A sequential ID boundry, default 9223372036854775807
            limit => '50', # The number of message objects to return, default 50
            user => $user, # The meritcommons user we're performing the searches as, 
                                         # required, no default. (Though one could easily use 
                                         # $controller->user(1) here to query as the 'root' user)
    }

B<STREAMS> is a list of streams to include, they must all be instantiated schema MeritCommons::Model::Stream objects.  If the list of streams is omitted the default behavior is to use all streams that the querying user is currently subscribed to.

B<single_stream_messages> ( USER, STREAM, LIMIT, AFTER )

A wrapper around B<merged_messages> that lets you pass the options as parameters to retrieve messages from a single stream.  Messages are returned as "prepared payloads", messages that have been run through the content driver outbound system.

B<multiple_stream_messages> ( USER, [STREAMS], LIMIT, AFTER )

A wrapper around B<merged_messages> that lets you pass the options as parameters to retrieve messages from multiple streams (passed as an arrayref).  Messages are returned as "prepared payloads", messages that have been run through the content driver outbound system.

B<stream_generate_url_name> ( STRING )

Generate a unique url_name given a string.  The string is reformatted so that it meets the formatting requirements for a URL name.  If the URL name already exists, then an auto-incrementing suffix will be appended to make it unique.

A wrapper around B<merged_messages> that lets you pass the options as parameters to retrieve messages from multiple streams (passed as an arrayref).  Messages are returned as "prepared payloads", messages that have been run through the content driver outbound system.

B<prepare_payload> ( [?MESSAGE], USER, GROUP_BY_THREAD )

Conditionally transforms a scalar or an array ref full of message objects into their corresponding JavaScript/Perl interop formatted hashref data structures for a given user, and optionally with full thread context.  Returns a scalar or a list of hashrefs.

B<prepare_payload_collection> ( [MESSAGES], USER, GROUP_BY_THREAD )

Transforms an array ref full of message objects into their corresponding JavaScript/Perl interop formatted hashref data structures for a given user, and optionally with full thread context.  Returns a scalar or a list of hashrefs.

B<prepare_payload_single> ( MESSAGE, USER )

Transforms a single message object into its corresponding JavaScript/Perl interop formatted hashref data structure for a given user.  Returns a hashref.

B<prepare_payload_message_attributes> ( MESSAGE, USER )

Called in the implementation of both B<prepare_payload_collection> and B<prepare_payload_single>, this helper is what pushes the content of a given message object through the content driver stack and returns it as a hashref.

B<user_messages> ( USER, LIMIT, AFTER )

Get all messages authored by a given user limited by B<LIMIT> (default 50), submitted after B<AFTER>.

B<add_identity_to_user> ( USER, IDENTITY, MULTIPLIER )

Add an identity to a B<USER> specified as a string B<IDENTITY>, with a given B<MULTIPLIER> that is the weight of this identity on swaying default order of content in MeritCommons.  B<IDENTITY> should be a string that is unique to a user or a group of users, and B<MULTIPLIER> should score its generality or specificity accordingly.

B<truncate> ( STRING, LENGTH, BREAK_ON_WORD )

Filters out HTML, and generates a truncated string of no more than B<LENGTH> characters.  Conditionally breaks the string on the last word, otherwise will break at the B<LENGTH> specified even in the middle of a word.

=back

=cut
