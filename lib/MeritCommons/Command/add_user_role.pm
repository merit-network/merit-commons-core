#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::add_user_role;

use Mojo::Base 'Mojolicious::Command';

has description => "add a role to a user\n";
has usage       => "Usage: $0 add_user_role [USER] [ROLE] [CREATE]\n";

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
        if ($create) {
            print "[info]: role '$role_name' did not exist, creating.\n";
            $role = $self->app->m->resultset('User::Role')->create({ common_name => $role_name });
        } else {
            die "[error]: role '$role_name' does not exist in the system, and create bit not specified.\n";
        }
    }

    foreach my $r ($user->roles) {
        if ($role->id == $r->id) {
            print "[info]: user '$username' already has role '$role_name'\n";
            return;
        }
    }

    $self->app->m->resultset('User::RoleUser')->create({ meritcommons_user => $user->id, role => $role->id });

    print "[info]: role '$role_name' added to '$username'\n";
}

1;
