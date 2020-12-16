#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Profile::StandardAttribute;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_profile_standard_attribute');

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
    is_default => {
        data_type  => 'integer',
        is_boolean => 1,
    },
    k => {
        data_type => 'varchar',
        size      => 255,
    },
    type => {
        data_type => 'varchar',
        size      => 1,
    },
    label => {
        data_type => 'varchar',
        size      => 255,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(user_profile_attributes => 'MeritCommons::Model::User::Profile::Attribute', 'standard_attribute');

# redirect!
sub key {
    $_[0]->k(@_[ 1 .. $#_ ]);
}

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
