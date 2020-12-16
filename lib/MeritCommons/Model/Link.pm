#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Link;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_link');

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
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    creator => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    icon_class => {
        data_type   => 'text',
        is_nullable => 1,
    },
    href => {
        data_type => 'text',
    },
    title => {
        data_type => 'text',
    },
    short_loc => {
        data_type => 'varchar',
        size      => 64,
    },
    keywords => {
        data_type   => 'text',
        is_nullable => 1,
    },
    target => {
        data_type     => 'varchar',
        default_value => '_blank',
    },
    type => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/user system unspecified/],
        },
        is_nullable => 1,
    },
    role_policy => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/any all none/],
        },
        default_value => 'any',
    },
);

__PACKAGE__->set_primary_key('id');

# link collections are lil bundles of joy.
__PACKAGE__->has_many(
    collection_members => 'MeritCommons::Model::Link::Collection::Member',
    'link'
);
__PACKAGE__->many_to_many(collections => 'collection_members', 'collection');

# links are used in many messages.
__PACKAGE__->has_many(
    message_links => 'MeritCommons::Model::Stream::MessageLink',
    'link'
);
__PACKAGE__->many_to_many(messages => 'message_links', 'message');

# links are clicked on.  many times if they're any good.
__PACKAGE__->has_many(clicks => 'MeritCommons::Model::Link::Click');
__PACKAGE__->belongs_to(creator => 'MeritCommons::Model::User');

# links have many roles
__PACKAGE__->has_many(link_roles => 'MeritCommons::Model::Link::Role', 'link');
__PACKAGE__->many_to_many(roles => 'link_roles', 'role');

__PACKAGE__->add_unique_constraint(shortened_location => [qw/short_loc/]);

my @sc = (1 .. 9, "a" .. "z");

sub add_role {
    my ($self, $role) = @_;
    foreach my $r ($self->roles) {
        if ($role->id eq $r->id) {
            return undef;
        }
    }
    $self->link_roles->create({ role => $role->id });
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
    foreach my $cr ($self->link_roles) {
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
    $self->short_loc($self->_next_short_loc);
    $self->next::method(@args);
}

sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

sub _next_short_loc {
    my ($self) = @_;

    # get the most recent short code!
    my $last_link =
      $self->result_source->schema->resultset('Link')->search({}, { order_by => { -desc => 'id' } })->first;
    if ($last_link) {
        my @lsl = split(//, reverse($last_link->short_loc));

        for (my $i = 0 ; $i < scalar(@lsl) ; $i++) {
            my $char = $lsl[$i];
            my $char_idx;

            # getting idx my own way, eff grep.
            for (my $ii = 0 ; $i < scalar(@sc) ; $ii++) {
                if ($sc[$ii] eq $char) {
                    $char_idx = $ii;
                    last;
                }
            }

            if ($char_idx == $#sc) {
                $lsl[$i] = $sc[0];
            } else {
                $lsl[$i] = $sc[ $char_idx + 1 ];
                last;
            }
        }

        my $next_code = reverse(join('', @lsl));

        if ($next_code =~ /^1+$/) {
            $next_code = "1" . $next_code;
        }

        return $next_code;
    } else {
        return $sc[0];
    }
}

sub relative_short {
    my ($self) = @_;
    return "/link/" . $self->short_loc;
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'short_loc_idx',
        fields => ['short_loc'],
    );
}
