#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Message::Watcher;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_message_watcher');
__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
    },
    target => {
        data_type      => 'varchar',
        size           => 64,
        is_foreign_key => 1,
    },
    watcher => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
    create_time => {
        data_type => 'integer',
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(target => 'MeritCommons::Model::Stream::Message', { 'foreign.unique_id' => 'self.target' });
__PACKAGE__->belongs_to(watcher => 'MeritCommons::Model::User');
__PACKAGE__->add_unique_constraint([qw/target watcher/]);

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}

1;
