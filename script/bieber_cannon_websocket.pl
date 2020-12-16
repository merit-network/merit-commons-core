#!/usr/bin/env perl

# This plugin does not maintain it's state.
use utf8;
use Mojo::UserAgent;
use Mojo::JSON qw/encode_json decode_json/;
use Date::Parse;
use AnyEvent::Twitter::Stream;

# hardcode!
my $pub_user = 'tweetie';
my $pub_pass = '';
my $aca_auth_url = "https://acappdev.cctest.wayne.edu/auth";
my $aca_websocket_url = "wss://acappdev.cctest.wayne.edu/hydrant";
my $tw_consumer_key = '';
my $tw_consumer_secret = '';
my $tw_token = '';
my $tw_token_secret = '';
my $acua = Mojo::UserAgent->new();
$acua->post($aca_auth_url, form => {
        username => $pub_user,
        password => $pub_pass,
});

# scope this here.
my $cv = AE::cv;

$acua->websocket($aca_websocket_url, sub {
    my ($ua, $tx) = @_;    

    my $submitted = 0;

    $tx->on(finish => sub {
        my ($tx, $code, $reason) = @_;
        print "WebSocket closed with status $code.\n";
    });

    $tx->on(message => sub {
        my ($tx, $msg) = @_;
        my $hr = decode_json($msg);
        if ($hr->{sent}->[0]->{message_id}) {
            print "[info]: added message $hr->{sent}->[0]->{message_id} ($submitted submitted)\n";
        } else {
            $submitted--;
        }
    });

    my $start_time = time;

    my $filter = AnyEvent::Twitter::Stream->new(
        consumer_key => $tw_consumer_key,
        consumer_secret => $tw_consumer_secret,
        token => $tw_token,
        token_secret => $tw_token_secret,
        method => 'filter',
        track => 'Pinterest,Bieber,#Detroit,#WayneState,#Michigan,#freshmanadvice,#io13',
        #method => 'firehose',
        on_tweet => sub {
            my ($tweet) = @_;
            my $this_resp = $tx->send({text => "inbound " . encode_json({
                stream => ["Twitter"],
                render_as => "twitter",
                serialized_payload => encode_json($tweet),
                body => $tweet->{text},
                public => 1,
                serialized => 1,
            })});
            ++$submitted;
            #print "[debug]: ding, $submitted\n";
            Mojo::IOLoop->one_tick;
            Mojo::IOLoop->one_tick;
        }, 
        on_error => sub {
            my ($error) = @_;
            warn "ERROR: $error\n";
            $cv->send;
        },
        on_eof => sub {
            warn "Exiting..\n";
            $cv->send;
        },
    );

    $cv->recv;
});

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
