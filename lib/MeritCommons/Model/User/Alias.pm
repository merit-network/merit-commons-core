#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::Alias;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_alias');
__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
    },
    meritcommons_user => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    owner => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    used => {
        data_type     => 'integer',
        default_value => 0,
    },
    common_name => {
        data_type => 'varchar',
        size      => 255,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(owner          => 'MeritCommons::Model::User');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'user_alias_common_name_idx',
        fields => ['common_name'],
    );
}

1;
