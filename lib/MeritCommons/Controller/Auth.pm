#    MeritCommons Portal
#    Copyright 2013-2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Auth;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Mojo::UserAgent;
use Mojo::Util qw(trim);
use Mojo::URL;
use Mojo::Date;

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    if (($self->req->method eq "GET") && $self->param('logout')) {
        if (my $session = $self->meritcommons_session) {
            $self->auth_log($session->meritcommons_user->userid . " - logout");
        }
        $self->destroy_session;

        my $url;
        if (my $back = $self->param('back') // $self->param('destination_url')) {
            $url = Mojo::URL->new($back);
        } elsif (my $auth_url = $self->app->config->{auth_url}) {

            # let's get a Mojo::URL
            $url = Mojo::URL->new($auth_url);

            # default to destination_url for back parameter, and logged_out for session logged out indicator
            my $back_param       = $self->app->config->{auth_back_param}       || 'destination_url';
            my $logged_out_param = $self->app->config->{auth_logged_out_param} || 'logged_out';

            # add the query data
            $url->query(
                {
                    $back_param       => $self->app->config->{front_door_url} . "/",
                    $logged_out_param => 1,
                }
            );
        } else {

            # otherwise we'll just go back "home" (which will )
            $url = $self->url_for('/');
        }

        $self->redirect_to($url->to_string);
    } elsif ($self->req->method eq "POST") {
        my $referrer        = $self->req->headers->referrer;
        my $identity_server = $self->config->{identity_server};

        if ($referrer && $referrer =~ /^$identity_server/) {

            # This is a new login request
            my $username = $self->param('username');
            my $password = $self->param('password');

            my $session;
            if ($username && $password) {
                $session = $self->new_session("initial_login", $username, $password);
            }

            if ($session) {
                if ($session->meritcommons_user && $session->meritcommons_user->userid ne $username) {
                    $self->auth_log("@{[$session->meritcommons_user->userid]} ($username) - login success");
                } else {
                    $self->auth_log("$username - login success");
                }

                $session->remote_address($self->tx->remote_address);
                my $back = $self->param('back') || '/';

                # calling features_detected immediately allows us to skip the load of the merge
                # only to get bounced again
                unless ($self->features_detected($back)) {

                    # handle the redirect ourselves if features_detected did its job same-request
                    $self->redirect_to($back);
                }
            } else {
                if ($username) {
                    $self->app->emit("failed_login_attempt", $self, $username);
                    $self->auth_log("$username - login incorrect");
                } else {
                    $self->auth_log("No username provided");
                }
                my $url = $self->url_for($self->req->headers->referrer);
                $url->query->param(invalid_login => 1);
                $self->redirect_to($url->to_string);
            }
        } else {
            $referrer = "no referrer header found" unless $referrer;
            $self->auth_log("referrer mismatch ($referrer)");
            my $url = $self->url_for($self->param('back') || '/');
            $url->query->param(invalid_login => 1);
            $self->redirect_to($url->to_string);
        }
    } else {
        if (my $session = $self->meritcommons_session) {
            $self->auth_log($session->meritcommons_user->userid . " - hit auth but already logged in");
            $self->render(template => "auth/logged-in");
        } else {
            $self->auth_log("bad session");
            my $url = $self->url_for($self->param('back') || '/');
            $url->query->param(invalid_login => 1);
            $self->redirect_to($url->to_string);
        }
    }
}

sub session_timed_out {
    my ($self) = @_;
    $self->render('general/session_timed_out');
}

sub detect_js_features {
    my ($self) = @_;
    if (my $session = $self->meritcommons_session) {
        $self->stash(
            {
                back => ($self->param('back') // '/'),
                backbone_view => 'views/common/detect_features',
            }
        );

        if ($session->first_attribute_value('features_detected')) {

            # features already detected...
            $self->redirect_to($self->param('back') || '/');
        } elsif (my $features = $self->signed_cookie('supported_features')) {

            # we have this browser's features in a valid signed cookie
            my @features = split(/:/, $features);
            if (scalar(@features)) {
                foreach my $feature (@features) {
                    $session->$feature(1);
                }
                $session->features_detected(1);
                $self->redirect_to($self->param('back') || '/');
            } else {

                # an empty feature list in the cookie?  That's not good.  Let's detect again.
                $self->render(template => 'general/detect_js_features', format => 'html');
            }
        } else {

            # we need to detect features
            $self->render(template => 'general/detect_js_features', format => 'html');
        }
    } else {
        $self->reply->not_found;
    }
}

# they have 120 seconds to use it.
sub get_login_token {
    my ($self) = @_;
    my $token = $self->crypto->random_hex;
    $self->cache->set(
        $token => {
            expire_time => time + $self->app->config('login_token_expire_time'),
        }
    );
    $self->render(text => $token);
}

sub session_info_options {
    my ($self) = @_;

    # get security profile
    my $sp_key =
        $self->tx->req->headers->referrer ? $self->tx->req->headers->referrer
      : $self->tx->req->headers->origin   ? $self->tx->req->headers->origin . "/"
      :                                     undef;

    my $sp = $self->__get_security_profile($sp_key) if $sp_key;

    if ($sp) {
        $self->res->headers->add('Access-Control-Allow-Origin'      => $sp->{cors_origin});
        $self->res->headers->add('Access-Control-Allow-Methods'     => 'GET, POST, OPTIONS');
        $self->res->headers->add('Access-Control-Allow-Credentials' => 'true');
        $self->res->headers->add('Access-Control-Allow-Headers'     => 'Content-Type, *');
        $self->res->headers->allow('GET, POST, OPTIONS');
    }

    $self->render(text => '');
}

sub session_info {
    my ($self) = @_;

    $self->app->emit('session_info', $self);
    my $si = $self->stash('session_info') || {};

    if (my $session = $self->meritcommons_session) {
        $si->{meritcommons_session}->{expire_time}    = Mojo::Date->new($session->expire_time)->to_string;
        $si->{meritcommons_session}->{heartbeat_from} = $session->heartbeat_from;
        $si->{meritcommons_session}->{session_id}     = $session->session_id;
        $si->{meritcommons_session}->{userid}         = $session->meritcommons_user->userid;
        $si->{meritcommons_session}->{valid}          = 1;

        if (my $created_from = $session->created_from) {
            my (undef, $origin, $destination_url) = split(/,/, $created_from);
            $si->{meritcommons_session}->{origin}               = $origin          if $origin;
            $si->{meritcommons_session}->{original_destination} = $destination_url if $destination_url;
            $si->{meritcommons_session}->{created_from}         = $created_from;
        } else {
            $si->{meritcommons_session}->{unknown_origin} = 1;
        }
    }

    if (my $sp =
        $self->__get_security_profile($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/")) {
        $self->res->headers->add('Access-Control-Allow-Origin'      => $sp->{cors_origin});
        $self->res->headers->add('Access-Control-Allow-Methods'     => 'GET, POST, OPTIONS');
        $self->res->headers->add('Access-Control-Allow-Credentials' => 'true');
        $self->res->headers->add('Access-Control-Allow-Headers'     => 'Content-Type, *');
        $self->res->headers->allow('GET, POST, OPTIONS');
    }

    if (scalar(keys %$si)) {
        $self->render(json => $si);
    } else {
        $self->render(
            json => {
                error           => 'no sessions found',
                reauth_required => 1,
            }
        );
    }
}

sub cookie_setter_options {
    my ($self) = @_;

    # get security profile
    my $sp_key =
        $self->tx->req->headers->referrer ? $self->tx->req->headers->referrer
      : $self->tx->req->headers->origin   ? $self->tx->req->headers->origin . "/"
      :                                     undef;

    my $sp = $self->__get_security_profile($sp_key) if $sp_key;

    if ($sp) {
        $self->res->headers->add('Access-Control-Allow-Origin'      => $sp->{cors_origin});
        $self->res->headers->add('Access-Control-Allow-Methods'     => 'GET, POST, OPTIONS');
        $self->res->headers->add('Access-Control-Allow-Credentials' => 'true');
        $self->res->headers->add('Access-Control-Allow-Headers'     => 'Content-Type, *');
        $self->res->headers->allow('GET, POST, OPTIONS');
    } else {
        $self->res->headers->add('X-Troubled-Hacker' => 'true');
    }
    $self->render(text => '');
}

sub cookie_setter {
    my ($self) = @_;

    # check for JSON
    my $use_json = $self->param('json');

    # check accept header for json behavior, too
    if ($self->tx->req->headers->accept && $self->tx->req->headers->accept eq "application/json") {
        $use_json = 1;
    }

    # anyone can clear cookies, no hash checking involved.
    if ($self->req->method eq "GET" && ($self->param('logout') || $self->param('clearcookie'))) {

        # get the user object, if it exists..
        my $user = $self->active_user;

        # same for the session
        my $session = $self->meritcommons_session;

        # figure out what security profile we're corresponding with
        my $sp =
          $self->__get_security_profile($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/");

        # need these for XHR logouts
        $self->tx->res->headers->add('Access-Control-Allow-Origin'      => $sp->{cors_origin});
        $self->tx->res->headers->add('Access-Control-Allow-Methods'     => 'GET, POST, OPTIONS');
        $self->tx->res->headers->add('Access-Control-Allow-Credentials' => 'true');
        $self->tx->res->headers->add('Access-Control-Allow-Headers'     => 'Content-Type, *');
        $self->tx->res->headers->allow('GET, POST, OPTIONS');

        # clear other cookies as requested in 'clearalso'
        if (my $cookie_names = $self->param('clearalso')) {
            foreach my $cookie_name (split /,/, $cookie_names) {
                $self->cookie(
                    "$cookie_name" => '',
                    {
                        max_age => 0,
                        domain  => $self->app->config->{cookie_domain},
                    }
                );
            }
        }

        # pull out and generate the back URL
        my $back_url = Mojo::URL->new($self->param('back_url') || $self->tx->req->headers->referrer);
        $back_url->query->append(message => "Session Cleared");

        # check to see if we actually cleared an meritcommons session, if we did let's log it and report it as a success!
        if (my $username = ref $user && $user->userid) {

            # pull out the destination URL..
            my $destination_url = $self->param('destination_url');

            # figure out if we should terminate this session..
            my $terminate_session;
            if ($self->resolve_session_created_from($session) eq "el,$sp->{cors_origin},$destination_url") {

                # always terminate this session..
                $terminate_session = 1;
            } elsif ($self->param('force')) {

                # forced termination...
                $terminate_session = 1;
            }

            if ($terminate_session) {

                # this session is OVER!
                $self->destroy_session;
                $self->tx->res->headers->add('X-MeritCommons-Session-Cleared' => 'TRUE');
                $self->auth_log("$username - external logout - " .
                      ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));

                # take action!
                if ($use_json) {
                    $self->render(
                        json => {
                            success                   => 1,
                            meritcommons_session_cleared => 1,
                            message =>
                              "Session for $destination_url and MeritCommons session terminated, origin matches @{[$session->created_from]}, or session was force-terminated",
                        }
                    );
                } else {
                    $self->redirect_to($back_url);
                }
            } else {
                $self->tx->res->headers->add('X-MeritCommons-Session-Cleared' => 'FALSE');
                my $original_destination_url = (split(/,/, $session->created_from))[2];

                # log as an application logout since this isn't a full meritcommons logout
                $self->auth_log("$username - application logout - $destination_url");

                if ($use_json) {
                    $self->render(
                        json => {
                            success                   => 1,
                            meritcommons_session_cleared => 0,
                            logged_out_destination    => $destination_url,
                            original_destination      => $original_destination_url,
                            message =>
                              "Session for $destination_url terminated, but MeritCommons session preserved as it was originally created by $original_destination_url",
                        }
                    );
                } else {
                    $self->redirect_to($back_url);
                }
            }
        } else {

            # there was no session..
            $self->tx->res->headers->add('X-MeritCommons-Session-Not-Found' => 'TRUE');
            if ($use_json) {
                $self->render(
                    json => {
                        success => 0,
                        message => "session not found",
                    }
                );
            } else {
                $self->redirect_to($back_url);
            }
        }
    } elsif ($self->req->method eq "POST") {

        # this might be a login.  let's support JSONRPC as well as regular HTTP, however with JSONRPC
        # the username must be username and the password must be password.

        my (
            $username,           # the user id of the account authenticating, self explanatory
            $password,           # the password for the aformentioned user
            $destination_url,    # where to send the user if the session creation succeeds
            $failed_url,         # where to send the user if the session creation fails
            $token,              # the token used to verify that the page sending this request is authorized
            $token_hash,         # the token; hashed with a secret shared by MeritCommons and the external login form page
        );

        if (my $data = $self->req->json) {
            $username        = $data->{username};
            $password        = $data->{password};
            $destination_url = $data->{destination_url} || $self->app->config('default_destination_url');
            $failed_url      = $data->{failed_url};
            $token           = $data->{token};
            $token_hash      = $data->{token_hash};
            $use_json = 1;       # pretty sure we're using JSON.
        } else {
            ($username) = $self->__find_user_param;
            ($password) = $self->__find_pass_param;
            $destination_url = $self->param('destination_url') || $self->app->config('default_destination_url');
            $failed_url      = $self->param('failed_url');
            $token           = $self->param('token');
            $token_hash      = $self->param('token_hash');
        }

        $username = trim($username);

        # check accept header for json behavior, too
        if ($self->tx->req->headers->accept && $self->tx->req->headers->accept eq "application/json") {
            $use_json = 1;
        }

        # get the security profile of the requesting origin
        my $sp =
          $self->__get_security_profile($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/");

        # these apply to every response
        $self->tx->res->headers->add('Access-Control-Allow-Origin'      => $sp->{cors_origin});
        $self->tx->res->headers->add('Access-Control-Allow-Methods'     => 'GET, POST, OPTIONS');
        $self->tx->res->headers->add('Access-Control-Allow-Credentials' => 'true');
        $self->tx->res->headers->add('Access-Control-Allow-Headers'     => 'Content-Type, *');
        $self->tx->res->headers->allow('GET, POST, OPTIONS');

        if (my $ct = $self->cache->get($token)) {
            if (time < $ct->{expire_time}) {

                # time hasn't elapsed, verify the token.

                if ($self->__verify_token_hash($sp->{secret}, $token, $token_hash)) {

                    # compute the session origin/from
                    # looks like "el,origin" or "el,origin,destination" (or a hash of those) depending on the presence of a security
                    # profile and a destination_url (or in the case of a sha256 hash, the combo was over 255 chars in length)

                    my $created_from;
                    if (ref $sp eq "HASH") {
                        $created_from = "el"; # eXTERNAL lOGIN
                        $created_from .= ",$sp->{cors_origin}" if $sp->{cors_origin};
                    }

                    # allow plugins to handle the preauth
                    $self->app->emit('external_preauth', $self, $username, $password);
                    if (my $cf_override = $self->stash('created_from_override')) {
                        # something overrode the created from url, we'll use that instead of destination_url
                        $created_from .= ",$cf_override";
                    } else {
                        # nothing tried to override the created from url, just use the destination
                        $created_from .= ",$destination_url";
                    }

                    # hash it if it's too long.. base64url encoded sha256 hash..
                    if (length($created_from) > 255) {
                        my $orig_cf = $created_from;
                        $created_from = $self->thumbprint($created_from);
                        $self->cache->set($created_from => $orig_cf); # so we can retrieve it later!
                    }

                    unless ($self->stash->{external_preauth_rendered}) {
                        my $session;
                        if ($username && $password) {
                            if ($username && $password) {
                                $session = $self->new_session($created_from, $username, $password);
                            }
                        }

                        if ($session) {

                            # valid login
                            if ($session->meritcommons_user && $session->meritcommons_user->userid ne $username) {
                                $self->auth_log(
                                    "@{[$session->meritcommons_user->userid]} ($username) - external login success - " .
                                      ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));
                            } else {
                                $self->auth_log("$username - external login success - " .
                                      ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));
                            }
                            $session->remote_address($self->tx->remote_address);

                            # delete the token so it can't be used again
                            $self->cache->delete($token);

                            if ($use_json) {
                                $self->render(
                                    json => {
                                        success => 1,
                                    }
                                );
                            } else {
                                $self->redirect_to($destination_url);
                            }
                        } else {
                            $self->app->emit("failed_login_attempt", $self, $username);
                            
                            my $failed_ip_logins = $self->cache->get("@{[$self->tx->remote_address]}-failed_logins");
                            $self->cache->set("@{[$self->tx->remote_address]}-failed_logins" => ++$failed_ip_logins);

                            # invalid login
                            my $failed_user_logins;
                            if ($username) {
                                $failed_user_logins = $self->cache->get("$username-failed_logins");
                                $self->cache->set("$username-failed_logins" => ++$failed_user_logins);
                                $self->auth_log(
                                    "$username - external login incorrect - ip:$failed_ip_logins/user:$failed_user_logins - "
                                      . ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));
                            } else {
                                $self->auth_log("No username provided to external login - " .
                                      ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));
                            }

                            if ($use_json) {
                                $self->render(
                                    json => {
                                        error                            => "Invalid Login",
                                        success                          => 0,
                                        failed_logins_from_this_ip       => $failed_ip_logins,
                                        failed_logins_with_this_username => $failed_user_logins,
                                    }
                                );
                            } else {
                                my $url = Mojo::URL->new($failed_url || $self->tx->req->headers->referrer);
                                $url->query->append(login_failed => 1);
                                $url->query->append(error        => "Invalid Login");
                                $self->redirect_to($url->to_string);
                            }
                        }
                    }
                } else {

                    # the hash is bad, 5 demerits.
                    my $failed_ip_logins = $self->cache->get("@{[$self->tx->remote_address]}-failed_logins");
                    $self->cache->set("@{[$self->tx->remote_address]}-failed_logins" => $failed_ip_logins + 5);

                    my $failed_user_logins;
                    if ($username) {
                        $self->auth_log("$username - external login incorrect - " .
                              ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));
                        $failed_user_logins = $self->cache->get("$username-failed_logins");
                        $self->cache->set("$username-failed_logins" => $failed_user_logins + 5);
                    } else {
                        $self->auth_log("No username provided to external login - " .
                              ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));
                    }

                    # the token can only be (mis)used once.
                    $self->cache->delete($token);

                    $self->auth_log("invalid token hash - " .
                          ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));

                    if ($use_json) {
                        $self->render(
                            json => {
                                error                            => "Invalid Login",
                                success                          => 0,
                                failed_logins_from_this_ip       => $failed_ip_logins + 5,
                                failed_logins_with_this_username => $failed_user_logins + 5,
                            }
                        );
                    } else {
                        my $url = Mojo::URL->new($failed_url || $self->tx->req->headers->referrer);
                        $url->query->append(login_failed => 1);
                        $url->query->append(error        => "Invalid Login");
                        $self->redirect_to($url->to_string);
                    }
                }
            } else {

                # the session token has expired
                # the token can only be (mis)used once.
                $self->cache->delete($token);

                $self->auth_log("expired login token - " .
                      ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));

                if ($use_json) {
                    $self->render(
                        json => {
                            error           => "Login Token Expired",
                            success         => 0,
                            bad_login_token => 1,
                        }
                    );
                } else {
                    my $url = Mojo::URL->new($failed_url || $self->tx->req->headers->referrer);
                    $url->query->append(error => "Login Token Expired");
                    $self->redirect_to($url);
                }
            }
        } else {
            $self->auth_log("unknown login token '$token' - " .
                  ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));

            if ($use_json) {
                $self->render(
                    json => {
                        error           => "Unknown Login Token",
                        success         => 0,
                        bad_login_token => 1,
                    }
                );
            } else {
                my $url = Mojo::URL->new($failed_url ||
                      ($self->tx->req->headers->referrer || $self->tx->req->headers->origin . "/"));
                $url->query->append(error => "Login Token Expired");

                # go back where you came from.
                $self->redirect_to($self->tx->req->headers->referrer);
            }
        }
    } else {

        # this is something we weren't expecting, possibly caused by a broken or old browser
        if (my $auth_url = $self->app->config->{auth_url}) {

            # let's get a Mojo::URL
            my $url = Mojo::URL->new($auth_url);

            # default to destination_url for back parameter, and logged_out for session logged out indicator
            my $back_param = $self->app->config->{auth_back_param} || 'destination_url';
            my $back_url = $self->url_for($self->param($back_param) || $self->app->config->{front_door_url} . "/");

            # add the query data
            $url->query(
                {
                    $back_param => $back_url->to_abs->to_string,
                    broken_cors => 1,
                }
            );

            $self->redirect_to($url);
        } else {
            $self->redirect_to('/login');
        }
    }
}

sub __verify_token_hash {
    my ($self, $secret, $token, $hash) = @_;
    my $check_hash = $self->sha256_hex(reverse($secret) . $token . $secret);
    if ($check_hash eq $hash) {
        return 1;
    }
    return undef;
}

sub __token_with_hash {
    my ($self, $for) = @_;

    if (my $secret = $self->__get_secret($for)) {
        my $token = $self->crypto->random_hex;
        my $hash  = $self->sha256_hex(reverse($secret) . $token . $secret);
        return ($token, $hash);
    }
    return undef;
}

sub __get_security_profile {
    my ($self, $for) = @_;
    return undef unless $for;
    foreach my $sp (@{ $self->app->config->{external_auth_secrets} }) {
        if ($for =~ $sp->{regex}) {
            return $sp;
        }
    }
    return undef;
}

sub __get_secret {
    my ($self, $for) = @_;
    foreach my $sp (@{ $self->app->config->{external_auth_secrets} }) {
        if ($for =~ $sp->{regex}) {
            return $sp->{secret};
        }
    }
    return undef;
}

sub __find_user_param {
    my ($self) = @_;
    foreach my $try (qw/user accessid user_id username login userID/) {
        if (my $val = $self->param($try)) {
            return ($val, $try);
        }
    }
    return undef;
}

sub __find_pass_param {
    my ($self) = @_;
    foreach my $try (qw/pass accessid_password password Password passwd/) {
        if (my $val = $self->param($try)) {
            return ($val, $try);
        }
    }
    return undef;
}

sub session_poll {
    my ($self) = @_;
    if (my $session = $self->meritcommons_session) {

        # uncoverable branch false It looks like we don't make any sessions without an expire time, yes?
        if (my $expire_time = $session->expire_time) {
            $self->render(text => $expire_time - time);
        } else {

            # uncoverable statement It looks like we don't make any sessions without an expire time, yes?
            $self->render(text => -1);
        }
    } else {
        $self->render(text => -10);
    }
}

sub session_extend {
    my ($c) = @_;

    my $seo = $c->global_config->{session_extend_origin};
    if (ref $seo eq "ARRAY" && scalar @$seo) {
        # get security profile
        my $extender =
            $c->tx->req->headers->referrer ? $c->tx->req->headers->referrer
          : $c->tx->req->headers->origin   ? $c->tx->req->headers->origin . "/"
          :                                     undef;

        if (scalar(grep { /^\Q$extender\E$/ } @$seo) > 0) {
            $c->res->headers->add('Access-Control-Allow-Origin'      => $extender);
            $c->res->headers->add('Access-Control-Allow-Methods'     => 'GET, POST, OPTIONS');
            $c->res->headers->add('Access-Control-Allow-Credentials' => 'true');
            $c->res->headers->add('Access-Control-Allow-Headers'     => 'Content-Type, *');
            $c->res->headers->allow('GET, POST, OPTIONS');
        }
    }

    $c->render(text => '1');
}

sub session_extend_options {
    my ($c) = @_;

    my $seo = $c->global_config->{session_extend_origin};
    if (ref $seo eq "ARRAY" && scalar @$seo) {
        # get security profile
        my $extender =
            $c->tx->req->headers->referrer ? $c->tx->req->headers->referrer
          : $c->tx->req->headers->origin   ? $c->tx->req->headers->origin . "/"
          :                                     undef;

        if (scalar(grep { /^\Q$extender\E$/ } @$seo) > 0) {
            $c->res->headers->add('Access-Control-Allow-Origin'      => $extender);
            $c->res->headers->add('Access-Control-Allow-Methods'     => 'GET, POST, OPTIONS');
            $c->res->headers->add('Access-Control-Allow-Credentials' => 'true');
            $c->res->headers->add('Access-Control-Allow-Headers'     => 'Content-Type, *');
            $c->res->headers->allow('GET, POST, OPTIONS');
        }
    }

    $c->render(text => '');
}

sub login {
    my ($self) = @_;

    my $back = $self->param('back') // $self->param('destination_url');

    # if someone stashed a message in the session, stash it in the app context
    $self->stash(message       => $self->param('message'));
    $self->stash(heading_title => $self->param('heading_title'));
    $self->stash(back => $back);

    if ($self->active_user) {
        $self->redirect_to($back // '/');
    } elsif (defined $self->stash->{heading_title} && $self->stash->{heading_title} =~ /^[\w\s,\.;\&\'+\:]+$/) {
        $self->render('auth/login');
    } elsif (my $auth_url = $self->app->config->{auth_url}) {

        # let's get a Mojo::URL
        my $url = Mojo::URL->new($auth_url);

        # default to destination_url for back parameter, and logged_out for session logged out indicator
        my $back_param       = $self->app->config->{auth_back_param}       || 'destination_url';
        my $logged_out_param = $self->app->config->{auth_logged_out_param} || 'logged_out';

        my $back_url = $self->url_for($back // ($self->app->config->{front_door_url} . "/"));

        # add the query data
        $url->query(
            {
                $back_param       => $back_url->to_abs->to_string,
                $logged_out_param => 1,
            }
        );

        $self->redirect_to($url);
    } else {
        $self->render('auth/login');
    }
}

# famous last words
sub hold_my_beer {
    my ($c) = @_;
    
    my $hr = $c->crypto->random_signed_token;
    my $payload = join('.', $hr->{token}, $hr->{signature});
    
    # this only lasts 5 seconds.  the clock's running.
    if (my $user = $c->active_user) {
        $c->cache->set("hmb-$payload", {
            key => $hr->{key},
            userid => $user->userid,
            ip => $c->tx->remote_address,
            session => $c->cookie('wayneAuth'),  
        }, 5);
    }
    
    $c->render(text => $payload);
}

sub gimme_my_beer {
    my ($c) = @_;
    
    my $back = Mojo::URL->new($c->param('back') // $c->param('destination_url') // '/');
    
    if (my $phrase = $c->param('phrase')) {
        my ($token, $signature) = split(/\./, $phrase);
        if ($phrase =~ /^[\w\-\.]{64,}$/) {
            if (my $cache_hr = $c->cache->get("hmb-$phrase")) {
                # single use.
                $c->cache->delete("hmb-$phrase");
                if ($cache_hr->{ip} && $cache_hr->{ip} eq $c->tx->remote_address) {
                    if ($c->crypto->verify_signed_token($token, $signature, $cache_hr->{key})) {
                        my $session = $c->new_session(
                            "ctx_switch_from:@{[$c->sha256_hex($cache_hr->{session})]}", 
                            $cache_hr->{userid}, 
                            $c->decrypt_cookie_payload($cache_hr->{session}),
                        );
                        
                        if ($session) {
                            $c->auth_log("sctx - session context switched successfully for $cache_hr->{userid}");
                            $c->redirect_to($back);
                            return;
                        } else {
                            $c->app->emit("failed_gmb_attempt", $c);
                            $c->auth_log("sctx - session ctx switch failed to create new session for " .
                                "$cache_hr->{userid}");
                        }
                    } else {
                        $c->auth_log("sctx - bad token signature in session ctx switch for $cache_hr->{userid}");
                    }
                } else {
                    $c->auth_log("sctx - ip mismatch trying to switch session ctx for $cache_hr->{userid}");
                }
            } else {
                $c->auth_log("sctx - no record of ctx switch '$phrase'");
            }
        } else {
            $c->auth_log("sctx - illegal characters in passed phrase '$phrase'");
        }
    } else {
        $c->auth_log("sctx - phrase absent");
    }
    
    $c->render(text => "ālea iacta est");
}

1;
