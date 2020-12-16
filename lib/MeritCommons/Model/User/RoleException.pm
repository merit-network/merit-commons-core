#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::RoleException;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_role_exception');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_numeric        => 1,
    },
    meritcommons_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    role => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(role           => 'MeritCommons::Model::User::Role');
__PACKAGE__->add_unique_constraint(role_exception => [qw/meritcommons_user role/]);

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

# do this extra stuff on update
sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

1;
