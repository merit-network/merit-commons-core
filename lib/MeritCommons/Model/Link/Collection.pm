#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Link::Collection;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_link_collection');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    common_name => {
        data_type => 'varchar',
        size      => 255,
    },
    icon_class => {
        data_type   => 'text',
        is_nullable => 1,
    },
    creator => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    parent => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
    }
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->add_unique_constraint(link_collection_hierarchy => [qw/id parent/]);

# recursive, they can include each other
__PACKAGE__->has_many(collections        => 'MeritCommons::Model::Link::Collection',         'parent');
__PACKAGE__->has_many(collection_members => 'MeritCommons::Model::Link::Collection::Member', 'collection');
__PACKAGE__->has_many(collection_roles   => 'MeritCommons::Model::Link::Collection::Role',   'collection');

__PACKAGE__->belongs_to(creator => 'MeritCommons::Model::User');
__PACKAGE__->belongs_to(parent  => 'MeritCommons::Model::Link::Collection');
__PACKAGE__->many_to_many(links => 'collection_members', 'link');
__PACKAGE__->many_to_many(roles => 'collection_roles',   'role');

# for consistency with links..
sub title {
    my ($self, @args) = @_;
    $self->common_name(@args);
}

sub add_role {
    my ($self, $role) = @_;
    foreach my $r ($self->roles) {
        if ($role->id eq $r->id) {
            return undef;
        }
    }
    $self->collection_roles->create({ role => $role->id });
}

sub has_role {
    my ($self, $role) = @_;
    foreach my $r ($self->roles) {
        if ($role->id eq $r->id) {
            return 1;
        }
    }
    return undef;
}

sub remove_role {
    my ($self, $role) = @_;
    foreach my $cr ($self->collection_roles) {
        if ($cr->role->id eq $role->id) {
            return $cr->delete;
        }
    }
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self->next::method(@args);
}

sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

sub delete {
    my ($self, @args) = @_;
    if ($self->common_name eq "_top") {
        die "[error] _top cannot be deleted\n";
    } else {
        $self->next::method(@args);
    }
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}
