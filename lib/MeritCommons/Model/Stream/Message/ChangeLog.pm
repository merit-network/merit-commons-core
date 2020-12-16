#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Message::ChangeLog;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_message_changelog');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        is_nullable       => 0,
    },
    actor => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    create_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 0,
    },

    # uuid of the entity changed (user, stream, message, whatever)
    message => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },

    # uuid of the undo action; log entries without undo_ids are not "undo-able"
    undo_id => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },

    # enough data to make the system the way it was before this event happened
    undo_data => {
        data_type   => 'text',
        is_nullable => 1,
    },
    description => {
        data_type   => 'text',
        is_nullable => 1,
    },
    title => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
);

# only one relationship, who initiated the change.
__PACKAGE__->belongs_to(
    actor => 'MeritCommons::Model::User',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);
__PACKAGE__->belongs_to(
    message => 'MeritCommons::Model::Stream::Message',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'stream_message_changelog_undo_id_idx',
        fields => ['undo_id'],
    );

    $sqlt_table->add_index(
        name   => 'stream_message_changelog_create_time_idx',
        fields => ['create_time'],
    );

    $sqlt_table->add_index(
        name   => 'stream_message_changelog_message_idx',
        fields => ['message'],
    );
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

1;
