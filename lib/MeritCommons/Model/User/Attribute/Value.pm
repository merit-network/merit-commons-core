#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::Attribute::Value;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_attribute_value');
__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
    },
    attribute => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    v => {
        data_type => 'text',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(attribute => 'MeritCommons::Model::User::Attribute');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'user_attribute_idx',
        fields => ['attribute'],
    );
}

1;
