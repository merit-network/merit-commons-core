#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Session::Keystore;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_session_keystore');
__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
    },
    session => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    k => {
        data_type => 'varchar',
        size      => '255',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(session => 'MeritCommons::Model::Session');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}

1;
