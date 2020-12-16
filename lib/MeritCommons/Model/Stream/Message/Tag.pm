#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Message::Tag;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/+DBIx::ClassAttachment PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_message_tag');

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
    meritcommons_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    tag => {
        data_type => 'varchar',
        size      => 255,
    },
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
);

# set the primary key, baby
__PACKAGE__->set_primary_key('id');

# encapsulating message and author
__PACKAGE__->belongs_to(message        => 'MeritCommons::Model::Stream::Message');
__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');

sub insert {
    my ($self, @args) = @_;

    $self->modify_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    # index on both.  do it for the kids.
    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_tag_message_user_idx',
        fields => [ 'message', 'meritcommons_user' ],
    );
}
