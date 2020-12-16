#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::set_emails_from_ldap;

use Mojo::Base 'Mojolicious::Command';
use File::Find;

has description => "Set all email addresses from ldap.\n";
has usage       => "Usage: $0 set_emails_from_ldap\n";

sub run {
    my ($self, @args) = @_;

    my $m = $self->app->m;

    if ($self->app->global_config->{authentication_provider} eq "MeritCommons::Helper::LDAPAuth") {
        if (my $ldap = $self->app->fetch_ldap) {
            foreach my $user ($m->resultset('User')->all) {
                my $entry = $self->app->user_to_ldap_entry($user);

                if ($entry) {
                    $user->email_address($entry->get_value('mail'));

                    $user->update;
                }
            }
        } else {
            die "Error connecting to LDAP: $!\n";
        }
    } else {
        die "[error]: MeritCommons doesn't appear to be configured to use LDAP.\n";
    }
}

1;

