#    MeritCommons Portal
#    Copyright 2013-2015 Wayne State University
#    All Rights Reserved

=head1 NAME

    MeritCommons::Helper::LocalAuth - A helper to handle local accounts for MeritCommons

=head1 DESCRIPTION

    MeritCommons::Helper::LocalAuth is a helper to handle local accounts for MeritCommons

=head1 FUNCTIONS

=cut

package MeritCommons::Helper::LocalAuth;
use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/croak/;

=head2 C<register>

  register($app);

A basic helper register method, which registers the helper with the app.

=cut

sub register {
    my ($self, $app) = @_;

    # install local subroutine as a helper.
    $app->helper(authenticate_user => \&_authenticate_local_user);
    $app->helper(new_local_user    => \&_new_local_user);
    $app->helper(change_local_user_password => \&_change_local_user_password);

}

=head2 C<_new_local_user>

  _new_local_user($username, $common_name, $password);

Create a new local user account for use with MeritCommons.

=cut

sub _new_local_user {
    my ($controller, $username, $common_name, $password) = @_;

    my $config = $controller->app->config;
    my $model  = $controller->app->m;

    # add the local user
    my $user = $controller->add_user_with_streams(
        {
            common_name       => $common_name,
            userid            => $username,
            identity_resource => 'local:' . $username,
        }
    );

    $controller->add_user_index($user);

    # create an authentication profile
    $controller->app->m->resultset('LocalAuth')->create(
        {
            meritcommons_user => $user,
            password       => $password,
        }
    );

    $controller->app->add_identity_to_user($user, $username, 2000);    # self
    $controller->app->emit(created_user => $user);
    return $user;
}

=head2 C<_authenticate_local_user>

  _authenticate_local_user($username, $password);

Authentice a local MeritCommons user based on the supplied username and password.

=cut

sub _change_local_user_password {
    my ($c, $user, $new_password) = @_;
    
    if (ref $user eq "MeritCommons::Model::User") {
        my $la = $c->m->resultset('LocalAuth')->find({ meritcommons_user => $user->id });
        if ($la) {
            $la->password($new_password);
            $la->update;
        }
    }
    
    return undef;
}

sub _authenticate_local_user {
    my ($controller, $username, $password) = @_;

    die "Usage: authenticate_local_user('username', 'password')\n" unless $username && $password;

    my $config = $controller->app->config;
    my $model  = $controller->app->m;

    # let's get the meritcommons user
    my $user = $model->resultset('User')->search(
        {
            userid => $username,
        }
    )->first;

    return undef unless $user;

    # now the LocalUser
    my $luser = $model->resultset('LocalAuth')->search(
        {
            meritcommons_user => $user->id,
        }
    )->first;

    if ($luser && $luser->authenticate($password)) {
        return $user;
    } else {
        if (!$luser) {
            $controller->app->log->error(
                "no credentials found for @{[$user->userid]}, did you switch authentication_providers?");
        }
        return undef;
    }
}

1;
