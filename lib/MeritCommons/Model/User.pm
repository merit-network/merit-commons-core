#    MeritCommons Portal
#    Copyright 2013-2017 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User;

use Mojo::Collection;
use Sphinx::Search;
use Net::LDAP;
use Digest::MD5 qw/md5_hex/;
use base qw/DBIx::Class/;
use Carp qw(croak);
use Data::Dumper;

__PACKAGE__->load_components(qw/+DBIx::ClassAttachment PK::Auto Core/);
__PACKAGE__->table('meritcommons_user');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    common_name => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    email_address => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    organization => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    title => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    nick_name => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    userid => {
        data_type => 'varchar',
        size      => 255,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    unique_id => {
        data_type => 'varchar',
        size      => 64,
    },
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    last_login_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 1,
    },
    public_key_fingerprint => {
        data_type   => 'varchar',
        is_nullable => 128,
    },
    public_key => {
        data_type   => 'text',
        is_nullable => 1,
    },
    secret_key => {
        data_type   => 'text',
        is_nullable => 1,
    },
    visiting_user => {
        data_type     => 'integer',
        default_value => 0,
    },
    home_server => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    meritcommonscoin_balance => {
        data_type     => 'integer',
        default_value => 0,
        is_numeric    => 1,
    },
    personal_inbox => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    personal_outbox => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,           # chicken / egg, must create user before stream
    },
    notification_inbox => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    external_unique_id => {
        data_type   => 'varchar',
        is_nullable => 1,
        size        => 255,
    },
    identity_resource => {
        data_type => 'text',
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    personal_inbox => 'MeritCommons::Model::Stream',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);
__PACKAGE__->belongs_to(
    personal_outbox => 'MeritCommons::Model::Stream',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);
__PACKAGE__->belongs_to(
    notification_inbox => 'MeritCommons::Model::Stream',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);
__PACKAGE__->has_many(attributes         => 'MeritCommons::Model::User::Attribute',    'meritcommons_user');
__PACKAGE__->has_many(submitted_messages => 'MeritCommons::Model::Stream::Message',    'submitter');
__PACKAGE__->has_many(sessions           => 'MeritCommons::Model::Session',            'meritcommons_user');
__PACKAGE__->has_many(streams            => 'MeritCommons::Model::Stream',             'creator');
__PACKAGE__->has_many(authorships        => 'MeritCommons::Model::Stream::Author',     'meritcommons_user');
__PACKAGE__->has_many(subscriptions      => 'MeritCommons::Model::Stream::Subscriber', 'meritcommons_user');
__PACKAGE__->has_many(moderatorships     => 'MeritCommons::Model::Stream::Moderator',  'meritcommons_user');
__PACKAGE__->has_many(roleusers          => 'MeritCommons::Model::User::RoleUser',     'meritcommons_user');
__PACKAGE__->has_many(identityusers      => 'MeritCommons::Model::User::IdentityUser', 'meritcommons_user');

__PACKAGE__->has_many(message_attachment_uploads => 'MeritCommons::Model::Stream::Message::Attachment',  'uploader');
__PACKAGE__->has_many(aliases                    => 'MeritCommons::Model::User::Alias',                  'meritcommons_user');
__PACKAGE__->has_many(nicknames_for_others       => 'MeritCommons::Model::User::Alias',                  'owner');
__PACKAGE__->has_many(meritcommonscoin_transactions   => 'MeritCommons::Model::User::MeritCommonscoinTransaction', 'meritcommons_user');
__PACKAGE__->has_many(message_tags               => 'MeritCommons::Model::Stream::Message::Tag',         'meritcommons_user');
__PACKAGE__->has_many(invites                    => 'MeritCommons::Model::Stream::Invite',               'invitee');
__PACKAGE__->has_many(votes                      => 'MeritCommons::Model::Stream::Message::Vote',        'voter');
__PACKAGE__->has_many(blocked_entities           => 'MeritCommons::Model::User::BlockedEntity',          'meritcommons_user');

__PACKAGE__->has_many(watched_users    => 'MeritCommons::Model::User::Watcher',            'watcher');
__PACKAGE__->has_many(watched_messages => 'MeritCommons::Model::Stream::Message::Watcher', 'watcher');
__PACKAGE__->has_many(watched_streams  => 'MeritCommons::Model::Stream::Watcher',          'watcher');

# i always feel like... somebody's WATCHING meeeeeee
__PACKAGE__->has_many(watched => 'MeritCommons::Model::User::Watcher', { 'foreign.target' => 'self.unique_id' });
__PACKAGE__->many_to_many(watchers => 'watched', 'watcher');

__PACKAGE__->many_to_many(roles      => 'roleusers',     'role');
__PACKAGE__->many_to_many(identities => 'identityusers', 'identity');

# changelog
__PACKAGE__->has_many(
    changes => 'MeritCommons::Model::User::ChangeLog',
    'meritcommons_user', { cascade_delete => 0, is_foreign_key_constraint => 0 }
);

__PACKAGE__->add_unique_constraint(['userid']);
__PACKAGE__->add_unique_constraint(['unique_id']);
__PACKAGE__->add_unique_constraint(['external_unique_id']);
__PACKAGE__->add_unique_constraint(['public_key_fingerprint']);

# Attachment configuration
__PACKAGE__->has_attachment(
    'profile_picture',
    {
        'tiny' => [
            {
                'thumbnail' => {
                    'geometry' => '30x30^',
                },
                'autoOrient' => {},
            },
            {
                'extent' => {
                    'geometry' => '30x30',
                    'gravity'  => 'Center',
                },
                'autoOrient' => {},
            },
        ],
        'thumbnail' => [
            {
                'thumbnail' => {
                    'geometry' => '64x64^',
                },
                'autoOrient' => {},
            },
            {
                'extent' => {
                    'geometry' => '64x64',
                    'gravity'  => 'Center',
                },
                'autoOrient' => {},
            },
        ],
        'large' => [
            {
                'resize' => {
                    'geometry' => '500x',
                },
                'autoOrient' => {},
            },
        ],
        'medium' => [
            {
                'resize' => {
                    'geometry' => '220x',
                },
                'autoOrient' => {},
            },
        ],
        'small' => [
            {
                'resize' => {
                    'geometry' => '64x',
                },
                'autoOrient' => {},
            },
        ],
    }
);

# link collection stuff.
sub should_see_link_collection {
    my ($self, $link_collection) = @_;

    # if we're an admin, we should see this link collection regardless of role.
    if ($self->is_admin()) {
        return 1;
    }

    my @lc_roles   = $link_collection->roles;
    my @user_roles = $self->roles;
    if (scalar(@lc_roles)) {
        if (scalar(@user_roles)) {
            foreach my $lrole (@lc_roles) {
                foreach my $role (@user_roles) {
                    if ($lrole->id == $role->id) {

                        # yes, user has role required by link collection
                        return 1;
                    }
                }
            }
        }

        # no, user does not have role required by link collection.
        return undef;
    } else {

        # yes.  link collection has no roles, so everyone should see!
        return 1;
    }
}

sub gravatar_thumbnail_url {
    return shift->gravatar_url(64);
}

sub gravatar_small_url {
    return shift->gravatar_url(64);
}

sub gravatar_medium_url {
    return shift->gravatar_url(220);
}

sub gravatar_large_url {
    return shift->gravatar_url(500);
}

sub gravatar_profile_url {
    return shift->gravatar_url(200);
}

sub gravatar_tiny_url {
    return shift->gravatar_url(30);
}

sub gravatar_url {
    my ($self, $size) = @_;
    if (my $email_address = lc($self->email_address)) {
        my $hash = md5_hex($email_address);
        return "//www.gravatar.com/avatar/$hash.jpg?s=$size&d=identicon";
    }
    return undef;
}

# users this users follows
sub following {
    my ($self) = @_;
    my @following;
    foreach my $stream ($self->authorized_subscribed_personal_streams) {
        push(@following, $stream->personal_outbox_user);
    }
    return @following;
}

# users following me.
sub followers {
    my ($self) = @_;
    my @following;
    eval {
        foreach my $subscription ($self->result_source->schema->resultset('Stream::Subscriber')
            ->search({ stream => $self->personal_outbox->id })) {
            push(@following, $subscription->meritcommons_user);
        }
    };
    return @following;
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'userid_idx',
        fields => ['userid'],
    );

    $sqlt_table->add_index(
        name   => 'uuid_idx',
        fields => ['unique_id'],
    );

    $sqlt_table->add_index(
        name   => 'cn_idx',
        fields => ['common_name'],
    );

    $sqlt_table->add_index(
        name   => 'identity_resource_idx',
        fields => ['identity_resource'],
    );

    $sqlt_table->add_index(
        name   => 'public_key_fingerprint_idx',
        fields => ['public_key_fingerprint'],
    );

    $sqlt_table->add_index(
        name   => 'email_address_idx',
        fields => ['email_address'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_user_external_unique_id_idx',
        fields => ['external_unique_id'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_user_idx_personal_inbox',
        fields => ['personal_inbox'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_user_idx_personal_outbox',
        fields => ['personal_outbox'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_user_idx_notification_inbox',
        fields => ['notification_inbox'],
    );
}

# filters an array of messages to only those that the user can see
sub authorized_messages_filter {
    my ($self, @message_ids) = @_;

    my $messages = $self->result_source->schema->resultset('Stream::Message')->search(
        {
            'me.unique_id' => [@message_ids],
            -or            => [
                -and => [
                    'stream.id' => {
                        -in => $self->authorized_subscriptions->get_column('stream')->as_query
                    },
                    'stream.requires_subscriber_authorization' => 1,
                ],
                'stream.requires_subscriber_authorization' => 0,
            ],
        },
        {
            join => {
                message_streams => 'stream'
            },
            distinct => 1,
        }
    );

    return $messages;
}

sub authorized_subscriptions {
    my ($self) = @_;

    # Subquery of authorized subscriptions
    return $self->result_source->schema->resultset('Stream::Subscriber')->search(
        {
            'me.meritcommons_user' => $self->id,
            'me.authorized'     => 1
        }
    );
}

sub authorized_authorships {
    my ($self) = @_;

    # Subquery of authorized subscriptions
    return $self->result_source->schema->resultset('Stream::Author')->search(
        {
            'me.meritcommons_user' => $self->id,
            'me.authorized'     => 1
        }
    );
}

# filters an array of streams to only those that the user can see
sub authorized_streams_filter {
    my ($self, @stream_ids) = @_;

    # Run a check to make sure that the user is authorized for all of the passed streams, or that
    # the streams don't require authorization
    return (
        $self->result_source->schema->resultset('Stream')->search(
            {
                'me.id' => [@stream_ids],
                -or     => [
                    -and => [
                        'me.id' => {
                            -in => $self->authorized_subscriptions->get_column('stream')->as_query
                        },
                        'me.requires_subscriber_authorization' => 1,
                    ],
                    'me.requires_subscriber_authorization' => 0,
                ],
            }
        )->all
    );
}

# filters an array of streams to only those that the user can write to
sub authorized_authorship_streams_filter {
    my ($self, @stream_ids) = @_;

    # Run a check to make sure that the user is authorized for all of the passed streams, or that
    # the streams don't require authorization
    return (
        $self->result_source->schema->resultset('Stream')->search(
            {
                'me.id' => [@stream_ids],
                -or     => [
                    -and => [
                        'me.id' => {
                            -in => $self->authorized_authorships->get_column('stream')->as_query
                        },
                        'me.requires_author_authorization' => 1,
                    ],
                    'me.requires_author_authorization' => 0,
                ],
            }
        )->all
    );
}

# filters an array of streams to only those that the user can see which are personal_outbox streams
sub authorized_personal_streams_filter {
    my ($self, @stream_ids) = @_;

    # Run a check to make sure that the user is authorized for all of the passed streams, or that
    # the streams don't require authorization
    return (
        $self->result_source->schema->resultset('Stream')->search(
            {
                'me.id'                => [@stream_ids],
                'personal_outbox_user' => { '!=' => undef },
                -or                    => [
                    -and => [
                        'me.id' => {
                            -in => $self->authorized_subscriptions->get_column('stream')->as_query
                        },
                        'me.requires_subscriber_authorization' => 1,
                    ],
                    'me.requires_subscriber_authorization' => 0,
                ],
            }
        )
    );
}

# return a list of streams that the user is subscribed to and authorized to view
sub authorized_subscribed_streams {
    my ($self) = @_;
    my @stream_ids = map { $_->get_column('stream') } $self->subscriptions;
    return $self->authorized_streams_filter(@stream_ids);
}

sub authorized_subscribed_personal_streams {
    my ($self) = @_;
    my @stream_ids = map { $_->get_column('stream') } $self->subscriptions;
    return $self->authorized_personal_streams_filter(@stream_ids);
}

sub most_clicked_links {
    my ($self, $lim) = @_;

    $self->link_role_filter(
        $self->result_source->schema->resultset('Link')->search(
            {
                'identityusers.meritcommons_user' => $self->id,
                'clicks.id'                    => { "!=" => undef }
            },
            {
                join   => [ { clicks => { 'identity' => 'identityusers' } } ],
                select => [
                    qw/
                      id      create_time     modify_time     creator     icon_class      href
                      title   short_loc       keywords        target      type
                      /,
                    { concat => [ '\'/link/\'', 'me.short_loc' ], -as => 'relative_short' },
                    { max => 'clicks.counter', -as => 'click_count' },
                ],
                group_by => 'me.id',
                order_by => {
                    "-desc" => 'cast(sum(cast(identity.multiplier as int8) * cast(clicks.counter as int8)) as bigint)'
                },
                rows         => $lim,
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        )->all
    );
}

sub can_read {
    my ($self, $stream) = @_;

    return 0 unless $stream;

    # block notification inbox and personal inbox from everyone but their rightful owner
    if ($stream->single_subscriber) {
        if (my $piu = $stream->personal_inbox_user) {
            if ($piu->id == $self->id) {
                return 1;
            } else {
                return 0;
            }
        }

        if (my $niu = $stream->notification_inbox_user) {
            if ($niu->id == $self->id) {
                return 1;
            } else {
                return 0;
            }
        }
    }

    # check for authorized subscription
    my $can_read = 0;
    my $sub      = $self->is_subscriber($stream);
    if ($sub) {
        if ($sub->authorized) {
            $can_read = 1;
        }
    }

    # check for open stream permissions
    unless ($can_read) {
        if (!$stream->private && !$stream->requires_subscriber_authorization) {
            $can_read = 1;
        }
    }

    return $can_read;
}

sub is_subscriber {
    my ($self, $stream) = @_;

    my $sub = $self->subscriptions->search({ stream => $stream->id })->first;

    if ($sub != undef) {

        # Double-check that there is a match.  Use get_column() to avoid another query for the relation
        if ($stream->id == $sub->get_column('stream')) {

            # the user is subscribed
            return $sub;
        } else {

            # we got something back, but it wasn't what we expected
            return undef;
        }
    } else {

        # no subscriptions found
        return undef;
    }
}

sub has_role {
    return shift->roles->find({ common_name => lc(shift) });
}

sub can_write {
    my ($self, $stream) = @_;

    my $aut = $self->is_author($stream);
    if (!$stream->requires_author_authorization || ($aut && $aut->authorized)) {
        return 1;
    } else {
        return 0;
    }
}

sub is_author {
    my ($self, $stream) = @_;

    my $aut = $self->result_source->schema->resultset('Stream::Author')->search(
        {
            meritcommons_user => $self->id,
            stream         => $stream->id
        }
    )->first;

    return ($aut) ? $aut : undef;
}

# Check if the user is an admin, which in MeritCommons really means whether or
# not they have moderator on stream 1. If so, return that moderatorship object.
sub is_admin {
    my ($self) = @_;

    unless (defined $self->{___cached_is_admin}) {
        $self->{___cached_is_admin} = $self->moderatorships->find(
            {
                # user must be the moderator of stream 1 (they're an admin)
                stream => 1
            }
        );
    }

    return $self->{___cached_is_admin};
}

# Checks if this user is a moderator on this specific stream, returning
# the moderatorship if so. If so, return that moderatorship object.
sub is_moderator {
    my ($self, $stream) = @_;

    my $stream_moderator = $self->moderatorships->search(
        {
            stream => $stream->id
        }
    )->first;

    return ($stream_moderator) ? $stream_moderator : undef;
}

# only determines whether or not the user can moderate the given stream,
# without caring why. Being a moderator or an admin is good enough.
sub can_moderate {
    my ($self, $stream) = @_;

    return $self->is_admin() || $self->is_moderator($stream);
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self->next::method(@args);
}

# do this extra stuff on update
sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    if ($self->is_column_changed('common_name')) {
        # common name changed, update the stream to reflect the new name.
        $self->personal_outbox->update({common_name => $self->common_name});
    }
    $self->next::method(@args);
}

# link role filter
sub link_role_filter {
    my ($self, @links) = @_;
    my @filtered;
    if ($self->is_admin) {
        @filtered = @links;
    } else {
      LINK: foreach my $link (@links) {
            my $l_obj;
            if (ref $link eq "HASH") {
                $l_obj = $self->result_source->schema->resultset('Link')->search({ id => $link->{id} })->first;
            } else {
                $l_obj = $link;
            }

            # this isn't a link... no good.
            next LINK unless $l_obj;

            if (my @roles = $self->roles) {
                foreach my $role (@roles) {
                    if (my @lroles = $l_obj->roles) {

                        # this link has roles, so it's only viewable by users who have one or more of the same roles it has.
                        foreach my $link_role (@lroles) {
                            if ($link_role->id == $role->id) {
                                push(@filtered, $link);
                                next LINK;
                            }
                        }
                    } else {

                        # this link has no roles, so it's viewable by all users.
                        push(@filtered, $link);
                        next LINK;
                    }
                }
            } else {
                if (my @lroles = $l_obj->roles) {
                    next LINK;
                } else {
                    push(@filtered, $link);
                    next LINK;
                }
            }
        }
    }
    return (@filtered);
}

sub search_streams {
    my ($self, $sph, $search_string, $opts) = @_;

    my $results;

    if (ref($search_string) eq "HASH") {
        $opts          = $search_string;
        $search_string = $opts->{search_string};
    }

    # emulate SPH_MATCH_ALL
    $search_string =~ s/\s+/ \& /g;

    if ($search_string) {
        $results = $sph->SetSortMode(SPH_SORT_RELEVANCE)->SetLimits(0, 2000)->Query($search_string, "streams");
    }

    if (ref $opts eq "HASH") {
        if (!$search_string && $opts->{my_authorships_only}) {

            # Short circuit it right here if they just want their own authorships just give them to them.
            warn "[debug] User::search_streams() my_authorships_only\n" if $ENV{MERITCOMMONS_DEBUG};
            return (
                $self->result_source->schema->resultset('Stream')->search(
                    {
                        'authors.authorized'     => 1,
                        'authors.meritcommons_user' => $self->id
                    },
                    {
                        join => ['authors']
                    }
                )->all
            );
        } else {

            # do the more complex query.. build the 'where' from the options...
            my $where = {};
            my $search_opts = { order_by => { -desc => ['common_name'] }, };

            # if we did a string search, limit what we return to those results, otherwise just search based on
            # the options.
            if ($search_string && $results) {
                $where->{'me.id'} = [ map { $_->{doc} } grep { $_->{doc} != 1 } @{ $results->{matches} } ];
            }

            # exclude these by default
            unless ($opts->{include_private}) {
                $where->{'me.private'} = { '!=', 1 };
            }
            unless ($opts->{include_single_subscriber}) {
                $where->{'me.single_subscriber'} = { '!=', 1 };
            }
            unless ($opts->{include_personal_outboxes}) {
                $where->{'me.personal_outbox_user'} = undef;
            }

            # optionally include these
            if (my $min_sub = $opts->{minimum_subscribers}) {
                $where->{'me.subscriber_count'} = { '>=', $min_sub };
            }

            if (my $type = $opts->{type}) {
                $where->{'me.type'} = $type if $search_string;
            } elsif (my $type = $opts->{type_when_empty}) {
                $where->{'me.type'} = $type if !$search_string;
            }

            if (my $subtype = $opts->{subtype}) {
                $where->{'me.subtype'} = $subtype if $search_string;
            } elsif (my $subtype = $opts->{subtype_when_empty}) {
                $where->{'me.subtype'} = $subtype if !$search_string;
            }

            if ($opts->{my_authorships_only}) {
                $where->{'authors.authorized'}     = 1;
                $where->{'authors.meritcommons_user'} = $self->id;
                $search_opts->{'join'}             = ['authors'];
            }

            if ($ENV{MERITCOMMONS_DEBUG}) {
                local $Data::Dumper::Terse = 1;
                warn "[debug] ----- BEGIN OPTS -----\n";
                warn Dumper($opts);
                warn "[debug] ----- END OPTS -----\n";
                warn "[debug] ----- BEGIN WHERE -----\n";
                warn Dumper($where);
                warn "[debug] ----- END WHERE -----\n";
                warn "[debug] ----- BEGIN QUERY CFG -----\n";
                warn Dumper($search_opts);
                warn "[debug] ----- END QUERY CFG -----\n";
            }

            return ($self->result_source->schema->resultset('Stream')->search($where, $search_opts)->all);
        }
    } else {

        # default behavior returns this user's filtered streams.
        return (
            $self->authorized_streams_filter(
                sort { $a cmp $b }
                map  { $_->{doc} } @{ $results->{matches} }
            )
        );
    }
}

# perform user-based link search
sub search_links {
    my ($self, $sph, $search_string) = @_;

    # emulate SPH_MATCH_ANY
    $search_string =~ s/\s+/ \| /g;

    my $results = $sph->SetSortMode(SPH_SORT_RELEVANCE)->SetLimits(0, 200)->Query($search_string, "links");

    my @links = $self->result_source->schema->resultset('Link')->search(
        {
            id   => [ map { $_->{doc} } @{ $results->{matches} } ],
            type => 'system',
        },
        {
            order_by => { -asc => [ 'type', 'title' ] },
        }
    )->all;

    return $self->link_role_filter(@links);
}

# perform user-based message search
sub search_messages {
    my ($self, $sph, $search_string, $after, $after_id, @search_stream_filter) = @_;

    my @search_streams;
    if (@search_stream_filter) {

        # a stream filter was defined, filter by it
        foreach my $sub ($self->authorized_streams_filter(@search_stream_filter)) {
            push(@search_streams, $sub->id);
        }
    } else {

        # a stream filter was not defined, default to all authorized subscriptions
        foreach my $sub ($self->authorized_subscribed_streams) {
            push(@search_streams, $sub->id);
        }
    }

    # only attempt a Sphinx search if there are authorized streams
    my @message_ids;

    # emulate SPH_MATCH_ALL
    $search_string =~ s/\s+/ \& /g;

    if (scalar(@search_streams) > 0) {
        my $results;
        if ($after) {
            $results =
              $sph->SetSortMode(SPH_SORT_ATTR_DESC, "post_time")->SetFilter('stream_id', \@search_streams)
              ->SetFilterRange('post_time', 0, ($after - 1))->SetFilterRange('message_id', 0, ($after_id - 1))
              ->SetLimits(0, 10)->Query($search_string, "messages");
        } else {
            $results = $sph->SetSortMode(SPH_SORT_ATTR_DESC, "post_time")->SetFilter('stream_id', \@search_streams)
              ->SetLimits(0, 10)->Query($search_string, "messages");
        }

        @message_ids = map { $_->{doc} } @{ $results->{matches} };
    } else {
        @message_ids = ();
    }

    # Get the thread ids for the message, and then load the entire threads
    my @thread_messages =
      $self->result_source->schema->resultset('Stream::Message')->search({ 'me.id' => \@message_ids });
    my @thread_ids = map { $_->thread_id } @thread_messages;
    my $messages = $self->result_source->schema->resultset('Stream::Message')->search(
        {
            'me.unique_id'           => \@thread_ids,
            'message_streams.stream' => \@search_streams,
        },
        {
            join => {
                message_streams => {
                    stream => 'subscribers',
                },
            },
            prefetch => [ { message_streams => 'stream', }, 'submitter', ],
            distinct => 1,
            order_by => {
                "-desc" => 'me.post_time',
                "-desc" => 'me.id'
            },
        }
    );

    return ($messages->all);
}

sub config {
    my ($self, $option, @values) = @_;

    if ($option) {
        # add the _config_ prefix...
        $option = "_config_" . $option;
        my $c = $self->$option(@values);
        return wantarray ? @$c : $c->first;
    } else {
        # return a read-only hashref of all config variables.
        my $config = {};
        foreach
          my $attribute ($self->attributes->search({ "me.k" => { LIKE => '_config_%' } }, { prefetch => ['vals'] })) {
            my ($k) = $attribute->k =~ /^_config_(.+)$/;
            $config->{$k} = [ map { $_->v } $attribute->vals ];
        }

        return $config;
    }
}

# returns a hashref copy.
sub as_hashref {
    my %hash = (%{ shift->{_column_data} });
    return \%hash;
}

sub DESTROY {
    return;
}

sub first_attribute_value {
    my ($self, $name) = @_;
    my $attr = $self->$name;
    if ($attr) {
        return $attr->first;
    }
    return undef;
}

sub last_attribute_value {
    my ($self, $name) = @_;
    my $attr = $self->$name;
    if ($attr) {
        return $attr->last;
    }
    return undef;
}

# the autoloader.  is here.  scary.
sub AUTOLOAD {
    my ($self, @values) = @_;
    our $AUTOLOAD;
    my $name = $AUTOLOAD;
    $name =~ s/.*:://g;
    my $attribute;

    if (ref($values[0]) eq "Mojo::Collection") {
        @values = @{$values[0]};
    }

    if ($self->attributes) {
        $attribute = $self->attributes->search(
            {
                k => $name,
            }
        )->first;
    }

    if ($attribute) {
        if (scalar(@values)) {
            if ($values[0] eq "__clear__") {
                $attribute->delete;
                return Mojo::Collection->new(undef);
            } else {

                # set all the new values!
                $attribute->vals->delete_all;
                foreach my $value (@values) {
                    $attribute->vals->create(
                        {
                            v => $value,
                        }
                    );
                }
            }
        }

        # "__clear__" is not a legal value for an attribute, if we find it in the database, we remove the attribute.
        foreach my $v ($attribute->vals) {
            if ($v->v eq "__clear__") {
                $attribute->delete;
                return Mojo::Collection->new(undef);
            }
        }

        if (defined $attribute->vals->first) {
            return Mojo::Collection->new(map { $_->v } $attribute->vals);
        }
    } else {
        if (scalar(@values) && $values[0] ne "__clear__") {
            my $attr = $self->attributes->create(
                {
                    k => $name,
                }
            );
            
            foreach my $value (@values) {
                $attr->vals->create(
                    {
                        v => $value,
                    }
                );
            }
            return Mojo::Collection->new(map { $_->v } $attr->vals);
        }
    }
    
    return Mojo::Collection->new(undef);
}

1;