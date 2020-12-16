#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Message::Gizmo;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_message_gizmo');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        size              => 18,
    },
    gizmo_code => {
        data_type => 'text',
    },
    message => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        size           => 18,
    },
    author => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
);

# set the primary key, baby
__PACKAGE__->set_primary_key('id');

# encapsulating message and author
__PACKAGE__->belongs_to(message => 'MeritCommons::Model::Stream::Message');
__PACKAGE__->belongs_to(author  => 'MeritCommons::Model::User');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}
