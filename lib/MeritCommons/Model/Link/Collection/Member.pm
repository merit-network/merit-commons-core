#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Link::Collection::Member;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_link_collection_member');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    link => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
    collection => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(link       => 'MeritCommons::Model::Link');
__PACKAGE__->belongs_to(collection => 'MeritCommons::Model::Link::Collection');

__PACKAGE__->add_unique_constraint(link_collection_membership => [qw/link collection/]);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}
