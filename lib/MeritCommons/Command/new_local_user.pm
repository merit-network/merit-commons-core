#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::new_local_user;

use Mojo::Base 'Mojolicious::Command';

has description => "Create a new local user\n";
has usage       => "Usage: $0 new_local_user [UID] [COMMON_NAME] [PASSPHRASE]\n";

sub run {
    my ($self, $username, $common_name, $password) = @_;

    unless ($self->app->config->{authentication_provider} eq "MeritCommons::Helper::LocalAuth") {
        print "[error]: new_local_user requires authentication_provider MeritCommons::Helper::LocalAuth\n";
        return;
    }

    if ($username && $common_name && $password) {
        my $user = $self->app->new_local_user($username, $common_name, $password);
        print "Created user " . $user->id . "\n";
    } else {
        print "Usage: new_local_user [UID] [COMMON_NAME] [PASSPHRASE]\n";
        return;
    }
}

1;
