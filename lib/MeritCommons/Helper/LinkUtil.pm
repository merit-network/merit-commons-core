#    MeritCommons Portal
#    Copyright 2013-2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::LinkUtil;
use Mojo::Base 'Mojolicious::Plugin';
use MIME::Base64 qw/encode_base64url decode_base64url/;
use Crypt::Digest qw/digest_data/;
use Mojo::URL;
use File::Basename qw/fileparse/;
use Carp qw/croak/;

sub register {
    my ($self, $app) = @_;

    # install local subroutine as a helper.
    $app->helper(add_link                    => \&_add_link);
    $app->helper(add_link_collection         => \&_add_link_collection);
    $app->helper(add_link_to_collection      => \&_add_link_to_collection);
    $app->helper(delete_link                 => \&_delete_link);
    $app->helper(remove_link_from_collection => \&_remove_link_from_collection);
    $app->helper(link                        => \&_link);
    $app->helper(link_ro                     => \&_link_ro);
    $app->helper(link_collection             => \&_link_collection);
    $app->helper(link_as_mojo_url            => \&_link_as_mojo_url);
    $app->helper(link_by_short_loc           => \&_link_by_short_loc);
    $app->helper(link_by_short_loc_ro        => \&_link_by_short_loc_ro);
    $app->helper(nav_tree                    => \&_nav_tree);
    $app->helper(generate_nav_tree           => \&_generate_nav_tree);             # cache-ignorant
    $app->helper(nav_tree_json               => \&_nav_tree_json);
    $app->helper(short_url                   => \&_short_url);
    $app->helper(most_clicked_links          => \&_most_clicked_links);
    $app->helper(proxy_href                  => \&_proxy_href);
}

sub _proxy_href {
    my ($c, $href) = @_;

    unless (ref($href) eq "Mojo::URL") {
        $href = Mojo::URL->new($href);
    }

    # get some config options...
    my $secret = $c->app->global_config->{ssl_asset_proxy_secret};
    my $wl     = $c->app->global_config->{ssl_asset_proxy_types};

    if ($secret && $wl) {
        my ($suffix) = $href->path_query =~ /\.(\w+)$/;

        # figure out if we should be proxying by making sure the mime type is on the whitelist...
        if ($suffix && $wl->{ lc($suffix) }) {
            my $proxy_hash = encode_base64url(digest_data('SHA256', $href->to_string . $secret));
            my $proxy_filename = encode_base64url($href->to_string) . lc(".$suffix");
            return $c->url_for("/asset_proxy/$proxy_hash/$proxy_filename");
        }
    }

    return $href;
}

# returns the short code of a link (always tries to use replica)
sub _short_url {
    my ($controller, $self, $link) = @_;
    $link = $self->app->link($link, $controller->replica) unless ref $link;
    if ($link) {
        my $short_url = $controller->app->global_config->{front_door_url};
        $short_url .= "/link/" . $link->short_loc;
        return $short_url;
    }
    return undef;
}

sub _most_clicked_links {
    my ($self, $lim) = @_;
    my $session     = $self->meritcommons_session;
    my $active_user = $self->active_user;
    return undef unless $session && $active_user;
    my $self_identity = $active_user->identities->search({}, { order_by => { -desc => 'multiplier' } })->first;

    if (my $mc_links = $self->cache->get('mc_links:' . $session->session_id . ":$lim")) {
        warn "[navcache]: frequent links cache HIT!\n" if $ENV{MERITCOMMONS_DEBUG};
        return @$mc_links;
    } else {
        my @mc_links = $active_user->most_clicked_links($lim);
        $self->cache->set('mc_links:' . $session->session_id . ":$lim", \@mc_links, 21600);
        return @mc_links;
    }
}

# handle caching here
sub _nav_tree {
    my ($controller, $collection) = @_;

    my $cache_string = __cache_string($controller);

    my $reload_cache;
    if ($reload_cache = $controller->meritcommons_session->nav_tree_reload_cache->first) {
        $controller->meritcommons_session->nav_tree_reload_cache('__clear__');
    }

    if ($collection) {
        $cache_string .= "-" . (ref $collection eq "HASH" ? $collection->{id} : $collection->id);
    }

    if (!$reload_cache) {
        if (my $nav_tree = $controller->cache->get($cache_string)) {
            if ($ENV{MERITCOMMONS_DEBUG}) {
                print "[navcache]: nav_tree cache HIT!\n";
            }
            return $nav_tree;
        }
    }
    
    if ($ENV{MERITCOMMONS_DEBUG}) {
        if ($reload_cache) {
            print "[navcache]: nav_tree session FORCE RELOAD\n";
        } else {
            print "[navcache]: nav_tree cache MISS!\n";
        }
    }
    
    my $nav_tree = $controller->generate_nav_tree($collection);
    $controller->cache->set($cache_string, $nav_tree, 21600);
    return $nav_tree;
}

sub __cache_string {
    my ($controller, $suffix) = @_;
    $suffix = "nav_tree" unless $suffix;
    my $cache_string;
    if (my $user = $controller->active_user) {
        if ($user->is_admin) {
            $cache_string = "admin-$suffix";
        } else {
            $cache_string =
              join('-', map { $_->common_name } sort { $a->common_name cmp $b->common_name } $user->roles) . "-$suffix";
        }
        if (scalar($user->config('links-in-same-window'))) {
            $cache_string .= "-lsw";
        }
    } else {
        $cache_string = "$suffix";
    }
    if ($ENV{MERITCOMMONS_DEBUG}) {
        print "[navcache]: cache string is $cache_string\n";
    }
    return $cache_string;
}

sub _generate_nav_tree {
    my ($controller, $collection) = @_;

    my $user = $controller->active_user;

    my @user_roles;
    if ($user) {
        @user_roles = map { $_->id } $user->roles;
    }

    # only evaluate once
    my $is_admin = $user->is_admin;

    my @collections = $controller->app->rorm->resultset('Link::Collection')->search(
        {
            # ensure that associated links are system, but still include collections that have no links (undef)
            -or => [
                'link.type' => 'system',
                'link.id'   => undef
            ]
        },
        {
            prefetch => {
                'collection_members' => { 'link' => 'link_roles' },
            },
            order_by     => { -asc => 'me.common_name, link.title' },
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    )->all;

    # loop through links and collections and identifies those that are relevent to the user
    my @required_collection_ids;
    my @required_link_ids;

    foreach my $collection (@collections) {
        foreach my $member (@{ $collection->{collection_members} }) {
            my $link         = $member->{link};
            my $include_link = 0;

            # if the user is an admin, always include it
            if ($is_admin) {
                $include_link = 1;
            }

            # if a link has no associated roles, always include it
            if (scalar(@{ $link->{link_roles} }) == 0) {
                $include_link = 1;
            }

            # check if the user has one of the link roles
            foreach my $link_role (@{ $link->{link_roles} }) {
                my $role_id = $link_role->{role};

                # check if the link is relevent to the user
                if (grep $_ == $role_id, @user_roles) {
                    $include_link = 1;
                }
            }

            # keep track of links that are relevent to the user
            if ($include_link) {
                push(@required_link_ids, $link->{id});

                # link is relevent. ensure that the collection and its dependent collections are identified as being relevent to the user
                my $collection_dependencies =
                  __identify_collection_dependencies(\@collections, [ $collection->{id} ], $collection);

                # add the dependencies to the complete list of collections required for the user, if it's not already identified
                foreach my $collection_dependency (@{$collection_dependencies}) {
                    if (!grep $_ == $collection_dependency, @required_collection_ids) {
                        push(@required_collection_ids, $collection_dependency);
                    }
                }
            }
        }
    }

    my $root_collection = $controller->rorm->resultset('Link::Collection')->find(
        {
            common_name => '_top',
        },
        {
            prefetch => {
                'collection_members' => { 'link' => 'link_roles' },
            },
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    );

    my $structure = __generate_nav_tree_node(\@collections, ($collection ? $collection : $root_collection),
        1, \@required_collection_ids, \@required_link_ids, scalar($user->config('links-in-same-window')), ());
    return $structure;
}

sub __generate_nav_tree_node {
    my ($collections, $current_collection, $is_root, $required_collection_ids, $required_link_ids, $lsw) = @_;

    my @children;

    # add child collections
    foreach my $collection (@{$collections}) {

        # check if the collection is at the current level being evaluated, the collection is relevent to the user
        if (
            (
                (!$current_collection && !$collection->{parent}) || ($current_collection &&
                    $collection->{parent} &&
                    ($collection->{parent} == $current_collection->{id}))
            ) &&
            (grep $_ == $collection->{id}, @{$required_collection_ids})
          ) {
            # add child collection
            push(
                @children,
                __generate_nav_tree_node(
                    $collections, $collection, 0, $required_collection_ids, $required_link_ids, $lsw
                )
            );
        }
    }

    # add links
    if ($current_collection) {
        foreach my $member (@{ $current_collection->{collection_members} }) {
            my $link = $member->{link};

            # check if link is relevent to the user
            if (grep $_ == $link->{id}, @{$required_link_ids}) {
                my $link_structure = {
                    link           => 1,
                    id             => $link->{id},
                    title          => $link->{title},
                    target         => $lsw ? "_self" : $link->{target},
                    href           => $link->{href},
                    short_loc      => $link->{short_loc},
                    relative_short => "/link/" . $link->{short_loc},
                    superclick     => "/superclick/" . $link->{short_loc},
                    unsuperclick   => "/unsuperclick/" . $link->{short_loc},
                };

                push(@children, $link_structure);
            }
        }
    }

    # the root node of the structure is an array of links/collections, but another level is represented as a hash with child nodes
    if ($is_root) {

        # root node
        return \@children;
    } else {

        # recursive call
        my $local_structure = {
            collection       => 1,
            id               => $current_collection->{id},
            children         => \@children,
            common_name      => $current_collection->{common_name},
            common_name_abbr => (substr($current_collection->{common_name}, 0, 5) . "...")
        };

        return $local_structure;
    }
}

sub __identify_collection_dependencies {
    my ($collections, $collection_dependencies, $current_collection) = @_;

    # find the prefetched parent collection
    foreach my $collection (@{$collections}) {
        my $parent_id = $current_collection->{parent};
        if (($parent_id) && ($collection->{id} == $parent_id)) {

            # add the parent as a dependencet, and then recursively get the parent's parent
            push(@{$collection_dependencies}, $parent_id);
            $collection_dependencies =
              __identify_collection_dependencies($collections, $collection_dependencies, $collection);
        }
    }

    return $collection_dependencies;
}

# we do it with serialized json!
sub _nav_tree_json {
    my ($controller) = @_;
    my $cache_string = __cache_string($controller, 'nav_tree_json');

    my $reload_cache;
    if ($reload_cache = $controller->meritcommons_session->nav_tree_json_reload_cache->first) {
        $controller->meritcommons_session->nav_tree_json_reload_cache('__clear__');
    }

    unless ($reload_cache) {
        if (my $nav_tree_json = $controller->cache->get($cache_string)) {
            if ($ENV{MERITCOMMONS_DEBUG}) {
                print "[navcache]: nav_tree_json cache HIT!\n";
            }
            return $nav_tree_json;
        } 
    }
    

    if ($ENV{MERITCOMMONS_DEBUG}) {
        if ($reload_cache) {
            print "[navcache]: nav_tree_json session FORCE RELOAD\n";
        } else {
            print "[navcache]: nav_tree_json cache MISS!\n";
        }
    }
    my $nav_tree_json = $controller->json_encode($controller->nav_tree);
    $controller->cache->set($cache_string, $nav_tree_json, 21600);
    return $nav_tree_json;
    
}

# always tries to use replica
sub _link_as_mojo_url {
    my ($controller, $link) = @_;
    $link = $controller->app->link($link, $controller->replica) unless ref $link;
    if ($link) {
        return Mojo::URL->new($link->href);
    }
    return undef;
}

sub _link {
    my ($controller, $string, $model) = @_;

    return undef unless $string;

    unless ($model) {
        if ($controller->can('app')) {
            $model = $controller->app->m;
        } else {
            $model = $controller->m;
        }
    }

    if ($string =~ /^\d+$/) {
        return $model->resultset('Link')->find({ id => $string });
    } else {
        return $model->resultset('Link')->search({ href => $string })->first;
    }
}

sub _link_ro {
    my ($controller, $string) = @_;

    return $controller->link($string, $controller->replica);
}

sub _link_by_short_loc {
    my ($controller, $string, $model) = @_;

    return undef unless $string;

    unless ($model) {
        if ($controller->can('app')) {
            $model = $controller->app->m;
        } else {
            $model = $controller->m;
        }
    }

    return $model->resultset('Link')->find({ short_loc => $string });
}

sub _link_by_short_loc_ro {
    my ($controller, $string) = @_;

    return $controller->link_by_short_loc($string, $controller->replica);
}

sub _link_collection {
    my ($controller, $string, $parent, $model) = @_;

    unless ($model) {
        if ($controller->can('app')) {
            $model = $controller->app->m;
        } else {
            $model = $controller->m;
        }
    }

    # if there's no parent defined, assume _top
    if (!$parent and $string ne '_top') {
        $parent = $controller->app->link_collection('_top');
    }

    if ($string =~ /^\d+$/) {
        return $model->resultset('Link::Collection')->find({ id => $string });
    } else {
        if (ref($parent)) {
            return $model->resultset('Link::Collection')->search({ common_name => $string, parent => $parent->id })
              ->first;
        } else {
            return $model->resultset('Link::Collection')->search({ common_name => $string, parent => undef })->first;
        }
    }
}

sub _link_collection_ro {
    my ($controller, $string, $parent) = @_;

    return $controller->link_collection($string, $parent, $controller->replica);
}

sub _remove_link_from_collection {
    my ($controller, $link, $collection) = @_;
    $link = $controller->app->link($link) unless ref $link;
    $collection = $controller->app->link_collection($collection) unless ref $collection;

    unless ($link) {
        return { error => "Invalid link specified" };
    }

    unless ($collection) {
        return { error => "Invalid collection specified" };
    }

    $controller->cache->set(nav_tree => undef);

    $controller->app->m->resultset('Link::Collection::Member')
      ->find({ link => $link->id, collection => $collection->id })->delete;
}

sub _add_link_to_collection {
    my ($controller, $link, $collection) = @_;
    $link = $controller->app->link($link) unless ref $link;
    $collection = $controller->app->link_collection($collection) unless ref $collection;

    unless ($link) {
        return { error => "Invalid link specified" };
    }

    unless ($collection) {
        return { error => "Invalid collection specified" };
    }

    return $controller->app->m->resultset('Link::Collection::Member')->create(
        {
            link       => $link->id,
            collection => $collection->id,
        }
    );
}

sub _add_link_collection {
    my ($controller, $actor, $collection_name, $parent) = @_;

    unless ($actor) {
        unless ($actor = $controller->active_user) {
            die "Access Denied\n";
        }
    }

    # if there's no parent defined, put the collection under _top
    if (!$parent and $collection_name ne '_top') {
        $parent = $controller->app->link_collection('_top');
    }

    if ($parent && !ref($parent)) {
        $parent = $controller->app->link_collection($parent);
    }

    if (ref($parent)) {
        if (my $exists = $controller->app->m->resultset('Link::Collection')
            ->search({ common_name => $collection_name, parent => $parent->id })->first) {
            return { error => "$collection_name already exists under " . $parent->common_name };
        }
    } else {
        if (my $exists = $controller->app->m->resultset('Link::Collection')
            ->search({ common_name => $collection_name, parent => undef })->first) {
            return { error => "$collection_name already exists with null parent!" };
        }
    }

    no warnings 'uninitialized';
    $controller->cache->set(nav_tree => undef);
    use warnings 'uninitialized';

    if ($parent) {
        return $controller->app->m->resultset('Link::Collection')->create(
            {
                common_name => $collection_name,
                parent      => $parent->id,
                creator     => $actor->id,
            }
        );
    } else {
        return $controller->app->m->resultset('Link::Collection')->create(
            {
                common_name => $collection_name,
                creator     => $actor->id,
            }
        );
    }
}

sub _add_link {
    my ($controller, $actor, $href, $title, $allow_duplicates, $target, $type, $keywords) = @_;

    # allow passing in vars as hashref.
    if (ref $actor eq "HASH") {
        $href             = $actor->{href};
        $title            = $actor->{title};
        $allow_duplicates = $actor->{allow_duplicates};
        $target           = $actor->{target};
        $type             = $actor->{type};
        $keywords         = $actor->{keywords};
        $actor            = $actor->{actor};
    }

    # set target's default.
    unless ($target) {
        $target = '_blank';
    }

    # set type default
    unless ($type) {
        $type = 'unspecified';
    }

    unless ($actor) {
        unless ($actor = $controller->active_user) {
            die "Access Denied\n";
        }
    }

    if ((my $exists = $controller->app->m->resultset('Link')->search({ href => $href })->first) && (!$allow_duplicates))
    {
        return { error => 'Link to $href already exists!' };
    }

    # keep trying in case we have a race conditon on short codes.
    my $link;
    until ($link) {
        eval {
            $link = $controller->app->m->resultset('Link')->create(
                {
                    creator  => $actor,
                    href     => $href,
                    title    => $title,
                    target   => $target,
                    type     => $type,
                    keywords => $keywords,
                }
            );
        };
        warn $@ unless $link;
    }

    $controller->app->add_link_index($link);

    return $link;
}

sub _delete_link {
    my ($controller, $link) = @_;

    $controller->delete_link_index($link);
    $link->delete;
}

1;
