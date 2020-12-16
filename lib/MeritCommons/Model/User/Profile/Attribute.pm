package MeritCommons::Model::User::Profile::Attribute;

use base qw/DBIx::Class/;
use Carp qw(croak);
use Data::Dumper;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_profile_attribute');

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
    standard_attribute => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
    user_attribute => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    type => {
        data_type => 'varchar',
        size      => 1,
    },
    attr_group => {
        data_type => 'varchar',
        size      => 255,
    },
    label => {
        data_type => 'varchar',
        size      => 255,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(user_attribute     => 'MeritCommons::Model::User::Attribute');
__PACKAGE__->belongs_to(standard_attribute => 'MeritCommons::Model::Profile::StandardAttribute');
__PACKAGE__->has_many(vals => 'MeritCommons::Model::User::Profile::Attribute::Value', 'profile_attribute');

sub delimited_values {
    my ($self) = @_;

    my @values = map { $_->user_attribute_value->v } $self->vals;

    return join(', ', @values);
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
