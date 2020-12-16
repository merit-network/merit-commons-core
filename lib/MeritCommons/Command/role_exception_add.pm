#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::role_exception_add;

use Mojo::Base 'Mojolicious::Command';

has description => "Add a role exception\n";
has usage       => "Usage: $0 role_exception_add [USER] [ROLE]\n";

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
        print "[info]: user '$userid' already has role exception '$role_name'\n";
        exit();
    } else {
        print "[info] Adding role exception\n";
        $self->app->m->resultset('MeritCommons::Model::User::RoleException')
          ->create({ meritcommons_user => $user->id, role => $role->id });
    }
}

1;
