#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::role_exception_delete;

use Mojo::Base 'Mojolicious::Command';

has description => "Remove a role exception\n";
has usage       => "Usage: $0 role_exception_delete [USER] [ROLE]\n";

sub run {
    my ($self, $userid, $role_name) = @_;
    my $user;
    my $role;
    $user = $self->app->user($userid);
    $role = $self->app->m->resultset('User::Role')->find({ common_name => $role_name });

    unless ($user && $role) {
        print $self->usage;
        return;
    }

    my $role_exception = $self->app->m->resultset('MeritCommons::Model::User::RoleException')
      ->search({ meritcommons_user => $user->id, role => $role->id })->first();

    if ($role_exception) {
        print "[info] Deleting role exception\n";
        $role_exception->delete();
    } else {
        print "[info] Role exception could not be found\n";
    }
}

1;
