#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::LDAPAuth;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::URL;
use Carp qw/croak/;

sub register {
    my ($self, $app) = @_;

    # break ldap_uri out into ldap_hoste, ldap_scheme, and ldap_port
    my $gc = $app->global_config;
    unless ($gc->{ldap_connect_info}->{ldap_host} && $gc->{ldap_connect_info}->{ldap_scheme}) {
        if (my $uri = Mojo::URL->new($gc->{ldap_connect_info}->{ldap_uri})) {
            $gc->{ldap_connect_info}->{ldap_host} = $uri->host;
            $gc->{ldap_connect_info}->{ldap_scheme} = $uri->scheme;
        } else {
            $app->log->error("LDAP authentication is improperly configured - ldap_host and ldap_scheme not present in configuration and cannot be inferred from ldap_uri");
        }
    }

    # install local subroutine as a helper.
    $app->helper(authenticate_user              => \&_authenticate_ldap_user);
    $app->helper(new_user_from_ldap             => \&_new_user_from_ldap);
    $app->helper(fetch_ldap                     => \&_fetch_ldap);
    $app->helper(user_to_ldap_entry             => \&_user_to_ldap_entry);
    $app->helper(new_stream_from_ldap_filter    => \&_new_stream_from_ldap_filter);
    $app->helper(update_stream_from_ldap_filter => \&_update_stream_from_ldap_filter);
    $app->helper(new_stream_from_ldap_group     => \&_new_stream_from_ldap_group);
    $app->helper(update_stream_from_ldap_group  => \&_update_stream_from_ldap_group);

    # handle situations where some other process didn't find a user they were thinking they
    # should find.
    $app->on(
        user_not_found => sub {
            my ($app, $username) = @_;

            if ($app->global_config->{ldap_provision_not_found}) {
                $app->new_user_from_ldap($username);
            }
        }
    );

    # self_check events ask us to make sure we're operating correctly.
    $app->on(
        self_check => sub {
            my ($app, $c) = @_;

            if (!$c->fetch_ldap) {
                $c->res->body(
                    "FAIL - unable to make LDAP connection to '@{[$app->global_config->{ldap_connect_info}->{ldap_host}]}'; application is up; please escalate to tier 2"
                );
            }
        }
    );
}

sub _new_stream_from_ldap_filter {
    my ($controller, $opts) = @_;

    my $actor           = $opts->{actor};
    my $stream_name     = $opts->{stream_name};
    my $moderator       = $opts->{moderator};
    my $auth_authn      = $opts->{require_author_authorization};
    my $sub_authn       = $opts->{require_subscriber_authorization};
    my $filter          = $opts->{filter};
    my $all_are_authors = $opts->{all_are_authors};

    my $config = $controller->app->config;

    my $stream;

    # check if this stream exists.
    if ($stream = $controller->stream($stream_name)) {
        print "Stream $stream_name already exists (" . $stream->unique_id . "), try update_stream_from_ldap_filter!\n";
        return;
    } else {

        # create the stream.
        $auth_authn = 1 unless defined($auth_authn);
        $sub_authn  = 0 unless defined($sub_authn);

        $stream = $controller->m->resultset('Stream')->create(
            {
                common_name                       => $stream_name,
                unique_id                         => $controller->new_uuid,
                creator                           => $moderator->id,
                requires_author_authorization     => $auth_authn,
                requires_subscriber_authorization => $sub_authn,
            }
        );

        $controller->add_stream_index($stream);

        $controller->m->resultset('Stream::Moderator')->create(
            {
                meritcommons_user      => $moderator->id,
                stream              => $stream->id,
                allow_add_moderator => 1,
                added_by            => $moderator->id,
            }
        );
    }

    my $ldap = $controller->fetch_ldap();

    my $lres = $ldap->search(
        base   => $config->{ldap_connect_info}->{base_dn},
        scope  => 'sub',
        filter => $filter,
    );

    my ($created_users, $added_users);
    if ($lres->count == 0) {
        print "[info] filter '$filter' matched no records.\n";
        return;
    } else {

        # what field are we looking for to identify these users?  we will pass the value of it to new_user_from_ldap if it
        # doesn't already exist.
        my $unique_id_field = $config->{ldap_connect_info}->{unique_id_field};
        foreach my $entry ($lres->entries) {
            my $uid = $entry->get_value($unique_id_field);
            if ($uid) {
                my $user;
                unless ($user = $controller->user($uid)) {
                    $user = $controller->new_user_from_ldap($uid);
                    ++$created_users;
                }

                # add each user to the stream.
                if ($all_are_authors) {
                    $controller->grant_authorship($actor, $user, $stream, 1);
                }
                $controller->grant_subscription($actor, $user, $stream, 1);
                ++$added_users;
            }
        }
    }

    return ($created_users, $added_users);
}

sub _update_stream_from_ldap_filter {
    my ($controller, $opts) = @_;

    my $actor           = $opts->{actor};
    my $stream_name     = $opts->{stream_name};
    my $filter          = $opts->{filter};
    my $all_are_authors = $opts->{all_are_authors};

    my $config = $controller->app->config;

    my $stream;

    # check if this stream exists.
    unless ($stream = $controller->stream($stream_name)) {
        print "Stream $stream_name does not exist, try new_stream_from_ldap_filter!\n";
        return;
    }

    my $ldap = $controller->fetch_ldap();

    my $lres = $ldap->search(
        base   => $config->{ldap_connect_info}->{base_dn},
        scope  => 'sub',
        filter => $filter,
    );

    my ($created_users, $added_users);
    if ($lres->count == 0) {
        print "[info] filter '$filter' matched no records.\n";
        return;
    } else {
        if ($all_are_authors) {

            # wipe out authors only if we're going to let LDAP dictate who are authors.
            foreach my $author ($stream->authors) {
                $controller->remove_authorship($actor, $author->meritcommons_user, $stream);
            }
        }

        foreach my $subscriber ($stream->subscribers) {
            $controller->remove_subscription($actor, $subscriber->meritcommons_user, $stream);
        }

        # what field are we looking for to identify these users?  we will pass the value of it to new_user_from_ldap if it
        # doesn't already exist.
        my $unique_id_field = $config->{ldap_connect_info}->{unique_id_field};
        foreach my $entry ($lres->entries) {
            my $uid = $entry->get_value($unique_id_field);
            if ($uid) {
                my $user;
                unless ($user = $controller->user($uid)) {
                    $user = $controller->new_user_from_ldap($uid);
                    ++$created_users;
                }

                # add each user to the stream.
                if ($all_are_authors) {
                    $controller->grant_authorship($actor, $user, $stream, 1);
                }
                $controller->grant_subscription($actor, $user, $stream, 1);
                ++$added_users;
            }
        }
    }
    return ($created_users, $added_users);
}

sub _new_stream_from_ldap_group {
    my ($controller, $opts) = @_;

    my $actor           = $opts->{actor};
    my $stream_name     = $opts->{stream_name};
    my $moderator       = $opts->{moderator};
    my $auth_authn      = $opts->{require_author_authorization};
    my $sub_authn       = $opts->{require_subscriber_authorization};
    my $group_dn        = $opts->{group_dn};
    my $all_are_authors = $opts->{all_are_authors};

    my $config = $controller->app->config;

    my $stream;

    # check if this stream exists.
    if ($stream = $controller->stream($stream_name)) {
        print "Stream $stream_name already exists (" . $stream->unique_id . "), try update_stream_from_ldap_group!\n";
        return;
    } else {

        # create the stream.
        $auth_authn = 1 unless defined($auth_authn);
        $sub_authn  = 0 unless defined($sub_authn);

        $stream = $controller->m->resultset('Stream')->create(
            {
                common_name                       => $stream_name,
                unique_id                         => $controller->new_uuid,
                creator                           => $moderator->id,
                requires_author_authorization     => $auth_authn,
                requires_subscriber_authorization => $sub_authn,
            }
        );

        $controller->add_stream_index($stream);

        $controller->m->resultset('Stream::Moderator')->create(
            {
                meritcommons_user      => $moderator->id,
                stream              => $stream->id,
                allow_add_moderator => 1,
                added_by            => $moderator->id,
            }
        );
    }

    my $ldap = $controller->fetch_ldap();

    my $lres = $ldap->search(
        base   => $group_dn,
        scope  => 'base',
        filter => "objectClass=*",
    );

    my ($created_users, $added_users);
    if ($lres->count == 0) {
        print "[info] could not find group $group_dn\n";
        return;
    } else {

        # what field are we looking for to identify these users?  we will pass the value of it
        # to new_user_from_ldap if it doesn't already exist.
        my $unique_id_field = $config->{ldap_connect_info}->{unique_id_field};
        my $group_entry     = $lres->entry(0);

        foreach my $member ($group_entry->get_value('member')) {

            # resolve this member.
            my $lres = $ldap->search(
                base   => $member,
                scope  => 'base',
                filter => "objectClass=*",
            );

            my $entry = $lres->entry(0);

            if ($entry) {
                my $uid = $entry->get_value($unique_id_field);
                if ($uid) {
                    my $user;
                    unless ($user = $controller->user($uid)) {
                        $user = $controller->new_user_from_ldap($uid);
                        ++$created_users;
                    }

                    # add each user to the stream.
                    if ($all_are_authors) {
                        $controller->grant_authorship($actor, $user, $stream, 1);
                    }
                    $controller->grant_subscription($actor, $user, $stream, 1);
                    ++$added_users;
                }
            }
        }
    }

    return ($created_users, $added_users);
}

sub _update_stream_from_ldap_group {
    my ($controller, $opts) = @_;

    my $actor           = $opts->{actor};
    my $stream_name     = $opts->{stream_name};
    my $group_dn        = $opts->{group_dn};
    my $all_are_authors = $opts->{all_are_authors};

    my $config = $controller->app->config;

    my $stream;

    # check if this stream exists.
    unless ($stream = $controller->stream($stream_name)) {
        print "Stream $stream_name does not exist, try new_stream_from_ldap_group!\n";
        return;
    }

    my $ldap = $controller->fetch_ldap();

    my $lres = $ldap->search(
        base   => $group_dn,
        scope  => 'base',
        filter => "objectClass=*",
    );

    my ($created_users, $added_users);
    if ($lres->count == 0) {
        print "[info] could not find group $group_dn\n";
        return;
    } else {
        if ($all_are_authors) {

            # wipe out authors only if we're going to let LDAP dictate who are authors.
            foreach my $author ($stream->authors) {
                $controller->remove_authorship($actor, $author->meritcommons_user, $stream);
            }
        }

        foreach my $subscriber ($stream->subscribers) {
            $controller->remove_subscription($actor, $subscriber->meritcommons_user, $stream);
        }

        # what field are we looking for to identify these users?  we will pass the value of it to new_user_from_ldap if it
        # doesn't already exist.
        my $unique_id_field = $config->{ldap_connect_info}->{unique_id_field};
        my $group_entry     = $lres->entry(0);

        foreach my $member ($group_entry->get_value('member')) {

            # resolve this member.
            my $lres = $ldap->search(
                base   => $member,
                scope  => 'base',
                filter => "objectClass=*",
            );

            my $entry = $lres->entry(0);

            if ($entry) {
                my $uid = $entry->get_value($unique_id_field);
                if ($uid) {
                    my $user;
                    unless ($user = $controller->user($uid)) {
                        $user = $controller->new_user_from_ldap($uid);
                        ++$created_users;
                    }

                    # add each user to the stream.
                    if ($all_are_authors) {
                        $controller->grant_authorship($actor, $user, $stream, 1);
                    }
                    $controller->grant_subscription($actor, $user, $stream, 1);
                    ++$added_users;
                }
            }
        }
    }

    return ($created_users, $added_users);
}

# obtain a Net::LDAP object from config data.
sub _fetch_ldap {
    my ($controller) = @_;

    my $config = $controller->global_config;

    # create a Net::LDAP object from the configuration file, try URI first, if that doesn't exist
    # try the old way.
    my $ldap;
    if (exists $config->{ldap_connect_info}->{ldap_uri} && $config->{ldap_connect_info}->{ldap_uri} ) {
        $ldap = Net::LDAP->new( $config->{ldap_connect_info}->{ldap_uri} );
    } else {
        $ldap = Net::LDAP->new(
            $config->{ldap_connect_info}->{ldap_host},
            scheme => $config->{ldap_connect_info}->{ldap_scheme},
            port   => $config->{ldap_connect_info}->{ldap_port},
        );
    }

    if ($ldap) {

        # authenticate the object with our privileged user credentials
        my $res = $ldap->bind(
            $config->{ldap_connect_info}->{ldap_priv_bind_dn},
            password => $config->{ldap_connect_info}->{ldap_priv_bind_pass},
            version  => 3,
        );

        if ($res->code) {
            my $error_id = $controller->new_uuid;
            my $error    = $res->error;
            chomp $error;

            $controller->app->log->error("Error ID $error_id - error connecting to LDAP server - $error");
            if ($controller->tx->remote_address && $controller->app->mode eq 'production') {
                die "<h3>LDAP Bind Error</h3><p>Error ID: $error_id</p>\n";
            } else {
                die "LDAP bind error: $error\n\nError ID: $error_id\n";
            }
            return;
        } else {
            return $ldap;
        }
    } else {
        my $error_id = $controller->new_uuid;
        my $error    = $@;
        chomp $error;

        $controller->app->log->error("Error ID $error_id - error connecting to LDAP server - $error");
        if ($controller->tx->remote_address && $controller->app->mode eq 'production') {
            die "<h3>LDAP Connection Error</h3><p>Error ID: $error_id</p>\n";
        } else {
            die "LDAP connection error: $error\n\nError ID: $error_id\n";
        }
    }
}

sub _new_user_from_ldap {
    my ($controller, $username) = @_;

    my $config = $controller->global_config;
    my $model  = $controller->m;

    # let's make sure the user doesn't already exist.
    my $user = $model->resultset('User')->search(
        {
            userid => $username,
        }
    )->first;

    if ($user) {
        print "[error]: record already exists as userid " . $user->id . "\n";
        return;
    }

    # create a Net::LDAP object from the configuration file
    my $ldap = $controller->fetch_ldap;

    # interpolate $username where ${username} is inside of ldap_connect_info->search_filter.
    my $filter = $config->{ldap_connect_info}->{search_filter};
    $filter =~ s/\$\{username\}/$username/g;

    # search to find the DN.
    my $lres = $ldap->search(
        base   => $config->{ldap_connect_info}->{base_dn},
        scope  => 'sub',
        filter => $filter,
        attrs  => [ '*', 'entryUUID', 'nsUniqueID', 'objectGUID' ],
    );

    # if we didn't get an account, let's freak out here.
    unless ($lres->count > 0) {
        return undef;
    }

    # we did get an account, let's create it!
    my $entry = $lres->entry(0);

    my $userid             = $entry->get_value($config->{ldap_connect_info}->{unique_id_field} // 'uid');
    my $common_name        = $entry->get_value('cn');
    my $title              = $entry->get_value('title') // "WSU Affiliate";
    my $email_address      = $entry->get_value('mail') // '';
    my $external_unique_id = $entry->get_value('entryUUID') // $entry->get_value('nsUniqueID') //
      __parse_guid($entry->get_value('objectGUID'));

    # add_user_with_streams is in DataUtil
    $user = $controller->add_user_with_streams(
        {
            userid            => $userid,
            common_name       => $common_name,
            title             => $title,
            identity_resource => (
                "$config->{ldap_connect_info}->{ldap_scheme}://$config->{ldap_connect_info}->{ldap_host}/?" . $entry->dn
            ),
            email_address      => $email_address,
            external_unique_id => $external_unique_id,
        }
    );

    # add identities everyone should have
    $controller->add_identity_to_user($user, $entry->get_value('uid'), 10000);    # self
    $controller->add_identity_to_user($user,
        join(',', $entry->get_value('organizationalStatus'), $entry->get_value('ou'),), 2); # organizational unit with organizational status

    # students should have these
    if ($entry->get_value('coll') && $entry->get_value('major')) {
        $controller->add_identity_to_user($user, join(',', $entry->get_value('coll'), $entry->get_value('major'),), 3)
          ;                                                                                 # college and major
    }

    # employees should have these
    if ($entry->get_value('organizationalStatus') &&
        $entry->get_value('ou')   &&
        $entry->get_value('dept') &&
        $entry->get_value('title')) {

        $controller->add_identity_to_user(
            $user,
            join(',',
                $entry->get_value('organizationalStatus'), $entry->get_value('ou'),
                $entry->get_value('dept'),                 $entry->get_value('title'),
            ),
            3
        );    # department, college, and major
    }

    # employee students should have these
    if ($entry->get_value('organizationalStatus') &&
        $entry->get_value('ou')    &&
        $entry->get_value('dept')  &&
        $entry->get_value('coll')  &&
        $entry->get_value('major') &&
        $entry->get_value('title')) {

        $controller->add_identity_to_user(
            $user,
            join(',',
                $entry->get_value('organizationalStatus'), $entry->get_value('ou'),
                $entry->get_value('dept'),                 $entry->get_value('coll'),
                $entry->get_value('major'),                $entry->get_value('title'),
            ),
            3
        );    # department, college, and major
    }

    return $user;
}

sub _user_to_ldap_entry {
    my ($controller, $user) = @_;

    my $config = $controller->app->config;
    my $ldap   = $controller->fetch_ldap;

    my ($ldap_uri, $dn) = split(/\?/, $user->identity_resource, 2);

    if ($dn) {
        my $lres = $ldap->search(
            base   => $dn,
            scope  => 'base',
            filter => 'objectClass=*',
        );

        if ($lres->count == 0) {

            # interpolate $username where ${username} is inside of ldap_connect_info->search_filter.
            my $filter   = $config->{ldap_connect_info}->{search_filter};
            my $username = $user->userid;
            $filter =~ s/\$\{username\}/$username/g;

            $lres = $ldap->search(
                base   => $config->{ldap_connect_info}->{base_dn},
                scope  => 'sub',
                filter => $filter,
            );

            if ($lres->count == 1) {

                # if the query for the userid returned true but the dn query didn't we definitely have a new DN.
                my $identity_resource =
                  "$config->{ldap_connect_info}->{ldap_scheme}://$config->{ldap_connect_info}->{ldap_host}/?" .
                  $lres->entry(0)->dn;
                $controller->audit_log(
                    "account $username moved DNs, automatically correcting; dn => @{[$lres->entry(0)->dn]}");
                $user->identity_resource($identity_resource);
                $user->update;
            }
        }

        # if we didn't get an account, we're done.
        unless ($lres->count > 0) {
            return undef;
        }

        return $lres->entry(0);
    } else {
        return undef;
    }
}

# authenticate an MeritCommons user
sub _authenticate_ldap_user {
    my ($controller, $username, $password) = @_;

    return undef unless ($username && $password);

    my $config = $controller->app->config;
    my $model  = $controller->m;
    my $ldap   = $controller->fetch_ldap;

    # interpolate $username where ${username} is inside of ldap_connect_info->search_filter.
    my $filter = $config->{ldap_connect_info}->{search_filter};
    $filter =~ s/\$\{username\}/$username/g;

    # search to find the DN.
    my $lres = $ldap->search(
        base   => $config->{ldap_connect_info}->{base_dn},
        scope  => 'sub',
        filter => $filter,
        attrs  => [ '*', qw/entryUUID nsUniqueID objectGUID/ ],
    );

    warn
      "[debug] LDAP Authentication - searching $config->{ldap_connect_info}->{base_dn} with '$filter' found @{[$lres->count]} entries\n"
      if $ENV{MERITCOMMONS_DEBUG};

    # if we didn't get an account, let's freak out here.
    unless ($lres->count > 0) {
        return undef;
    }

    # let's make sure the user exists in MeritCommons
    my $user = $model->resultset('User')->search(
        {
            identity_resource => (
                "$config->{ldap_connect_info}->{ldap_scheme}://$config->{ldap_connect_info}->{ldap_host}/?" .
                  $lres->entry(0)->dn
            ),
        }
    )->first;

    ## DEBUG CODE
    if ($ENV{MERITCOMMONS_DEBUG}) {
        warn "[debug] LDAP Authentication - Using source LDAP record @{[$lres->entry(0)->dn]}\n";

        if ($user) {
            warn "[debug] LDAP Authentication - $username currently exists as UserID @{[$user->id]}\n";
        } else {
            warn "[debug] LDAP Authentication - $username does not currently exist in MeritCommons as provided by " . 
                 "$config->{ldap_connect_info}->{ldap_scheme}://$config->{ldap_connect_info}->{ldap_host}/\n";
        }
    }

    my $res = $ldap->bind(
        $lres->entry(0)->dn,
        password => $password,
        version  => 3,
    );

    # only do this if the bind was successful
    if ($res->code == 0) {
        warn "[debug] LDAP Authentication - $username bind successful\n" if $ENV{MERITCOMMONS_DEBUG};

        unless ($user) {

            # first check if they changed DNs.  try and find a case sensitive match and then an all lowercase one.
            my $entry = $lres->entry(0);

            my $unique_id_field = $config->{ldap_connect_info}->{unique_id_field};
            my $test_user       = $controller->user($entry->get_value($unique_id_field));

            if ($test_user) {
                my ($ldap_uri, $dn) = split(/\?/, $test_user->identity_resource, 2);
                my $identity_resource =
                  "$config->{ldap_connect_info}->{ldap_scheme}://$config->{ldap_connect_info}->{ldap_host}/?" .
                  $entry->dn;

                warn "[debug] LDAP Authentication - Lookup via unique_id '$unique_id_field' found an account\n"
                  if $ENV{MERITCOMMONS_DEBUG};

                if ($entry->dn ne $dn) {
                    # just a moved DN, update it and use this one.
                    $controller->audit_log(
                        "account $username moved DNs, automatically correcting; dn => @{[$entry->dn]}");
                    $test_user->identity_resource($identity_resource);
                    warn "[debug] LDAP Authentication - $username\'s DN changed from '$dn' to '@{[$entry->dn]}'\n"
                      if $ENV{MERITCOMMONS_DEBUG};
                    $test_user->update;
                    $user = $test_user;
                } else {
                    if ($ENV{MERITCOMMONS_DEBUG}) {
                        warn
                            "[debug] LDAP Authentication - LDAP Account error for user $username; '@{[$entry->dn]}' " . 
                            "eq '$dn' but can't find user record matching identity_resource: '$identity_resource'\n"
                    }
                        
                    if ($config->{ldap_connect_info}->{clobber_identity_resource}) {
                        # we have a DN that matches, but something about the LDAP server name changed.  if this ldap server says we can, let's
                        # clobber the existing identity resource value with the new identity_resource
                        if ($ENV{MERITCOMMONS_DEBUG}) {
                            warn "[debug] LDAP Authentication - clobber_identity_resource true for this config; allowing Identity Origin change " . 
                                 "from @{[$test_user->identity_resource]} to $identity_resource\n"; 
                        }
                        $controller->app->log->info(
                            "Identity origin server changed for $username; @{[$test_user->identity_resource]} is now $identity_resource"  
                        );
                        $test_user->identity_resource($identity_resource);
                        $test_user->update;
                        $user = $test_user;
                    } else {
                        $controller->app->log->error(
                            "LDAP Account error for user $username; '@{[$entry->dn]}' eq '$dn' but can't find user record matching identity_resource: '$identity_resource'"
                        );
                    }
                }
            } else {

                # first check to make sure we don't have this object's unique id on file...
                my $external_unique_id = $entry->get_value('entryUUID') // $entry->get_value('nsUniqueID') //
                  __parse_guid($entry->get_value('objectGUID'));

                if ($external_unique_id) {
                    $user = $controller->m->resultset('User')->find({ external_unique_id => $external_unique_id });
                }

                warn "[debug] LDAP Authentication - found user object via external unique ID\n"
                  if $ENV{MERITCOMMONS_DEBUG};

                # we got nothing, this is a new user.
                unless ($user) {

                    # autoviv the user on first authenticate
                    warn "[debug] LDAP Authentication - autoprovisioning new user $username from @{[$entry->dn]}\n"
                      if $ENV{MERITCOMMONS_DEBUG};
                    $user = $controller->new_user_from_ldap($username);
                }
            }
        }

        return $user;
    } else {
        return undef;
    }
}

# parse GUID to it's hyphenated form
sub __parse_guid {
    my ($bytes) = @_;

    use bytes;

    my $chunks = [ substr($bytes, 0, 4), substr($bytes, 4, 2), substr($bytes, 6, 2), substr($bytes, 8, 2),
        substr($bytes, 10, 6), ];

    return uc(
        join('-',
            join('', map { sprintf("%02x", ord($_)) } split(//, reverse($chunks->[0]))),
            join('', map { sprintf("%02x", ord($_)) } split(//, reverse($chunks->[1]))),
            join('', map { sprintf("%02x", ord($_)) } split(//, reverse($chunks->[2]))),
            join('', map { sprintf("%02x", ord($_)) } split(//, $chunks->[3])),
            join('', map { sprintf("%02x", ord($_)) } split(//, $chunks->[4])),
        )
    );
}

1;
