package MeritCommons::Test::AuthViaLocalUser;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
use MeritCommons::Test;
use File::Temp;

use Mojo::JSON qw/encode_json/;
use Mojo::URL;
use Mojo::Transaction::HTTP;
use Mojolicious::Commands;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;

sub make_meritcommons : Test(startup => 3) {
    my $self      = shift;
    my $t         = MeritCommons::Test->new();
    my $meritcommons = $t->app;

    # Make our standard schema
    my $install_schema_cmd = MeritCommons::Command::install_schema->new;
    $install_schema_cmd->app($meritcommons);
    $install_schema_cmd->run();

    # Check that it's really what we think it is
    ok(
        $meritcommons->m->resultset('User')->count == 1, 
        "there is exactly one (1) user in the fresh database"
    );    # Yes we have a new database
    ok(
        $meritcommons->m->resultset('Stream::Message')->count == 0,
        "there are exactly zero (0) messages in the fresh database"
    );    # Yes we have a new database

    # Add test data
    my $new_local_user_cmd1 = MeritCommons::Command::new_local_user->new;
    $new_local_user_cmd1->{app} = $meritcommons;
    $new_local_user_cmd1->run('testuserone', 'Test UserOne', 'testpassone');

    my $user1 = $meritcommons->m->resultset('User')->search(
        {
            userid => 'testuserone',
        }
    )->single;

    # Check that it's really what we think it is
    ok(
        $meritcommons->m->resultset('User')->count == 2, 
        "there are exactly two (2) users database after adding the first user"
    );  

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
    $self->{user1}     = $user1;
}

sub test_login_selenium : Test(no_plan) {
    my ($self) = @_;
    return unless $ENV{SELENIUM_TESTING};
    my $t = $self->{t};

    my $res = $t->selenium_call(
        {
            method => 'get',
            args   => [
                {
                    val             => '/',
                    is_relative_url => 1,
                }
            ],
            time => 5000,
        }
    );

    is($res, 1, "load home page using chrome single call");

    $res = $t->selenium_call(
        {
            calls => [

                # Get /sysinfo
                {
                    method => 'get',
                    args   => [
                        {
                            val             => '/sysinfo',
                            is_relative_url => 1,
                        }
                    ],
                },

                # test 404 page
                {
                    method => 'get',
                    args   => [
                        {
                            val             => '/s/whatever',
                            is_relative_url => 1,
                        }
                    ],
                },

            ],
            time => 5000,
        }
    );

    is($res->[0]->{result}, 1, "load sysinfo page using 'calls' interface and chrome");
    is($res->[1]->{result}, 1, "unauthenticated users get 404");

    my $login_test = sub {
        my ($t, $driver) = @_;

        $driver->set_implicit_wait_timeout(5000);
        $driver->set_window_size(720, 1280);
        $driver->get($t->fixup_front_door_url('/')->to_string);

        # click on the page to get past firefox notification pop up
        my $page = $driver->find_element('/html/body');
        $page->click;

        my $username_field = $driver->find_element_by_name('username');
        $username_field->click;
        $driver->send_keys_to_active_element('testuserone');

        my $password_field = $driver->find_element_by_name('password');
        $password_field->click;
        $driver->send_keys_to_active_element('testpassone');

        my $login = $driver->find_element_by_class('btn');
        $login->click;

        if ($driver->find_element_by_id('messages-go-here')) {

            # test success
            return 1;
        } else {

            # test fail
            return 0;
        }
    };

    $res = $t->selenium_call(
        {
            browser => 'chrome',
            block   => $login_test,
            time    => 5000,
        }
    );

    is($res, 1, "looking for the merge after login (chrome)");

    $self->builder->skip("firefox search for merge after login fails intermittently");

    #   is($res, 1, "looking for the merge after login (firefox)");
    #
    #   $res = $t->selenium_call({
    #       browser => 'firefox',
    #       block => $login_test,
    #       time => 5000,
    #   });
    #
    #   is($res, 1, "looking for the merge after login (firefox)");

    if ($ENV{SELENIUM_TEST_IE}) {
        $res = $t->selenium_call(
            {
                browser => 'ie',
                block   => $login_test,
                time    => 5000,
            }
        );

        is($res, 1, "looking for the merge after login (internet explorer)");
    } else {
        $self->builder->skip("not testing internet explorer at this time");
    }

    $res = $t->selenium_call(
        {
            method  => 'get',
            browser => 'chrome',
            args    => [
                {
                    val             => '/auth?logout=1',
                    is_relative_url => 1,
                }
            ],
            time => 2000,
        }
    );

    is($res, 1, "logging out (chrome)");

    $res = $t->selenium_call(
        {
            method  => 'get',
            browser => 'firefox',
            args    => [
                {
                    val             => '/auth?logout=1',
                    is_relative_url => 1,
                }
            ],
            time => 2000,
        }
    );

    is($res, 1, "logging out (firefox)");

    my $invalid_login_test = sub {
        my ($t, $driver) = @_;

        $driver->set_implicit_wait_timeout(5000);
        $driver->set_window_size(720, 1280);
        $driver->get($t->fixup_front_door_url('/')->to_string);

        my $form           = $driver->find_element_by_id('login-form');
        my $username_field = $driver->find_child_element($form, 'username', 'name');
        my $password_field = $driver->find_child_element($form, 'password', 'name');

        $username_field->send_keys('testuserone');
        $password_field->send_keys('wrongpassword');

        $form->submit();

        if ($driver->find_element_by_id('login-form')) {

            # test success
            return 1;
        } else {

            # test fail
            return 0;
        }
    };

    $res = $t->selenium_call(
        {
            browser => 'chrome',
            block   => $invalid_login_test,
            time    => 5000,
        }
    );

    is($res, 1, "looking for the login form after bad login (chrome)");

    $res = $t->selenium_call(
        {
            browser => 'firefox',
            block   => $invalid_login_test,
            time    => 5000,
        }
    );

    is($res, 1, "looking for the login form after bad login (firefox)");

    if ($ENV{SELENIUM_TEST_IE}) {
        $res = $t->selenium_call(
            {
                browser => 'ie',
                block   => $invalid_login_test,
                time    => 5000,
            }
        );

        is($res, 1, "looking for the login form after bad login (internet explorer)");
    } else {
        $self->builder->skip("not testing internet explorer at this time");
    }
}

sub test_logout : Test(45) {
    my $self = shift;
    my $t    = $self->{t};

    # Check logout
    $t->get_ok('/auth' => form => { logout => 1 })->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query([ logout => undef ])->to_string);

    # Do it again in case the last one had a lingering session to test handling of logout with no session
    $t->get_ok('/auth' => form => { logout => 1 })->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query([ logout => undef ])->to_string);

    # Make sure I can't see anything
    $t->get_ok('/')->status_is(200)->element_exists_not('html body div#inbound', 'Looking for no inbound div');

    # Now login
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(200)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');
    $t->get_ok('/')->status_is(200)->element_exists('html body meta', 'Looking for meta refresh');
    my $location = (split("'", (split(';', $t->tx->res->dom->find('html body meta')->[0]->attr('content')))[1]))[1];
    $t->get_ok($location)->status_is(302)->header_is('location' => $t->app->url_for('/'));
    $t->get_ok('/')->status_is(200)->element_exists('html body div#inbound', 'Looking for inbound div');

    # Now logout again
    $t->get_ok('/auth' => form => { logout => 1 })->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query([ logout => undef ])->to_string);

    # Now login and logout with a back param weeeee
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(200)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');
    $t->get_ok('/')->status_is(200)->element_exists('html body meta', 'Looking for meta refresh');
    $location = (split("'", (split(';', $t->tx->res->dom->find('html body meta')->[0]->attr('content')))[1]))[1];
    $t->get_ok($location)->status_is(302)->header_is('location' => $t->app->url_for('/'));
    $t->get_ok('/')->status_is(200)->element_exists('html body div#inbound', 'Looking for inbound div');
    $t->get_ok('/auth' => form => { logout => 1, back => 'http://example2.com' })->status_is(302)
      ->header_is('location' => Mojo::URL->new('http://example2.com')->query([ logout => undef ])->to_string);

    # Make sure I can't see anything
    $t->get_ok('/')->status_is(200)->element_exists_not('html body div#inbound', 'Looking for no inbound div');

    # Test the back param for unauthed GET
    $t->get_ok('/auth' => form => { back => 'http://example2.com' })->status_is(302)
      ->header_is('location' => Mojo::URL->new('http://example2.com')->query(invalid_login => 1)->to_string);
}

sub hold_my_beer_test : Test(no_plan) {
    my ($self) = @_;
    my $t    = $self->{t};

    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
        { 
            username => 'testuserone', 
            password => 'testpassone',
        }
    )->header_like('Set-Cookie' => qr/wayneAuth/);
    
    my $phrase = $t->get_ok('/hmb')->tx->res->body;
    $t->ua->cookie_jar->empty;
    $t->post_ok('/gmb' => form => { phrase => $phrase })->header_like('Set-Cookie', qr/wayneAuth/);
    $t->ua->cookie_jar->empty;
    $t->post_ok('/gmb' => form => { phrase => $phrase })->header_unlike('Set-Cookie', qr/wayneAuth/);
}

sub test_auth : Test(36) {
    my $self = shift;
    my $t    = $self->{t};

    # Before auth
    $t->get_ok('/')->status_is(200)->element_exists('form#login-form', 'login form present');

    # Auth
    # Check failures
    $t->get_ok('/auth')->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query(invalid_login => 1)->to_string);
    $t->post_ok('/auth')->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query(invalid_login => 1)->to_string);

    # Gibberish user/pass
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'lkjklj', password => 'aasdfasdf' })->status_is(302)
      ->header_like(location => qr/invalid_login/, 'checking for invalid_login in redirect url');

    # Real user, wrong pass
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'lkj234lkj23l4j' })->status_is(302)
      ->header_like(location => qr/invalid_login/, 'checking for invalid_login in redirect url');

    # Missing user, invented pass
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form => { password => 'garbage' })
      ->status_is(302)->header_like(location => qr/invalid_login/, 'checking for invalid_login in redirect url');

    # Real user, missing pass
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form => { username => 'testuserone' })
      ->status_is(302)->header_like(location => qr/invalid_login/, 'checking for invalid_login in redirect url');

    # Bad user, existing pass
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'lkjjkljsidsfa', password => 'testpassone' })->status_is(302)
      ->header_like(location => qr/invalid_login/, 'checking for invalid_login in redirect url');

    # Good login - can't figure out the attribute value in the CSS selector so this will suffice for now.
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->header_like('Set-Cookie', qr/wayneAuth/)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');

    # Good login - back specified, but note that I'm not really asserting it D:
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone', back => 'u/1/' })->status_is(200)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');

    # Good credentials, bad referrer
    $t->post_ok('/auth' => { Referer => 'http://example.com' } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query(invalid_login => 1)->to_string);

    # Good credentials, bad referrer, back specified
    $t->post_ok('/auth' => { Referer => 'http://example.com' } => form =>
          { username => 'testuserone', password => 'testpassone', back => 'http://example2.com' })->status_is(302)
      ->header_is('location' => Mojo::URL->new('http://example2.com')->query(invalid_login => 1)->to_string);

    # Any other ideas here?
}

sub test_login : Test(15) {
    my $self = shift;
    my $t    = $self->{t};

    # Auth
    # Good login - can't figure out the attribute value in the CSS selector so this will suffice for now.
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(200)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');
    $t->get_ok('/')->status_is(200)->element_exists('html body meta', 'Looking for meta refresh');

    my $location = (split("'", (split(';', $t->tx->res->dom->find('html body meta')->[0]->attr('content')))[1]))[1];

    $t->get_ok($location)->status_is(302)->header_is('location' => $t->app->url_for('/'));
    $t->get_ok('/')->status_is(200)->element_exists('html body div#inbound', 'Looking for inbound div');

    # Cover the redirect to logged-in
    $t->get_ok('/auth')->status_is(200)->element_exists('html body div.row', 'Looking for Hey div');
}

sub test_session_poll : Test(15) {
    my $self = shift;
    my $t    = $self->{t};

    # Make sure we don't have a session
    $t->get_ok('/auth' => form => { logout => 1 });

    # Test poll response for logged out user
    $t->get_ok('/auth/session_poll')->status_is(200)->content_is('-10');

    # Make sure the configured session_length is long
    $t->app->config->{session_length} = 10000;

    # Login
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(200);

    # Test poll response for good session
    $t->get_ok('/auth/session_poll')->status_is(200);
    ok($t->tx->res->text > 0);

    # Logout
    $t->get_ok('/auth' => form => { logout => 1 });

    # Make sure the configured session_length is short
    $t->app->config->{session_length} = 1;

    # Login
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(200);

    sleep 2;

    # Test poll response for expired session
    $t->get_ok('/auth/session_poll')->status_is(200);
    ok($t->tx->res->text < 0);
}

sub test_session_extend : Test(9) {
    my $self = shift;
    my $t    = $self->{t};

    # Make sure we don't have a session
    $t->get_ok('/auth' => form => { logout => 1 });

    # Test extend response for logged out user
    $t->get_ok('/auth/session_extend')->status_is(200)->content_is('1');

    # Login
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(200);

    # Test extend response for logged in user
    $t->get_ok('/auth/session_extend')->status_is(200)->content_is('1');
}

sub test_login_sub : Test(12) {
    my $self = shift;
    my $t    = $self->{t};

    # Make sure we don't have a session
    $t->get_ok('/auth' => form => { logout => 1 });

    $t->get_ok('/login')->status_is(200)->element_exists('html body form.form-signin', 'Looking for sign in form');

    # Login
    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => 'testuserone', password => 'testpassone' })->status_is(200);

    # Check logged in user with no back
    $t->get_ok('/login' => form => { username => 'testuserone', password => 'testpassone' })->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query([ username => undef, password => undef ])->to_string);

    # Check logged in user with back specified
    $t->get_ok(
        '/login' => form => { username => 'testuserone', password => 'testpassone', back => 'http://example2.com' })
      ->status_is(302)->header_is('location' => Mojo::URL->new('http://example2.com')->to_string);
}

sub test_auth_log_sub : Test(1) {
    my $self = shift;
    my $t    = $self->{t};

    # disable zmq logging for tests
    delete $t->app->config->{log_to_publisher};
    my $auth_log = $t->app->config->{auth_log};

    require MeritCommons::Controller::Auth;
    my $c = MeritCommons::Controller::Auth->new(app => $t->app);
    $c->tx(Mojo::Transaction::HTTP->new);

    # Avoid warnings
    $c->tx->remote_address('127.0.0.1');

    $c->auth_log('A test message');

    open(my $samefh, '<', $auth_log);
    my $found_it = 0;
    while (<$samefh>) {
        if (/A test message$/) {
            $found_it = 1;
            last;
        }
    }
    ok($found_it);
    $samefh->close;
}

sub clean_up : Test(shutdown) {
}

1;
