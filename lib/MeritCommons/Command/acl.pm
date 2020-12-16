#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::acl;

use Mojo::Base 'Mojolicious::Command';

has description => "Manage user to stream access control permissions\n";
has usage       => "Usage: $0 acl [ACTION] [PERMISSION] [USER] [STREAM] [ADDTL FLAG]\n";
has subcommands => sub {
    [
        [qw/add authorize deauthorize grant remove add_allow_add_moderator remove_allow_add_moderator/],
        [qw/authorship subscription moderatorship/],
    ];
};

sub run {
    my ($self, $action, $permission, $username, $stream_name, $additional) = @_;
    unless ($action && $stream_name && $permission) {
        print $self->usage;
        return;
    }

    # Get the MeritCommons System user
    my $actor = $self->app->user(1);
    my $c     = $self->app->build_controller;
    $c->stash(active_user => $actor);

    if (my $stream = $c->stream($stream_name)) {
        if (my $user = $c->user($username)) {
            if ($permission =~ /^aut/i) {
                $permission = "authorship";
            } elsif ($permission =~ /^sub/i) {
                $permission = "subscription";
            } elsif ($permission =~ /^mod/i) {
                $permission = "moderatorship";
            }

            my $method = $action . "_" . $permission;
            my $data;

            if ($action eq "add") {
                $data = $c->$method($actor, $user, $stream);
            } elsif ($action eq "grant") {
                $data = $c->$method($actor, $user, $stream, $additional);
            } elsif ($action eq "remove") {
                $data = $c->$method($actor, $user, $stream);
            } elsif ($action eq "authorize") {
                if ($permission eq "authorship" || $permission eq "subscription") {
                    $data = $c->$method($actor, $user, $stream, $additional);
                } else {
                    print "[error]: authorization not relevant to moderators\n";
                    return;
                }
            } elsif ($action eq "deauthorize") {
                if ($permission eq "authorship" || $permission eq "subscription") {
                    $data = $c->$method($actor, $user, $stream);
                } else {
                    print "[error]: deauthorization not relevant to moderators\n";
                    return;
                }
            } elsif ($action eq "add_allow_add_moderator") {
                if ($permission eq "moderatorship") {
                    $data = $c->$action($actor, $user, $stream);
                } else {
                    print "[error]: add_allow_add_moderator only relevant to moderators\n";
                    return;
                }
            } elsif ($action eq "remove_allow_add_moderator") {
                if ($permission eq "moderatorship") {
                    $data = $c->$action($actor, $user, $stream);
                } else {
                    print "[error]: remove_allow_add_moderator only relevant to moderators\n";
                    return;
                }
            }

            if ($data->{error}) {
                print "[error]: $data->{error}\n";
                return;
            } else {
                print ucfirst($action) . "ed $permission to/from " . $user->userid . " successfully.\n";
            }
        } else {
            print "[error]: Couldn't find user $username\n";
            return;
        }
    } else {
        print "[error]: Couldn't find stream $stream_name\n";
        return;
    }
}

1;
