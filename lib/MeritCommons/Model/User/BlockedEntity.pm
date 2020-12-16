#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::BlockedEntity;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_blockedentity');

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
    meritcommons_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    entity_type => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/user stream message/],
        },
    },
    entity_id => {
        data_type => 'varchar',
        size      => 64,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');
__PACKAGE__->add_unique_constraint([qw/meritcommons_user entity_id/]);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'entity_id_idx',
        fields => ['entity_id'],
    );
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

1;
