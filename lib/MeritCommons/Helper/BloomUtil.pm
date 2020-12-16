#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::BloomUtil;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app) = @_;

    # install local subroutine as a helper.
    $app->helper('bloom.check_filter' => \&_check_bloom_filter);
    $app->helper('bloom.toggle_filter'   => \&_toggle_bloom_filter);
    $app->helper('bloom.block_objects'   => \&_block_objects);
}

#
# check and set bloom filter take three arguments
# if calling for the current logged in user, the filter name and the key are all that are required
# optionally you pass an MeritCommons::Model::User object as the third argument to override that default behavior
#

sub _check_bloom_filter {
    my ($c, $filter, $key, $user) = @_;

    unless (ref($user) eq "MeritCommons::Model::User") {

        # default to whoever's logged in!
        $user = $c->active_user;
    }

    unless ($filter = $c->global_config->{bloom_filters}->{$filter}) {
        return undef;
    }

    my $i = 0;
    my $present = 0;

    if ($user) {
        my $uuid = $user->unique_id;
        while ($c->bloomd->check($filter, "$uuid.$key.$i")) {
            $present ^= 1;
            $i++;
        }
    }

    return wantarray ? ($present, $i) : $present;
}

sub _toggle_bloom_filter {
    my ($c, $filter, $key, $user) = @_;

    unless (ref($user) eq "MeritCommons::Model::User") {
        # default to whoever's logged in!
        $user = $c->active_user;
    }

    unless ($filter = $c->global_config->{bloom_filters}->{$filter}) {
        return undef;
    }

    if ($user) {
        my ($last_present, $i) = $c->bloom->check_filter($filter, $key, $user);
        my $uuid = $user->unique_id;
        return $c->bloomd->set(
            $c->global_config->{bloom_filters}->{$filter}, "$uuid.$key.@{[($last_present || $i > 0) ? ($i + 1) : 0]}"
        );
    } else {
        return undef;
    }
}

sub _block_objects {
    my ($c, $user, @objects) = @_;

    # if we weren't passed a user, then assume it's just a list of objects and use active_user
    if (ref($user) eq "MeritCommons::Model::User") {
        unless ($user->id == $c->active_user_id) { 
            unshift(@objects, $user);
            $user = $c->active_user;
        }        
    } else {
        unshift(@objects, $user);
        $user = $c->active_user;
    }

    return undef unless $user;

    my $system_user_unique_id = $c->user(1)->unique_id;
    my $user_unique_id = $user->unique_id;
    my $filter         = $c->global_config->{bloom_filters}->{block};
    my $bloomd         = $c->bloomd;
    
    # you can't block MeritCommons System User, and you can't block yourself.  Otherwise, all bets are off.
    @objects = grep { !($user_unique_id eq $_->unique_id || $system_user_unique_id eq $_->unique_id) } @objects;

    my $blocked = 0;
    foreach my $object_id (@objects) {

        # turn off notifications for these objects
        foreach my $item (qw/message stream user/) {
            my $method = "watched_${item}s";

            if (my $watch = $user->$method->find({ target => $object_id })) {
                $watch->delete;
            }
        }

        my ($last_present, $i) = $c->bloom->check_filter($filter, $object_id, $user);

        if ($last_present) {
            $c->audit_log("blocking object $object_id for @{[$user->unique_id]} failed; object alread blocked!");
        } else {
            # set the block for these objects
            $blocked++ if $bloomd->set($filter, "$user_unique_id.$object_id.@{[($last_present || $i > 0) ? ($i + 1) : 0]}");
        }
    }

    return $blocked;
}

1;
