#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Link::Click;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_link_click');

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
    identity => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    link => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
    counter => {
        data_type  => 'integer',
        is_numeric => 1,
    },
);

__PACKAGE__->set_primary_key('id');

# recursive, they can include each other
__PACKAGE__->belongs_to(link     => 'MeritCommons::Model::Link');
__PACKAGE__->belongs_to(identity => 'MeritCommons::Model::User::Identity');

sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'user_identity_idx',
        fields => ['identity'],
    );
}
