#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::remove_user_role;

use Mojo::Base 'Mojolicious::Command';

has description => "remove a role from a user\n";
has usage       => "Usage: $0 remove_user_role [USER] [ROLE]\n";

sub run {
    my ($self, $username, $role_name, $create) = @_;
    unless ($username && $role_name) {
        print $self->usage;
        return;
    }

    my $user = $self->app->user($username);

    unless ($user) {
        print "Can't find user $username!\n";
        return;
    }

    my $role = $self->app->m->resultset('User::Role')->find({ common_name => $role_name });

    unless ($role) {
        die "[error]: role '$role_name' does not exist in the system, and create bit not specified.\n";
    }

    foreach my $r ($user->roles) {
        if ($role->id == $r->id) {
            $self->app->m->resultset('User::RoleUser')->find({ meritcommons_user => $user->id, role => $role->id })
              ->delete;
            print "[info]: role '$role_name' removed from '$username'\n";
            return;
        }
    }

    print "[info]: '$username' did not have role '$role_name'\n";
}

1;
