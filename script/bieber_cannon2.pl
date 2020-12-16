#!/usr/bin/env perl

# The Bieber Cannon [What's Hot Edition]
# (c) 2015 Michael Gregorowicz

use utf8;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::JSON qw/ encode_json decode_json to_json /;
use Date::Parse;
use UUID::Tiny;
use AnyEvent::Twitter::Stream;

# meritcommons credentials
my $pub_user = 'tweetie'; # the MeritCommons user to authenticate and post as
my $pub_pass = ''; # that user's password

# You should only need to set what's in this constructor
my $aca_base = Mojo::URL->new('https://meritcommons.merit.edu');
my $aca_auth_url = $aca_base->clone->path("/auth"); 
my $aca_websocket_url = $aca_base->scheme eq "https"  ? 
    $aca_base->clone->scheme('wss')->path('/hydrant') : # https => wss
    $aca_base->clone->scheme('ws')->path('/hydrant'); # http => ws

# twitter credentials
my $tw_consumer_key = '';
my $tw_consumer_secret = '';
my $tw_token = '';
my $tw_token_secret = '';

# what to filter on Twitter
my $track = "#MMC2015,#WayneState,#MeritCommons,#Merit,#MCRCon";

# where to put messages on MeritCommons, streams must exist
my $streams = ["MMC2015", "MMCTweets"];

# annnd away we go!
my $acua = Mojo::UserAgent->new();
$acua->post($aca_auth_url->to_string, { Referer => "$aca_base" } => form => {
    username => $pub_user,
    password => $pub_pass,
});

# scope this here.
my $cv = AE::cv;

$acua->websocket($aca_websocket_url->to_string, sub {
    my ($ua, $tx) = @_;    

    my $submitted = 0;

    $tx->on(finish => sub {
        my ($tx, $code, $reason) = @_;
        print "[finish]: WebSocket closed with status $code" . ($reason  ? " ($reason)\n" : "\n");
        exit();
    });

    $tx->on(message => sub {
        my ($tx, $msg) = @_;
        my $hr = decode_json($msg);
        if (ref($hr) eq "HASH") {
            $hr = decode_json($hr->{body});
        }
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
        track => $track,
        #method => 'firehose',
        on_tweet => sub {
            my ($tweet) = @_;
            my $this_resp = $tx->send({
                text => create_UUID_as_string(UUID_V4) . " inbound " . encode_json({
                    stream => $streams,
                    render_as => "twitter",
                    serialized_payload => to_json($tweet),
                    body => $tweet->{text},
                    public => 1,
                    serialized => 1,
                }),
            });
            ++$submitted;
            #print "[debug]: ding, $submitted\n";
            Mojo::IOLoop->one_tick;
            Mojo::IOLoop->one_tick;
        }, 
        on_error => sub {
            my ($error) = @_;
            warn "Twitter error: $error\n";
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
