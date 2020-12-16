#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::new_user_from_ldap;

use Mojo::Base 'Mojolicious::Command';

has description => "Create a new MeritCommons user from the LDAP directory configured in meritcommons.conf\n";
has usage       => "Usage: $0 new_user_from_ldap [UID]\n";

sub run {
    my ($self, $username) = @_;
    unless ($self->app->config->{authentication_provider} eq "MeritCommons::Helper::LDAPAuth") {
        print "[error]: new_user_from_ldap requires authentication_provider MeritCommons::Helper::LDAPAuth\n";
        return;
    }

    if ($username) {
        my $user = $self->app->new_user_from_ldap($username);
        if ($user) {
            print "Created user " . $user->id . "\n";
        }
    } else {
        print "Usage: new_user_from_ldap [UID]\n";
        return;
    }
}

1;
