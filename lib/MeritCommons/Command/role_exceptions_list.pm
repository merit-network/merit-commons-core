#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::role_exceptions_list;

use Mojo::Base 'Mojolicious::Command';

has description => "List all role exceptions\n";
has usage       => "Usage: $0 role_exceptions_list\n";

sub run {
    my ($self) = @_;

    my @records = $self->app->m->resultset('MeritCommons::Model::User::RoleException')->search()->all();

    print "User\tRole\n";

    foreach my $record (@records) {
        print $record->meritcommons_user->userid . "\t" . $record->role->common_name . "\n";
    }
}

1;
