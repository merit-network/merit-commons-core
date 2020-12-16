#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::Identity;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_identity');

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
    multiplier => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => '0',
    },
    identity => {
        data_type => 'varchar',
        size      => 64,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(identityusers => 'MeritCommons::Model::User::IdentityUser', 'identity');
__PACKAGE__->many_to_many(users => 'identityusers', 'user');
__PACKAGE__->has_many(clicks => 'MeritCommons::Model::Link::Click');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(
        name   => 'user_identity_string_idx',
        fields => ['identity'],
    );
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
