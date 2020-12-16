#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::User::MeritCommonscoinTransaction;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_user_meritcommonscointransaction');
__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    create_time => {
        data_type => 'integer',
    },
    previous_balance => {
        data_type  => 'real',
        is_numeric => 1,
    },
    resulting_balance => {
        data_type  => 'real',
        is_numeric => 1,
    },
    amount => {
        data_type  => 'real',
        is_numeric => 1,
    },
    transaction_type => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/credit exchange spend/],
        },
    },
    role => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/buyer sender seller receiver creditor/],
        },
    },
    transaction_id => {
        data_type     => 'varchar',
        size          => 64,
        default_value => '00000000-0000-0000-DEAD-BEEFDEADBEEF',
    },
    meritcommons_user => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    related_transaction => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_nullable    => 1,
        is_foreign_key => 1,
    },
    second_party => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(
    meritcommons_user => 'MeritCommons::Model::User',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);
__PACKAGE__->belongs_to(
    second_party => 'MeritCommons::Model::User',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);
__PACKAGE__->belongs_to(
    related_transaction => 'MeritCommons::Model::User::MeritCommonscoinTransaction',
    undef, { cascade_delete => 0, is_foreign_key_constraint => 0 }
);

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'txn_type_idx',
        fields => ['transaction_type'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommonscoin_transaction_user_idx',
        fields => ['meritcommons_user'],
    );

    $sqlt_table->add_index(
        name   => 'txn_id_idx',
        fields => ['transaction_id'],
    );
}

1;
