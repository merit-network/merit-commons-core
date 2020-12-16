#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Util;
use Net::LDAP;
require Exporter;

=head1 NAME

MeritCommons::Util - a general collection of useful methods and functions

=head1 SYNOPSIS

  use MeritCommons::Util qw(update_hash);
  update_hash(\%hash,\%data_to_add);

=head1 DESCRIPTION

MeritCommons::Util contains a general collection of useful methods and functions
that might be of value throughout the MeritCommons application, and makes
them available for exporting.

=cut

=head1 FUNCTIONS

=head2 C<update_hash>

  update_hash(\%hash1,\%hash2);

C<update_hash> takes the key-value pairs in the second hashref and adds
them to the first hashref, overwriting any conflicting data in the
process.

=cut

sub update_hash {
    my @args = @_;

    my ($old, $new) = @args;
    if (ref($old) eq 'HASH' and ref($new) eq 'HASH') {
        foreach my $new_key (keys %$new) {
            if (ref($old->{$new_key}) eq 'HASH' and ref($new->{$new_key}) eq 'HASH') {
                update_hash($old->{$new_key}, $new->{$new_key});
            } else {
                $old->{$new_key} = $new->{$new_key};
            }
        }
        return;
    }
    die "Update must be called with two args, both hashrefs.  Stopped";
}

=head2 C<new_user_from_ldap>

  my $user = new_user_from_ldap($uid);

C<new_user_from_ldap> takes a username/uid, searches LDAP, and creates an
MeritCommons::Model::User object and database entry.

=cut

@EXPORT_OK = qw(update_hash new_user_from_ldap);

1;
