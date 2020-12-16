#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Link::Role;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_link_role');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    role => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
    link => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(role => 'MeritCommons::Model::User::Role');
__PACKAGE__->belongs_to(link => 'MeritCommons::Model::Link');

__PACKAGE__->add_unique_constraint(link_roles => [qw/role link/]);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}
