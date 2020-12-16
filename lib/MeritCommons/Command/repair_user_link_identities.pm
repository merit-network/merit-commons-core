#    MeritCommons Portal
#    Copyright 2017 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::repair_user_link_identities;

use Mojo::Base 'Mojolicious::Command';

has description => "repairs/updates a user's link identities\n";
has usage       => "Usage: $0 repair_user_link_identities [USER]\n";

sub run {
    my ($self, $username) = @_;
    unless ($username) {
        print $self->usage;
        return;
    }

    my $app = $self->app;
    my $repaired;
    my $user  = $app->user($username);
    my $model = $app->m;

    if ($user) {
        $app->add_identity_to_user($user, $user->userid, 10000);
        if (_ldap_test($app)) {
            if (my $e = $app->user_to_ldap_entry($user)) {

                print "[info]: adding identity, multiplier 2 for " . join(',', $e->get_value('organizationalStatus'), $e->get_value('ou')) . "\n";
                $app->add_identity_to_user($user,
                    join(',', $e->get_value('organizationalStatus'), $e->get_value('ou'),), 2); # organizational unit with organizational status

                # students should have these
                if ($e->get_value('coll') && $e->get_value('major')) {
                    print "[info]: adding identity, multiplier 3 for " . join(',', $e->get_value('coll'), $e->get_value('major')) . "\n";
                    
                    # college and major
                    $app->add_identity_to_user($user, join(',', $e->get_value('coll'), $e->get_value('major'),), 3);                                         
                }

                # employees should have these
                if ($e->get_value('organizationalStatus') &&
                    $e->get_value('ou')   &&
                    $e->get_value('dept') &&
                    $e->get_value('title')) {
                    
                    print "[info]: adding identity, multiplier 3 for " . 
                      join(',',
                          $e->get_value('organizationalStatus'), $e->get_value('ou'),
                          $e->get_value('dept'),                 $e->get_value('title')
                      ) . "\n";
                    
                    $app->add_identity_to_user(
                        $user,
                        join(',',
                            $e->get_value('organizationalStatus'), $e->get_value('ou'),
                            $e->get_value('dept'),                 $e->get_value('title'),
                        ),
                        3
                    );    # department, college, and major
                }

                # employee students should have these
                if ($e->get_value('organizationalStatus') &&
                    $e->get_value('ou')    &&
                    $e->get_value('dept')  &&
                    $e->get_value('coll')  &&
                    $e->get_value('major') &&
                    $e->get_value('title')) {

                    print "[info]: adding identity, multiplier 3 for " . 
                      join(',',
                          $e->get_value('organizationalStatus'), $e->get_value('ou'),
                          $e->get_value('dept'),                 $e->get_value('coll'),
                          $e->get_value('major'),                $e->get_value('title'),
                      ) . "\n";

                    $app->add_identity_to_user(
                        $user,
                        join(',',
                            $e->get_value('organizationalStatus'), $e->get_value('ou'),
                            $e->get_value('dept'),                 $e->get_value('coll'),
                            $e->get_value('major'),                $e->get_value('title'),
                        ),
                        3
                    );    # department, college, and major
                }
                
            }   
        } else {
            warn "[warn] not configured to use LDAP; only added 'self' identity\n";   
        }
    } else {
        die "[fatal] user not found: $username\n"; 
    }
}

sub _ldap_test {
    my ($app) = @_;
    eval {
        $app->fetch_ldap;    
    };
        
    return $@ ? 0 : 1;
}

1;
