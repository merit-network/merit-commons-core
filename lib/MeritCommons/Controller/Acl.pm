#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Acl;

# declare our @ISA
our @ISA;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;
    my $data = {};

    # default to active user if a user wasn't passed.
    my $user = $self->user($self->param('user')) || $self->active_user;
    if (my $stream = $self->stream($self->param('stream'))) {
        if ($user) {

            # one action
            my $action = $self->param('action');

            # potentially multiple permissions
            my @permissions = @{$self->every_param('permission')};

            # canonicalize shorthands
            for (my $i = 0 ; $i <= $#permissions ; $i++) {
                if ($permissions[$i] =~ /^aut/i) {
                    $permissions[$i] = "authorship";
                } elsif ($permissions[$i] =~ /^sub/i) {
                    $permissions[$i] = "subscription";
                } elsif ($permissions[$i] =~ /^mod/i) {
                    $permissions[$i] = "moderatorship";
                }
            }

            foreach my $permission (@permissions) {
                my $method = $action . "_" . $permission;
                if ($action eq "add") {
                    $data = $self->$method($self->active_user, $user, $stream);
                } elsif ($action eq "grant") {
                    $data = $self->$method($self->active_user, $user, $stream, $self->param('additional'));
                } elsif ($action eq "remove") {
                    $data = $self->$method($self->active_user, $user, $stream);
                } elsif ($action eq "authorize") {
                    if ($permission eq "authorship" ||
                        $permission eq "subscription") {
                        $data = $self->$method($self->active_user, $user, $stream, $self->param('additional'));
                    } else {
                        $data->{error} = "authorization not relevant to moderators\n";
                    }
                } elsif ($action eq "deauthorize") {
                    if ($permission eq "authorship" ||
                        $permission eq "subscription") {
                        $data = $self->$method($self->active_user, $user, $stream);
                    } else {
                        $data->{error} = "deauthorization not relevant to moderators\n";
                    }
                } elsif ($action eq "add_allow_add_moderator") {
                    if ($permission eq "moderatorship") {
                        $data = $self->app->$action($self->active_user, $user, $stream);
                    } else {
                        $data->{error} = "add_allow_add_moderator only relevant to moderators";
                    }
                } elsif ($action eq "remove_allow_add_moderator") {
                    if ($permission eq "moderatorship") {
                        $data = $self->app->$action($self->active_user, $user, $stream);
                    } else {
                        $data->{error} = "remove_allow_add_moderator only relevant to moderators";
                    }
                }
            }
        } else {
            if ($self->param('user')) {
                $data->{error} = "Couldn't find user " . $self->param('user');
            } else {
                $data->{error} = "No user specified";
            }
        }
    } else {
        if ($self->param('stream')) {
            $data->{error} = "Couldn't find stream " . $self->param('stream');
        } else {
            $data->{error} = "No stream specified";
        }

    }

    my $redirect_to = $self->param('back');
    if ($redirect_to eq "1") {
        $redirect_to = $self->req->headers->referrer ? $self->req->headers->referrer : "/";
    }

    if ($redirect_to) {
        $self->redirect_to($redirect_to);
    } else {
        if ($data->{error}) {
            $self->render(json => { error => $data->{error} });
        } else {
            $self->render(json => { success => 1 });
        }
    }
}

1;
