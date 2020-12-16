package MeritCommons::Test::Plugins;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
use MeritCommons::Test;
use File::Temp;
use Time::HiRes;

use Mojo::JSON qw/encode_json decode_json/;
use Mojo::URL;
use Mojo::Util qw(url_escape);
use Mojolicious::Commands;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;

my $username1 = 'justin';
my $password1 = 'abc123';
my $username2 = 'bailey';
my $password2 = 'lewlz';

sub hydrant_test : Test(no_plan) {
    my $self = shift;
    my $t    = $self->{t};

    my $streamname1 = 'teststreamonews';

    # Not logged in
    $t->get_ok('/s/' . $streamname1 . '/m')->status_is(404);

    $self->_login;

    # Websocket
    $t->websocket_ok('/hydrant');

    # ping and ping time
    my $txid = $t->app->new_uuid;
    $t->send_ok($txid . ' ping ' . Time::HiRes::time);
    $t->message_ok;
    my $payload = decode_json($t->message->[1]);
    my ($float) = $payload->{body} =~ /^pong ([\d\.]+)$/;
    ok((Time::HiRes::time - $float) < 1,        "hydrant ping time @{[Time::HiRes::time - $float]} seconds");
    ok($txid eq $payload->{hydrant_request_id}, "making sure we got the right hydrant_request_id for our ping");

    # hydrant inbound test setup
    my $user = $t->app->user($username1);
    isnt($user, undef, "does our user exist?");

    my $stream = $user->personal_outbox;
    isnt($stream, undef, "does our user have a personal_outbox stream");

    # use inbound to make a new message in this stream.
    $txid = $t->app->new_uuid;
    $t->send_ok(
        $txid . " inbound " .
          encode_json(
            {
                render_as => 'generic',
                body      => 'Tadashi is here!',
                stream    => [ $stream->unique_id ],
                public    => 1,
            }
          ),
        "submitting new message via websocket inbound"
    );
    $t->message_ok('got back response for websocket inbound');

    $payload = decode_json($t->message->[1]);
    my $body               = decode_json($payload->{body});
    my $created_message_id = $body->{sent}->[0]->{message_id};
    is($body->{success}, 1, "check that the inbound call succeeded");
    is($txid, $payload->{hydrant_request_id}, "checking hydrant_request_id for inbound call");
    isnt($created_message_id, undef, "verifying that the newly submitted message_id was specified by the response");

    # subscribe to our message
    $txid = $t->app->new_uuid;
    $t->send_ok($txid . " subscribe_to_messages " . encode_json({ messages => [$created_message_id] }),
        "subscribing to new message");

    # like our message (which will trigger a ZMQ update!)
    $txid = $t->app->new_uuid;
    $t->send_ok(
        $txid . " vote " .
          encode_json(
            {
                vote       => 1,
                message_id => $created_message_id,
            }
          ),
        "upvoting our message"
    );
    $t->message_ok("got back a response for our vote");
    $payload = decode_json($t->message->[1]);
    $body    = decode_json($payload->{body});
    is($txid,            $payload->{hydrant_request_id}, "got the correct hydrant_request_id for vote call");
    is($body->{success}, 1,                              "vote was successful");
    is($body->{upvote},  1,                              "vote was registered as an upvote");

    # the next message should be from zmq.
    $t->message_ok("got an updated message from our subscription");
    $payload = decode_json($t->message->[1]);
    $body    = decode_json($payload->{body});
    is($payload->{hydrant_request_id}, 0, "got 0 for hydrant_request_id on subscribed message");
    is($body->{score},                 1, "message correctly has a score of 1 after our upvote");
    is($body->{body}, "<p>Tadashi is here!</p>\n", "message has the same body as the body originally submitted");

    # test validation
    $txid = $t->app->new_uuid;
    $t->send_ok($txid . ' ping hi');
    $t->message_ok("got a response back from our ping");
    $payload = decode_json($t->message->[1]);
    is($payload->{ws_msgtype}, 'cmdresponse:error',
        "checking that poorly formatted ping generated a cmdresponse:error");
    ok($payload->{body} =~ /hydrant command 'ping' validation failed/, "checking for the failed validation error copy");
    $t->finish_ok;

    # some cleanup to prevent zmq errors
    my $daemon    = $t->ua->server->{server};
    my $nb_daemon = $t->ua->server->{nb_server};
    for my $d ($daemon, $nb_daemon) {
        $d->_remove($_) for keys %{ $_->{connections} || {} };
    }
}

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

sub clean_up : Test(shutdown) {
    my ($self) = @_;
    my $t = $self->{t};

    # cleanup one last time
    my $daemon    = $t->ua->server->{server};
    my $nb_daemon = $t->ua->server->{nb_server};
    for my $d ($daemon, $nb_daemon) {
        $d->_remove($_) for keys %{ $_->{connections} || {} };
        $d->ioloop->remove($_) for @{ $d->acceptors };
    }
    $t->ua->ioloop->one_tick;
}

1;
