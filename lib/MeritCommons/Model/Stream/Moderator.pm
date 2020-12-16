#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Moderator;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_moderator');

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
    meritcommons_user => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
    stream => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
    allow_add_moderator => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    added_by => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(stream         => 'MeritCommons::Model::Stream');
__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(added_by       => 'MeritCommons::Model::User');

# good to enforce this here!
__PACKAGE__->add_unique_constraint(moderatorship => [qw/meritcommons_user stream/]);

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self = $self->next::method(@args);
    my $stream = $self->stream;
    $stream->moderator_count($stream->moderators->count);
    $stream->update;
    return $self;
}

sub delete {
    my ($self, @args) = @_;
    my $stream = $self->stream;
    $self = $self->next::method(@args);
    $stream->moderator_count($stream->moderators->count);
    $stream->update;
}

# do this extra stuff on update
sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}

1;
