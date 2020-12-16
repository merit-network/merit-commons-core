package MeritCommons::Test::StreamCreation;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
use MeritCommons;
use MeritCommons::Test;
use File::Temp;

use Mojo::JSON qw/encode_json/;
use Mojo::URL;
use Mojo::Util qw(url_escape);
use Mojolicious::Commands;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;

my $username1 = 'testuserone';
my $password1 = 'testpassone';

sub make_meritcommons : Test(startup => 2) {
    $MeritCommons::config_file = '%test-configs%/meritcommons.streamcreation.conf';

    my $self      = shift;
    my $t         = MeritCommons::Test->new('MeritCommons');
    my $meritcommons = $t->app;

    # Make our standard schema
    my $install_schema_cmd = MeritCommons::Command::install_schema->new;
    $install_schema_cmd->{app} = $meritcommons;
    $install_schema_cmd->run();

    # Check that it's really what we think it is
    my @users = $meritcommons->m->resultset('User')->all;
    cmp_ok(scalar(@users), '==', 1);    # Yes we have a new database
    my @messages = $meritcommons->m->resultset('Stream::Message')->all;
    cmp_ok(scalar(@messages), '==', 0);    # Yes we have a new database

    # Add test data
    my $new_local_user_cmd1 = MeritCommons::Command::new_local_user->new;
    $new_local_user_cmd1->{app} = $meritcommons;
    $new_local_user_cmd1->run($username1, 'Test UserOne', $password1);
    my $user1 = $meritcommons->m->resultset('User')->search(
        {
            userid => $username1,
        }
    )->single;

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
    $self->{user1}     = $user1;
}

sub _login {    # Does 12 tests
    my $self = shift;
    my $t    = $self->{t};

    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => $username1, password => $password1 })->status_is(200)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');
    $t->get_ok('/')->status_is(200)->element_exists('html body meta', 'Looking for meta refresh');
    my $location = (split("'", (split(';', $t->tx->res->dom->find('html body meta')->[0]->attr('content')))[1]))[1];
    $t->get_ok($location)->status_is(302)->header_is('location' => $t->app->url_for('/'));
    $t->get_ok('/')->status_is(200)->element_exists('html body div#inbound', 'Looking for inbound div');
}

sub test_create_stream : Test(36) {
    my $self = shift;
    my $t    = $self->{t};

    # login
    $self->_login;

    # Successful creations
    my $streamname1 = 'teststreamone';
    $t->post_ok(
        '/s/' .
          $streamname1 => form => {
            url_name            => 'test1',
            badge_name          => 'tst1',
            description         => 'A test stream.',
            keywords            => 'keywordone, two, three',
            show_publicly       => 1,
            display_subscribers => 0,
          }
    )->status_is(302)->header_is('location' => $t->app->url_for('/s/' . $streamname1));

    my $streamname2 = 'TestStreamTwo';
    $t->post_ok(
        '/s/' .
          $streamname2 => form => {
            url_name            => 'test2',
            badge_name          => 'tst2',
            description         => 'A test stream 2.',
            keywords            => 'two2',
            show_publicly       => 0,
            display_subscribers => 1,
          }
    )->status_is(302)->header_is('location' => $t->app->url_for('/s/' . $streamname2));

    # Failure - reusing url_name
    my $redirect_target_regex = $t->app->url_for('/s/') . $streamname1 . '\?data=([A-Za-z0-9]+)';
    $t->post_ok(
        '/s/' .
          $streamname1 => form => {
            url_name            => 'test1',
            badge_name          => 'tst1',
            description         => 'A test stream.',
            keywords            => 'keywordone, two, three',
            show_publicly       => 1,
            display_subscribers => 0,
          }
    )->status_is(302)->header_like('location' => qr/$redirect_target_regex/);

    # Failure - bad url_name
    my $bad_url_name    = 'Test2%';      # non-underscore symbols not allowed
    my $bad_stream_name = 'Testing 3';
    my $redirect_target_regex_symbol = $t->app->url_for('/s/') . url_escape($bad_stream_name) . '\?data=([A-Za-z0-9]+)';
    $t->post_ok(
        '/s/' .
          $bad_stream_name => form => {
            url_name            => $bad_url_name,
            badge_name          => 'tst3',
            description         => 'A test stream 3.',
            keywords            => 'keywordthree',
            show_publicly       => 0,
            display_subscribers => 1,
          }
    )->status_is(302)->header_like('location' => qr/$redirect_target_regex_symbol/);

    # Failure - missing url_name
    my $missing_url_stream_name = 'Testing 3';
    my $redirect_target_regex_missing_url =
      $t->app->url_for('/s/') . url_escape($missing_url_stream_name) . '\?data=([A-Za-z0-9]+)';
    $t->post_ok(
        '/s/' .
          $missing_url_stream_name => form => {
            badge_name          => 'tst3',
            description         => 'A test stream 3.',
            keywords            => 'keywordthree',
            show_publicly       => 0,
            display_subscribers => 1,
          }
    )->status_is(302)->header_like('location' => qr/$redirect_target_regex_missing_url/);

    # Failure - reserved stream name - string compare
    my $reserved1_url_name    = 'resone';
    my $reserved1_stream_name = 'reserved stream one';
    my $redirect_target_regex_reserved1 =
      $t->app->url_for('/s/') . url_escape($reserved1_stream_name) . '\?data=([A-Za-z0-9]+)';
    $t->post_ok(
        '/s/' .
          $reserved1_stream_name => form => {
            url_name            => $reserved1_url_name,
            badge_name          => 'tst4',
            description         => 'A test stream 4.',
            keywords            => 'keywordfour',
            show_publicly       => 0,
            display_subscribers => 1,
          }
    )->status_is(302)->header_like('location' => qr/$redirect_target_regex_reserved1/);

    # Failure - reserved stream name - regex compare
    my $reserved2_url_name    = 'restwo';
    my $reserved2_stream_name = 'testreservediopwerowrtjklwerkltweu9pw5723490p4';
    my $redirect_target_regex_reserved2 =
      $t->app->url_for('/s/') . url_escape($reserved2_stream_name) . '\?data=([A-Za-z0-9]+)';
    $t->post_ok(
        '/s/' .
          $reserved2_stream_name => form => {
            url_name            => $reserved2_url_name,
            badge_name          => 'tst5',
            description         => 'A test stream 5.',
            keywords            => 'keywordfive',
            show_publicly       => 0,
            display_subscribers => 1,
          }
    )->status_is(302)->header_like('location' => qr/$redirect_target_regex_reserved2/);

    # Failure - starting with underscore
    my $reserved3_url_name    = 'resunderscore';
    my $reserved3_stream_name = '_somethingorother';
    my $redirect_target_regex_reserved3 =
      $t->app->url_for('/s/') . url_escape($reserved3_stream_name) . '\?data=([A-Za-z0-9]+)';
    $t->post_ok(
        '/s/' .
          $reserved3_stream_name => form => {
            url_name            => $reserved3_url_name,
            badge_name          => 'tst6',
            description         => 'A test stream 6.',
            keywords            => 'keywordfive',
            show_publicly       => 0,
            display_subscribers => 1,
          }
    )->status_is(302)->header_like('location' => qr/$redirect_target_regex_reserved3/);

    # Not fully covered
}

sub clean_up : Test(shutdown) {
}

1;
