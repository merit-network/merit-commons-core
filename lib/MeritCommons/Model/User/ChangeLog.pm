#    MeritCommons Portal
#    Copyright 2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::ChangeLog;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_changelog');

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
    meritcommons_user => {
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
    meritcommons_user => 'MeritCommons::Model::User',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'user_changelog_undo_id_idx',
        fields => ['undo_id'],
    );

    $sqlt_table->add_index(
        name   => 'user_changelog_create_time_idx',
        fields => ['create_time'],
    );

    $sqlt_table->add_index(
        name   => 'user_changelog_meritcommons_user_idx',
        fields => ['meritcommons_user'],
    );
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

1;
