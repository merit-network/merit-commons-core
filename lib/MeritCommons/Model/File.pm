#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::File;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_file');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        is_nullable       => 0,
    },
    mime_type => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 0,
    },
    unique_id => {
        data_type => 'varchar',
        size      => 64,
    },
    create_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 0,
    },
    modify_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 0,
    },
    uploader => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
);

# our humble primary key
__PACKAGE__->set_primary_key('id');

# only one relationship, who initiated the change.
__PACKAGE__->has_many(variants => 'MeritCommons::Model::File::Variant', 'file', { cascade_delete => 0 });
__PACKAGE__->belongs_to(uploader => 'MeritCommons::Model::User');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'file_create_time_idx',
        fields => ['create_time'],
    );
    $sqlt_table->add_index(
        name   => 'file_unique_id_idx',
        fields => ['unique_id'],
    );
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self->next::method(@args);
}

# do this extra stuff on insert
sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

# manually cascade deletes.
sub delete {
    my ($self, @args) = @_;
    foreach my $v ($self->variants) {
        $v->delete;
    }
    $self->next::method(@args);
}

sub url {
    my ($self, $variant) = @_;
    $variant ||= "original";
    my $v = $self->variants->single({ common_name => $variant });
    if ($v) {
        return $v->url;
    }
    return undef;
}

sub path {
    my ($self, $variant) = @_;
    $variant ||= "original";
    my $v = $self->variants->single({ common_name => $variant });
    if ($v) {
        return $v->path;
    }
    return undef;
}

sub variant {
    my ($self, $variant) = @_;
    $variant ||= "original";
    my $v = $self->variants->single({ common_name => $variant });
    if ($v) {
        return $v->url;
    }
    return undef;
}

1;
