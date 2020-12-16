#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::Role;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_role');

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
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    common_name => {
        data_type => 'varchar',
        size      => 255,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(roleusers => 'MeritCommons::Model::User::RoleUser', 'role');
__PACKAGE__->many_to_many(users => 'roleusers', 'meritcommons_user');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self->next::method(@args);
}

1;
