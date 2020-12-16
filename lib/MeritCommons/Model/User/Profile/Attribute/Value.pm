package MeritCommons::Model::User::Profile::Attribute::Value;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_profile_attribute_value');

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
    profile_attribute => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    user_attribute_value => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    ordinal => {
        data_type  => 'integer',
        is_numeric => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(profile_attribute    => 'MeritCommons::Model::User::Profile::Attribute');
__PACKAGE__->belongs_to(user_attribute_value => 'MeritCommons::Model::User::Attribute::Value');

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
