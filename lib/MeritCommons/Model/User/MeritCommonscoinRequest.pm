package MeritCommons::Model::User::MeritCommonscoinRequest;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_meritcommonscoinrequest');
__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    create_time => {
        data_type => 'integer',
    },
    modify_time => {
        data_type => 'integer',
    },
    amount_requested => {
        data_type  => 'real',
        is_numeric => 1,
    },
    reason => {
        data_type => 'text',
    },
    approved => {
        data_type     => 'integer',
        default_value => 0,
    },
    updated_by => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    requested_by => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(requested_by => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(updated_by   => 'MeritCommons::Model::User');

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self->next::method(@args);
}

sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

1;
