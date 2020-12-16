#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::MessageLink;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_messagelink');

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
    link => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
);

# set the primary key, baby
__PACKAGE__->set_primary_key('id');

# encapsulating message and author
__PACKAGE__->belongs_to(message => 'MeritCommons::Model::Stream::Message');
__PACKAGE__->belongs_to(link    => 'MeritCommons::Model::Link');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'messagelink_link_idx',
        fields => ['link'],
    );

    $sqlt_table->add_index(
        name   => 'messagelink_message_idx',
        fields => ['message'],
    );
}

1;
