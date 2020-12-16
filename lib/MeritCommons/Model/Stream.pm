#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/+DBIx::ClassAttachment PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    short_name => {
        data_type   => 'varchar',
        size        => 8,
        is_nullable => 1,
    },
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    unique_id => {
        data_type => 'varchar',
        size      => 255,
    },
    common_name => {
        data_type => 'varchar',
        size      => 255,
    },
    configuration => {
        data_type   => 'text',
        is_nullable => 1,
    },
    origin => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    creator => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    single_author => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    single_subscriber => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    disabled => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    earns_return => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 1,
    },
    toll_required => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    requires_subscriber_authorization => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    requires_author_authorization => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    allow_unsubscribe => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 1,
    },
    allow_add_moderator => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    open_reply => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 1,
    },
    personal_inbox_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    personal_outbox_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    notification_inbox_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    description => {
        data_type   => 'text',
        is_nullable => 1,
    },
    keywords => {
        data_type   => 'text',
        is_nullable => 1,
    },
    url_name => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    type => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/user system role/],
        },
        is_nullable => 1,
    },
    subtype => {
        data_type   => 'varchar',
        is_nullable => 1,
        size        => 255,
    },
    external_unique_id => {
        data_type   => 'varchar',
        is_nullable => 1,
        size        => 255,
    },
    public_key => {
        data_type   => 'text',
        is_nullable => 1,
    },
    secret_key => {
        data_type   => 'text',
        is_nullable => 1,
    },
    show_publicly => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    display_subscribers => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    subscriber_count => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    author_count => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    moderator_count => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    members_can_invite => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    private => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    membership_requires_moderator_approval => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(creator => 'MeritCommons::Model::User');
__PACKAGE__->has_many(authors     => 'MeritCommons::Model::Stream::Author');
__PACKAGE__->has_many(subscribers => 'MeritCommons::Model::Stream::Subscriber', 'stream');
__PACKAGE__->has_many(moderators  => 'MeritCommons::Model::Stream::Moderator', 'stream');

__PACKAGE__->might_have(personal_inbox_user     => 'MeritCommons::Model::User', 'personal_inbox');
__PACKAGE__->might_have(notification_inbox_user => 'MeritCommons::Model::User', 'notification_inbox');
__PACKAGE__->might_have(personal_outbox_user    => 'MeritCommons::Model::User', 'personal_outbox');

# invites
__PACKAGE__->has_many(invites => 'MeritCommons::Model::Stream::Invite', 'stream');
__PACKAGE__->many_to_many(invitees => 'invites', 'invitee');
__PACKAGE__->many_to_many(inviters => 'invites', 'inviter');

# who's watching me?
__PACKAGE__->has_many(watched => 'MeritCommons::Model::Stream::Watcher', { 'foreign.target' => 'self.unique_id' });
__PACKAGE__->many_to_many(watchers => 'watched', 'watcher');

__PACKAGE__->has_many(message_streams => 'MeritCommons::Model::Stream::MessageStream', 'stream');
__PACKAGE__->many_to_many(messages => 'message_streams', 'message');

# changelog
__PACKAGE__->has_many(
    changes => 'MeritCommons::Model::Stream::ChangeLog',
    'stream', { cascade_delete => 0, is_foreign_key_constraint => 0 }
);

# the uuids must be unique, or else.
__PACKAGE__->add_unique_constraint(['unique_id']);
__PACKAGE__->add_unique_constraint(['url_name']);
__PACKAGE__->add_unique_constraint(['external_unique_id']);

# Attachment configuration
__PACKAGE__->has_attachment('background_image', {});

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

# returns a hashref copy.
sub as_hashref {
    my %hash = (%{ shift->{_column_data} });
    return \%hash;
}

# search for entities that are both authors and subscribers
sub members {
    my ($self) = @_;
    return $self->result_source->schema->resultset('Stream::Subscriber')->search(
        {
            'me.meritcommons_user' => {
                -in => $self->authors->get_column('meritcommons_user')->as_query,
            },
            'me.stream' => $self->id,
        },
        { prefetch => ['meritcommons_user'] }
    );
}

sub get_authed_subscribers {
    my ($self) = @_;

    if ($self->requires_subscriber_authorization) {
        my @authed;
        foreach my $sub ($self->subscribers) {
            push @authed, $sub if $sub->authorized;
        }
        return @authed;
    } else {
        return $self->subscribers;
    }
}

sub get_authed_authors {
    my ($self) = @_;

    if ($self->requires_author_authorization) {
        my @authed;
        foreach my $author ($self->authors) {
            push @authed, $author if $author->authorized;
        }
        return @authed;
    } else {
        return $self->authors;
    }
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
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'url_name_idx',
        fields => ['url_name'],
    );

    $sqlt_table->add_index(
        name   => 'personal_inbox_user_idx',
        fields => ['personal_inbox_user'],
    );

    $sqlt_table->add_index(
        name   => 'personal_outbox_user_idx',
        fields => ['personal_outbox_user'],
    );

    $sqlt_table->add_index(
        name   => 'notification_inbox_user_idx',
        fields => ['notification_inbox_user'],
    );

    $sqlt_table->add_index(
        name   => 'url_name_type_idx',
        fields => [ 'url_name', 'type' ],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_stream_external_unique_id_idx',
        fields => ['external_unique_id'],
    );
}

#sub description_html {
#    my ($self) = @_;
#    my $desc = $self->app->htmlstrip($self->description);
#    return markdown($desc);
#}

1;
