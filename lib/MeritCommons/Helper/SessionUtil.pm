#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

=head1 NAME

    MeritCommons::Helper::SessionUtil - A helper to handle common session tasks

=head1 DESCRIPTION

    MeritCommons::Helper::SessionUtil is a helper to handle common session tasks

=head1 FUNCTIONS

=cut

package MeritCommons::Helper::SessionUtil;
use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/croak/;
use Time::Piece;
use JSON::XS;
use POSIX qw/strftime/;

=head2 C<register>

  register($app);

A basic helper register method, which registers the helper with the app.

=cut

sub register {
    my ($self, $app) = @_;

    # session helpers
    $app->helper(new_session            => \&_new_session);
    $app->helper(destroy_session        => \&_destroy_session);
    $app->helper(decrypt_cookie_payload => \&_decrypt_cookie_payload);
    $app->helper(meritcommons_session      => \&_meritcommons_session);
    $app->helper(active_user            => \&_active_user);
    $app->helper(features_detected      => \&_features_detected);
    $app->helper(auth_log               => \&_auth_log);
    $app->helper(session_heartbeat      => \&_session_heartbeat);
    $app->helper(parse_session_cookie   => \&_parse_session_cookie);

    # keep session heartbeats + clean up stale sessions.
    $app->hook(
        before_dispatch => sub {
            my ($c) = @_;

            if ($c->req->url->to_string =~
                /^(?:\/js|\/css|\/img|\/hydrant|\/audio|\/myws|\/[0-9a-f]{32}|\/favicon|\/font|\/auth\/session_poll|\/si|\/cs|\/lt)/
              ) {
                return;
            }

            # clear all expired sessions no matter what.
            $c->app->m->resultset('Session')->search(
                {
                    expire_time => { '<', time - 3600 }
                }
            )->delete;

            if ($c->param('no_heartbeat')) {
                return;
            }

            $c->session_heartbeat(substr($c->req->url->to_string, 0, 254));
        }
    );

    $app->on(
        password_changed => sub {
            my ($app, $c, $session) = @_;
            my $rs = $c->m->resultset('Session')->search({meritcommons_user => $session->meritcommons_user->id});
            
            my $killed;
            while (my $s = $rs->next) {
                # skip the triggering session
                next if $s->session_id eq $session->session_id;
                
                $c->pub_write(join(' ', $s->session_id, 'session_destroy'));
                $s->delete;
                $killed++;
            }
            
            my $log_message = $session->meritcommons_user->userid . " - global logout due to password change";
            if ($killed) {
                $log_message .= " - $killed additional session" . ($killed > 1 ? 's' : '') . ' also destroyed';
            }
            
            $c->auth_log($log_message);
            $c->destroy_session;
        }
    );

    $app->on(
        session_destroyed => sub {
            my ($self, $controller, $session) = @_;
            $controller->pub_write(join(' ', $session->session_id, 'session:destroy'));
        }
    );
}

=head2 C<session_heartbeat>

  $c->session_heartbeat($heartbeat_from);

Registers activity and updates the session's expiration time.  Also emits the 'session_refreshed' event on the
MeritCommons application object.

=cut

sub _session_heartbeat {
    my ($c, $heartbeat_from) = @_;
    if (my $session = $c->meritcommons_session($c->cookie('wayneAuth'))) {
        unless ($session->is_expired) {
            # global session update
            $session->update(
                {
                    heartbeat_time => time,
                    heartbeat_from => substr($c->req->url->to_string, 0, 254),
                    expire_time    => $session->session_length + time,
                }
            );
            
            # allow plugins, other stuff to update.
            $c->app->emit('session_refreshed', $c, $session, $heartbeat_from);            
        }
    }
}

=head2 C<_active_user>

  _active_user($session);

Returns the current active user, using the supplied $session if needed.

=cut

sub _active_user {
    my ($self, $session) = @_;

    if (my $user = $self->stash('active_user')) {
        return $user;
    } elsif (my $session = $self->meritcommons_session) {
        $self->stash(active_user => $session->meritcommons_user);
        return $self->stash('active_user');
    }

    return undef;
}

=head2 C<_meritcommons_session>

  _meritcommons_session($session_string);

Returns an MeritCommons Session based on the supplied $session_string or the wayneAuth cookie
if no $session_string is provided

=cut

sub _meritcommons_session {
    my ($controller, $session_string) = @_;

    my ($session, $session_id);
    if ($session = $controller->stash('meritcommons_session')) {
        return $session;
    } else {
        $session_string //= $controller->cookie('wayneAuth');

        return undef unless $session_string;
 
        # always get the sha256_hex of the session string as session_id
        if ($session_string =~ /^[a-f0-9]+$/) {
            $session_id = $session_string;
        } else {
            $session_id = $controller->crypto->sha256_hex($session_string);
        }

        eval {
            $session = $controller->app->m->resultset('Session')->find(
                {
                    session_id  => $session_id,
                    expire_time => { '>', time },
                }
            );
        };

        if ($session && $session->in_storage) {
            if ($session_string eq $session_id) {
                # if we passed in a session id instead of a cookie value, we can't do any further checks on the
                # session.  just act as an accessor.
                return $session;
            }
            
            my $sc = $controller->cache->get("authenticated-$session_id");
            if ($sc && $sc > time) {
                $controller->stash(meritcommons_session => $session);
                return $session;
            } elsif ($controller->authenticate_user($session->meritcommons_user->userid, 
              $controller->decrypt_cookie_payload($session_string, $session->key->k, $session->key->id))) {
                # the cookie authenticates.
                $controller->stash(meritcommons_session => $session);
                $controller->cache->set("authenticated-$session_id" => time + 5, 5);
                return $session;
            } else {
                # the cookie does not authenticate
                $controller->app->emit(password_changed => $controller, $session);
                return undef;        
            }
        } else {
            return undef;
        }
    }
}

=head2 C<_new_session>

  _new_session($from, $username, $password);

Generate and return a new MeritCommons session. This returns the $session
if sucessful, or undef if authentication fails.

=cut

sub _new_session {
    my ($controller, $from, $username, $password) = @_;
    my $app = $controller->app;

    if (my $user = $controller->authenticate_user($username, $password)) {

        # set the last login time!
        $user->last_login_time(time);
        $user->update;

        my $m = $app->m;

        # the session id is an md5 hex of their validUser cookie
        my $session = $m->resultset('Session')->create(
            {
                created_from   => $from,
                heartbeat_from => $from,
                meritcommons_user => $user->id,

                # pull this in from the config file for the model, used to compute expire time
                session_length => $app->global_config->{session_length},
            }
        );

        # create a key for the session.
        my $key = $m->resultset('Session::Keystore')->create(
            {
                session => $session->id,
                k       => $controller->crypto_stream_key,
            }
        );

        # "a" is for "MeritCommons", the cookie setter.
        # create the wayneAuth cookie
        my $wa_session = "a:$username:[" . $app->encrypt_pw($password, $key->k, $key->id) . "]";

        $session->session_id($controller->crypto->sha256_hex($wa_session));
        $session->update;

        $controller->cookie(
            wayneAuth => $wa_session,
            { path => "/", domain => $controller->app->global_config->{cookie_domain} }
        );    # second array value is the wayneAuth cookie!

        # Default JavaScript to disabled until proven otherwise by detect_features.js
        $session->{javascript_supported} = 0;

        # set this for the duration of this request.
        $controller->stash(meritcommons_session => $session);

        $controller->app->emit('session_established', $controller, $session);

        return $session;
    } else {
        return undef;
    }
}

=head2 C<_destroy_session>

  _destroy_session();

Deletes the current user's session.

=cut

sub _destroy_session {
    my ($controller, $reason) = @_;

    # This is logout request
    $controller->cookie(
        wayneAuth => 'USER_LOG_OUT ' . time,
        { max_age => 0, domain => $controller->app->global_config->{cookie_domain} }
    );

    if ($controller->meritcommons_session) {
        my $session = $controller->meritcommons_session;
        $session->delete;
        $controller->app->emit('session_destroyed', $controller, $session, $reason);
    }
}

=head2 C<_decrypt_cookie_payload>

  _decrypt_cookie_payload($session_string);

Given a $session_string, return the decrypted user password.

=cut

sub _decrypt_cookie_payload {
    my ($controller, $session_string) = @_;

    return undef unless $session_string;

    # get session so we can get the key.
    my $session_id = $controller->crypto->sha256_hex($session_string);

    my $session = $controller->m->resultset('Session')->search(
        {
            session_id => $session_id,
        }
    )->first;

    return undef unless $session;

    my ($encrypted_password) = $session_string =~ /\[([^\]]+)\]$/;

    return $controller->crypto->stream_cipher_decrypt($encrypted_password, $session->key->k, $session->key->id);
}

=head2 C<_features_detected>

  _features_detected();

Detect features from the user's browser. Return 1 if the features are
newly detected, 0 otherwise.

=cut

sub _features_detected {
    my ($controller, $back) = @_;

    if (my $session = $controller->meritcommons_session) {
        if (!$session->features_detected->first) {
            if (my $features = $controller->signed_cookie('supported_features')) {

                # we have this browser's features in a valid signed cookie
                foreach my $feature (split(/:/, $features)) {
                    $session->$feature(1);
                }
                $session->features_detected(1);
            } else {

                # we need to detect features
                $back ||= $controller->req->url->to_abs->path;
                $controller->stash(
                    {
                        back => ($controller->param('back') // '/'),
                        backbone_view => 'views/common/detect_features',
                    }
                );

                $controller->render(template => 'general/detect_js_features', format => 'html');
                return 1;
            }
        }
    }

    return 0;
}

sub _parse_session_cookie {
    my ($self, $cookie_string) = @_;
    
    my ($setter, $username, $encoded_ciphertext) = $cookie_string =~ /^([a-zA-Z]{1,2}):([^:]+):\[([^\]]+)\]$/;
    
    if ($setter && $username && $encoded_ciphertext) {
        return ($setter, $username, $encoded_ciphertext);
    } else {
        return undef;
    }
}

sub _auth_log {
    my ($self, $message) = @_;
    my $c = $self->global_config;
    my $line = "[" . strftime("%d/%b/%Y:%H:%M:%S %z", localtime) . "] - " . $self->tx->remote_address . " - $message";
    my $auth_log;

    if ($c->{log_to_publisher}) {
        $self->pub_write("LOG AUTH_LOG " . $self->instance_id . " $line");
    } elsif ($c->{auth_log_syslog}) {
        foreach my $logger (@{ $self->auth_log_syslog }) {
            eval { $logger->send("@{[$self->instance_id]} $line"); };
        }
    } else {
        if (exists($c->{auth_log})) {

            # uncoverable branch true I'm not going to bother with these for now
            open $auth_log, '>>', $c->{auth_log} or warn "[error] can't open auth log $c->{auth_log}: $!\n";
        } else {

            # uncoverable branch true I'm not going to bother with these for now
            open $auth_log, '>>', $ENV{MERITCOMMONS_HOME} . "/var/log/auth.log"
              or warn "[error] can't open auth log: $!\n";
        }
        print $auth_log "$line\n";
        close($auth_log);
    }
}

1;
