#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::File::Variant;
use base qw/DBIx::Class/;
use Mojo::Asset::File;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_file_variant');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        is_nullable       => 0,
    },
    common_name => {
        data_type     => 'varchar',
        size          => 255,
        is_nullable   => 0,
        default_value => 'original',
    },
    storage_type => {
        data_type     => 'varchar',
        size          => 255,
        is_nullable   => 0,
        default_value => 'default',
    },
    size => {
        data_type     => 'integer',
        is_nullable   => 0,
        default_value => 0,
    },
    url => {
        data_type   => 'text',
        is_nullable => 0,
    },
    path => {
        data_type   => 'text',
        is_nullable => 0,
    },
    file => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 0,
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
);

# our humble primary key
__PACKAGE__->set_primary_key('id');

# only one relationship, who initiated the change.
__PACKAGE__->belongs_to(file => 'MeritCommons::Model::File');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'file_variant_create_time_idx',
        fields => ['create_time'],
    );
}

sub asset {
    my ($self) = @_;
    return Mojo::Asset::File->new(path => $self->path);
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

# remove files associated with this variant, too
sub delete {
    my ($self, @args) = @_;
    if ($self->path && -e $self->path) {
        unlink($self->path);
    }
    $self->next::method(@args);
}

1;
