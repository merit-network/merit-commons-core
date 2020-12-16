#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Session;

use Mojo::Collection;
use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_session');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    created_from => {
        data_type => 'varchar',
        size      => 255,
    },
    heartbeat_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 1,
    },
    heartbeat_from => {
        data_type => 'varchar',
        size      => 255,
    },
    expire_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    session_length => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    session_id => {
        is_nullable => 1,
        data_type   => 'varchar',
        size        => 255,
    },
    meritcommons_user => {
        data_type      => 'integer',
        is_foreign_key => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');
__PACKAGE__->might_have(key => 'MeritCommons::Model::Session::Keystore', 'session');
__PACKAGE__->has_many(attributes => 'MeritCommons::Model::Session::Attribute');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}

sub user {
    shift->meritcommons_user(@_);
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->heartbeat_time(time);
    $self->expire_time($self->heartbeat_time + $self->session_length);
    $self->next::method(@args);
}

# do this extra stuff on update
sub update {
    my ($self, @args) = @_;
    $self->next::method(@args);
}

sub is_expired {
    my ($self) = @_;
    if ($self->expire_time < time) {
        return 1;
    }

    return undef;
}

sub DESTROY {
    return;
}

sub first_attribute_value {
    my ($self, $name) = @_;
    my $attr = $self->$name;
    if ($attr) {
        return $attr->first;
    }
    return undef;
}

sub last_attribute_value {
    my ($self, $name) = @_;
    my $attr = $self->$name;
    if ($attr) {
        return $attr->last;
    }
    return undef;
}

# the autoloader.  is here.  scary.
sub AUTOLOAD {
    my ($self, @values) = @_;
    our $AUTOLOAD;
    my $name = $AUTOLOAD;
    $name =~ s/.*:://g;
    my $attribute;

    if (ref($values[0]) eq "Mojo::Collection") {
        @values = @{$values[0]};
    }

    if ($self->attributes) {
        $attribute = $self->attributes->search(
            {
                k => $name,
            }
        )->first;
    }

    if ($attribute) {
        if (scalar(@values)) {
            if ($values[0] eq "__clear__") {
                $attribute->delete;
                return Mojo::Collection->new(undef);
            } else {
                # set all the new values!
                $attribute->vals->delete_all;
                foreach my $value (@values) {
                    $attribute->vals->create(
                        {
                            v => $value,
                        }
                    );
                }
            }
        }

        # "__clear__" is not a legal value for an attribute, if we find it in the database, we remove the attribute.
        foreach my $v ($attribute->vals) {
            if ($v->v eq "__clear__") {
                $attribute->delete;
                return Mojo::Collection->new(undef);
            }
        }

        if (defined $attribute->vals->first) {
            return Mojo::Collection->new(map { $_->v } $attribute->vals);
        } 
    } else {
        if (scalar(@values) && $values[0] ne "__clear__") {
            my $attr = $self->attributes->create(
                {
                    k => $name,
                }
            );
            
            foreach my $value (@values) {
                $attr->vals->create(
                    {
                        v => $value,
                    }
                );
            }
            return Mojo::Collection->new(map { $_->v } $attr->vals);
        }
    }
    
    return Mojo::Collection->new(undef);
}

1;
