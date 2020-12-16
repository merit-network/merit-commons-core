package MeritCommons::Test::StreamModeration;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
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
my $username2 = 'testusertwo';
my $password2 = 'testpasstwo';

sub make_meritcommons : Test(startup => 2) {
    my $self      = shift;
    my $t         = MeritCommons::Test->new();
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
    $new_local_user_cmd1->run($username2, 'Test UserTwo', $password2);
    my $user2 = $meritcommons->m->resultset('User')->search(
        {
            userid => $username2,
        }
    )->single;

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
    $self->{user1}     = $user1;
    $self->{user2}     = $user2;
}

sub _login {    # Does 12 tests
    my $self     = shift;
    my $t        = $self->{t};
    my $username = shift || $username1;
    my $password = shift || $password1;

    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => $username, password => $password })->status_is(200)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');
    $t->get_ok('/')->status_is(200)->element_exists('html body meta', 'Looking for meta refresh');
    my $location = (split("'", (split(';', $t->tx->res->dom->find('html body meta')->[0]->attr('content')))[1]))[1];
    $t->get_ok($location)->status_is(302)->header_is('location' => $t->app->url_for('/'));
    $t->get_ok('/')->status_is(200)->element_exists('html body div#inbound', 'Looking for inbound div');
}

sub _logout {    # Does 3 tests
    my $self = shift;
    my $t    = $self->{t};

    # Check logout
    $t->get_ok('/auth' => form => { logout => 1 })->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query([ logout => undef ])->to_string);
}

sub test_initial_render : Test(no_plan) {
    my $self = shift;
    my $t    = $self->{t};

    my $streamname1 = 'teststreamone';

    # Not logged in
    $t->get_ok('/s/' . $streamname1 . '/m')->status_is(404);

    # login
    $self->_login;

    # A not real stream
    $t->get_ok('/s/somethingelse/m')->status_is(404);

    # Multiple streams not allowed
    $t->get_ok('/s/' . $streamname1 . ',somethingelse/m')->status_is(404);

    # Successful creations
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

    # Get new stream unique_id for testing purposes
    my $stream_unique_id = $self->{meritcommons}->stream($streamname1)->unique_id;

    $t->get_ok('/s/' . $streamname1 . '/m')->status_is(200)
      ->element_exists('html body div[data-stream-id="' . $stream_unique_id . '"]', 'Looking for moderation div');

    my @mods = $self->{meritcommons}->m->resultset('Stream::Moderator')->search(
        {
            'stream.unique_id' => $stream_unique_id
        },
        {
            join => 'stream'
        }
    );
    is(scalar(@mods), 1, 'number of mods for new stream');

    my @subs = $self->{meritcommons}->m->resultset('Stream::Subscriber')->search(
        {
            'stream.unique_id' => $stream_unique_id
        },
        {
            join => 'stream'
        }
    );
    is(scalar(@subs), 1, 'number of subs for new stream');

    my @auts = $self->{meritcommons}->m->resultset('Stream::Author')->search(
        {
            'stream.unique_id' => $stream_unique_id
        },
        {
            join => 'stream'
        }
    );
    is(scalar(@auts), 1, 'number of auts for new stream');

    # logout
    $self->_logout;

    # login
    $self->_login($username2, $password2);

    $t->get_ok('/s/' . $streamname1 . '/m')->status_is(404);

}

sub test_initial_render_personal_inbox : Test(15) {
    my $self = shift;
    my $t    = $self->{t};

    # login
    $self->_login;

    # Get new stream unique_id for testing purposes
    my $stream_unique_id = $self->{meritcommons}->stream('_' . $username1)->unique_id;

    $t->get_ok('/s/You/m')->status_is(200)
      ->element_exists('html body div[data-stream-id="' . $stream_unique_id . '"]', 'Looking for moderation div');

}

sub test_websocket_permissions : Test(no_plan) {
    my $self = shift;
    my $t    = $self->{t};

    my $streamname1 = 'teststreamonews';

    # Not logged in
    $t->get_ok('/s/' . $streamname1 . '/m')->status_is(404);

    $self->_login;

    # Successful creations
    $t->post_ok(
        '/s/' .
          $streamname1 => form => {
            url_name            => 'test1ws',
            badge_name          => 'tst1ws',
            description         => 'A websocket test stream.',
            keywords            => 'keywordone',
            show_publicly       => 1,
            display_subscribers => 0,
          }
    )->status_is(302)->header_is('location' => $t->app->url_for('/s/' . $streamname1));

    # Get new stream unique_id for testing purposes
    my $stream_unique_id = $self->{meritcommons}->stream($streamname1)->unique_id;

    $t->get_ok('/s/' . $streamname1 . '/m')->status_is(200)
      ->element_exists('html body div[data-stream-id="' . $stream_unique_id . '"]', 'Looking for moderation div');

    # Websocket
    $t->websocket_ok('/hydrant');

    # Subscribers
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'subscribers' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    my $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype sub');
    is($payload->{render_as}, 'info', 'default render_as sub');
    my $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number sub');
    is($body->{type},                     'subscribers',     'ws response type sub');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id sub');
    is(scalar(@{ $body->{permissions} }), 1,                 'ws response permissions count sub');
    my $permission = $body->{permissions}->[0];
    is($permission->{meritcommons_user}->{unique_id}, $self->{user1}->unique_id, 'ws response user unique id sub');

    # Authors
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'authors' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype aut');
    is($payload->{render_as}, 'info', 'default render_as aut');
    $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number aut');
    is($body->{type},                     'authors',         'ws response type aut');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id aut');
    is(scalar(@{ $body->{permissions} }), 1,                 'ws response permissions count aut');
    $permission = $body->{permissions}->[0];
    is($permission->{meritcommons_user}->{unique_id}, $self->{user1}->unique_id, 'ws response user unique id aut');

    # Moderators
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'moderators' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype mod');
    is($payload->{render_as}, 'info', 'default render_as mod');
    $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number mod');
    is($body->{type},                     'moderators',      'ws response type mod');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id mod');
    is(scalar(@{ $body->{permissions} }), 1,                 'ws response permissions count mod');
    $permission = $body->{permissions}->[0];
    is($permission->{meritcommons_user}->{unique_id}, $self->{user1}->unique_id, 'ws response user unique id mod');

    $t->finish_ok;

    $self->_logout;

    # login user without moderatorship
    $self->_login($username2, $password2);

    $t->websocket_ok('/hydrant');

    # Subscribers
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'subscribers' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype sub');
    is($payload->{render_as}, 'info', 'default render_as sub');
    $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number sub');
    is($body->{type},                     'subscribers',     'ws response type sub');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id sub');
    is(scalar(@{ $body->{permissions} }), 0,                 'not allowed ws response permissions count sub');

    # Authors
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'authors' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype aut');
    is($payload->{render_as}, 'info', 'default render_as aut');
    $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number aut');
    is($body->{type},                     'authors',         'ws response type aut');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id aut');
    is(scalar(@{ $body->{permissions} }), 0,                 'not allowed ws response permissions count aut');

    # Moderators
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'moderators' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype mod');
    is($payload->{render_as}, 'info', 'default render_as mod');
    $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number mod');
    is($body->{type},                     'moderators',      'ws response type mod');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id mod');
    is(scalar(@{ $body->{permissions} }), 0,                 'not allowed ws response permissions count mod');

    $t->finish_ok;

    $self->_logout;
}

sub test_websocket_supermod_permissions : Test(79) {
    my $self = shift;
    my $t    = $self->{t};

    my $streamname2 = 'teststreamtwows';

    # Not logged in
    $t->get_ok('/s/' . $streamname2 . '/m')->status_is(404);

    $self->_login;

    # Successful creations
    $t->post_ok(
        '/s/' .
          $streamname2 => form => {
            url_name            => 'test2ws',
            badge_name          => 'tst2ws',
            description         => 'A websocket test stream.',
            keywords            => 'keywordone',
            show_publicly       => 1,
            display_subscribers => 0,
          }
    )->status_is(302)->header_is('location' => $t->app->url_for('/s/' . $streamname2));

    # Get new stream unique_id for testing purposes
    my $stream_unique_id = $self->{meritcommons}->stream($streamname2)->unique_id;

    $t->get_ok('/s/' . $streamname2 . '/m')->status_is(200)
      ->element_exists('html body div[data-stream-id="' . $stream_unique_id . '"]', 'Looking for moderation div');

    # Websocket
    $t->websocket_ok('/hydrant');

    # Give mod (not supermod) to $username2
    $t->send_ok(
        $t->app->new_uuid . ' change_stream_permission ' . $t->app->json_encode(
            {
                what                 => 'moderatorship',
                user_id              => $username2,
                add_other_moderators => 0,                   # not supermod
                action               => 'add',
                streamId             => $stream_unique_id,
            }
        )
    );
    $t->message_ok;
    $t->finish_ok;

    $self->_logout;

    # login user without moderatorship
    $self->_login($username2, $password2);

    $t->websocket_ok('/hydrant');

    # Subscribers
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'subscription' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    my $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype sub');
    is($payload->{render_as}, 'info', 'default render_as sub');
    my $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number sub');
    is($body->{type},                     'subscribers',     'ws response type sub');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id sub');
    is(scalar(@{ $body->{permissions} }), 1,                 'ws response permissions count sub');
    my $permission = $body->{permissions}->[0];
    is($permission->{meritcommons_user}->{unique_id}, $self->{user1}->unique_id, 'ws response user unique id sub');

    # Authors
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'authorship' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype aut');
    is($payload->{render_as}, 'info', 'default render_as aut');
    $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number aut');
    is($body->{type},                     'authors',         'ws response type aut');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id aut');
    is(scalar(@{ $body->{permissions} }), 1,                 'ws response permissions count aut');
    $permission = $body->{permissions}->[0];
    is($permission->{meritcommons_user}->{unique_id}, $self->{user1}->unique_id, 'ws response user unique id aut');

    # Moderators - can't see any!
    $t->send_ok($t->app->new_uuid . ' get_moderation_page {' .
          '"streamId": "' . $stream_unique_id . '",' . '"type": "' . 'moderatorship' . '",' . '"page": ' . '1' . '}');
    $t->message_ok;
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    is($payload->{ws_msgtype}, 'permission_page:fetched', 'default msgtype mod');
    is($payload->{render_as}, 'info', 'default render_as mod');
    $body = $t->app->json_decode($payload->{body});
    is($body->{page},                     1,                 'ws response page number mod');
    is($body->{type},                     'moderators',      'ws response type mod');
    is($body->{streamId},                 $stream_unique_id, 'ws response stream unique id mod');
    is(scalar(@{ $body->{permissions} }), 0,                 'not allowed ws response permissions count mod');

    $t->finish_ok;

    $self->_logout;
}

sub test_websocket_cover_websocket_server_side_add_permission : Test(61) {
    my $self = shift;
    my $t    = $self->{t};

    my $streamname3 = 'teststreamthreews';

    # Not logged in
    $t->get_ok('/s/' . $streamname3 . '/m')->status_is(404);

    $self->_login;

    # Successful creations
    $t->post_ok(
        '/s/' .
          $streamname3 => form => {
            url_name            => 'test3ws',
            badge_name          => 'tst3ws',
            description         => 'A websocket test stream.',
            keywords            => 'keywordone',
            show_publicly       => 1,
            display_subscribers => 0,
          }
    )->status_is(302)->header_is('location' => $t->app->url_for('/s/' . $streamname3));

    # Get new stream unique_id for testing purposes
    my $stream_unique_id = $self->{meritcommons}->stream($streamname3)->unique_id;

    $t->get_ok('/s/' . $streamname3 . '/m')->status_is(200)
      ->element_exists('html body div[data-stream-id="' . $stream_unique_id . '"]', 'Looking for moderation div');

    # Websocket
    $t->websocket_ok('/hydrant');

    # Give aut to $username2
    $t->send_ok(
        $t->app->new_uuid . ' change_stream_permission ' .
          $t->app->json_encode(
            {
                what     => 'authorship',
                user_id  => $username2,
                action   => 'add',
                streamId => $stream_unique_id,
            }
          )
    );
    $t->message_ok;
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    my $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    is($payload->{ws_msgtype}, 'author:added', 'default msgtype add aut');
    is($payload->{render_as},  'info',         'default render_as add aut');
    my $body = $t->app->json_decode($payload->{body});
    is($body->{stream_id},        $stream_unique_id,           'ws response stream unique id add aut');
    is($body->{user_unique_id},   $self->{user2}->unique_id,   'ws response user unique id add aut');
    is($body->{user_common_name}, $self->{user2}->common_name, 'ws response user common name add aut');

    # Give mod to $username2
    $t->send_ok(
        $t->app->new_uuid . ' change_stream_permission ' . $t->app->json_encode(
            {
                what                 => 'moderatorship',
                user_id              => $username2,
                add_other_moderators => 1,                   # supermod
                action               => 'add',
                streamId             => $stream_unique_id,
            }
        )
    );

    # Two messages are going to come back at us from the websocket
    # One of these will be for the more_than_one_supermod
    # The other will be the moderator add response
    # Let's not assume an order for them, even though the more_than_one_supermod should come first
    my $last_msgtype = '';
    for (my $i = 0 ; $i < 2 ; $i++) {    # We expect two messages
        $t->message_ok;
        $t->json_message_has('/ws_msgtype');
        $t->json_message_has('/render_as');
        $t->json_message_has('/body');
        $payload = $self->{meritcommons}->json_decode($t->message->[1]);
        is($payload->{render_as}, 'info', 'default render_as add mod');
        $body = $t->app->json_decode($payload->{body});
        isnt($payload->{ws_msgtype}, $last_msgtype, 'ws response no repeat add mod');
        $last_msgtype = $payload->{ws_msgtype};

        if ($payload->{ws_msgtype} eq 'moderator:more_than_one_supermod') {
            is(
                $body->{active_user_id},
                $self->{user1}->unique_id,
                'ws response active user unique id > 1 supermod add mod'
            );
            is($body->{stream_id}, $stream_unique_id, 'ws response stream id > 1 supermod add mod');
        } elsif ($payload->{ws_msgtype} eq 'moderator:added') {
            is($body->{stream_id},           $stream_unique_id,           'ws response stream unique id add mod');
            is($body->{user_unique_id},      $self->{user2}->unique_id,   'ws response user unique id add mod');
            is($body->{user_common_name},    $self->{user2}->common_name, 'ws response user common name add mod');
            is($body->{me},                  Mojo::JSON::false,           'ws response me add mod');
            is($body->{allow_add_moderator}, Mojo::JSON::true,            'ws response allow_add_moderator add mod');
        } else {
            ok(0, 'ws response bad msgtype add mod');    # Fail
        }
    }

    # Try to give sub to $username2 - won't work
    $t->send_ok(
        $t->app->new_uuid . ' change_stream_permission ' . $t->app->json_encode(
            {
                what                 => 'subscription',
                user_id              => $username2,
                add_other_moderators => 1,                   # supermod
                action               => 'add',
                streamId             => $stream_unique_id,
            }
        )
    );
    $t->message_ok;
    $t->json_message_has('/ws_msgtype');
    $t->json_message_has('/render_as');
    $t->json_message_has('/body');
    $payload = $self->{meritcommons}->json_decode($t->message->[1]);
    is($payload->{ws_msgtype}, 'cmdresponse:success', 'default msgtype add sub');
    is($payload->{render_as},  'info',                'default render_as add sub');
    is($payload->{body},       undef,                 'default body add sub');

    # Check that the subscription didn't get added to the database
    is(
        $self->{meritcommons}->m->resultset('Stream::Subscriber')->count(
            {
                'meritcommons_user.id' => $self->{user2}->id,
                'stream.unique_id'  => $stream_unique_id,
            },
            {
                join => [ 'meritcommons_user', 'stream' ],
            }
        ),
        0,
        'database check add sub'
    );

    $t->finish_ok;
}

sub clean_up : Test(shutdown) {
}

1;
