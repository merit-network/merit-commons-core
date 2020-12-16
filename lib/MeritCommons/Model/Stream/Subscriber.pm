#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Subscriber;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_subscriber');

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
    authorized => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 0,
    },
    allow_history => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 1,
    },
    added_by => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(stream         => 'MeritCommons::Model::Stream');
__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(added_by       => 'MeritCommons::Model::User');

# good to enforce this here!
__PACKAGE__->add_unique_constraint(subscription => [qw/meritcommons_user stream/]);

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);

    # do the insert
    $self = $self->next::method(@args);

    # update the subscriber count
    my $stream = $self->stream;
    $stream->subscriber_count($stream->subscribers->count);
    $stream->update;

    return $self;
}

sub delete {
    my ($self, @args) = @_;
    my $stream = $self->stream;
    $self = $self->next::method(@args);
    $stream->subscriber_count($stream->subscribers->count);
    $stream->update;

    return $self;
}

# do this extra stuff on update
sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
    $sqlt_table->add_index(
        name   => 'authorized_idx',
        fields => ['authorized'],
    );
    $sqlt_table->add_index(
        name   => 'added_by_idx',
        fields => ['added_by'],
    );
    $sqlt_table->add_index(
        name   => 'user_idx',
        fields => ['meritcommons_user'],
    );
    $sqlt_table->add_index(
        name   => 'stream_idx',
        fields => ['stream'],
    );

}

1;
