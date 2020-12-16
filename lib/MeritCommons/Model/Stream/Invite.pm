#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Invite;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_invite');
__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
    },
    inviter => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    invitee => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    stream => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    approved => {
        data_type     => 'integer',
        default_value => 0,
    },
    create_time => {
        data_type => 'integer',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(inviter => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(invitee => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(stream  => 'MeritCommons::Model::Stream');

__PACKAGE__->add_unique_constraint([qw/inviter invitee stream/]);

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}
