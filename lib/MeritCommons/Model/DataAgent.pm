#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::DataAgent;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_dataagent');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    enc_pub_key => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    sign_pub_key => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    common_name => {
        data_type => 'varchar',
        size      => 255,
    },
    unique_id => {
        data_type => 'varchar',
        size      => 64,
    },
    source_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foregin_key => 1,
        is_nullable    => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->might_have(source_user => 'MeritCommons::Model::User');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'meritcommons_dataagent_uuid_idx',
        fields => ['unique_id'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_dataagent_cn_idx',
        fields => ['common_name'],
    );
}

sub user {
    shift->meritcommons_user(@_);
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

sub DESTROY {
    return;
}

1;
