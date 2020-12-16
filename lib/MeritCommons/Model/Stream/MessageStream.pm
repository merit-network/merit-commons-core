#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::MessageStream;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_messagestream');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        size              => 18,
    },
    message => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        size           => 18,
    },
    stream => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    create_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 1,
    },
);

# set the primary key, baby
__PACKAGE__->set_primary_key('id');

# encapsulating message and author
__PACKAGE__->belongs_to(message => 'MeritCommons::Model::Stream::Message');
__PACKAGE__->belongs_to(stream  => 'MeritCommons::Model::Stream');

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'create_time_idx',
        fields => ['create_time'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_stream_messagestream_idx_stream',
        fields => ['stream'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_stream_messagestream_idx_message',
        fields => ['message'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_stream_messagestream_idx_stream_message',
        fields => [ 'message', 'stream' ],
    );
}
