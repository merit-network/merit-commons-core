#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::new_user_from_ldap_listfile;

use Mojo::Base 'Mojolicious::Command';

has description => "Create a bunch of new MeritCommons users from the LDAP directory configured in meritcommons.conf\n";
has usage       => "Usage: $0 new_user_from_ldap [LISTFILE]\n";

sub run {
    my ($self, $listfile) = @_;
    unless ($self->app->config->{authentication_provider} eq "MeritCommons::Helper::LDAPAuth") {
        print "[error]: new_user_from_ldap requires authentication_provider MeritCommons::Helper::LDAPAuth\n";
        return;
    }

    open my $fh, '<', $listfile or die "Can't open listfile $!\n";

    while (my $username = <$fh>) {
        chomp($username);

        if ($username) {
            my $user;
            eval { $user = $self->app->new_user_from_ldap($username); };
            if ($user) {
                print "Created user $username as ID: " . $user->id . "\n";
            }
        }
    }
}

1;
