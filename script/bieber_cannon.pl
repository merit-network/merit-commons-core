#!/usr/bin/env perl

# This plugin does not maintain it's state.
use utf8;
use Mojo::UserAgent;
use Mojo::JSON qw/encode_json/;
use Date::Parse;
use HTTP::Cookies;
use AnyEvent::Twitter::Stream;

# hardcode!
my $pub_user = 'tweetie';
my $pub_pass = '';
my $aca_auth_url = "https://meritcommons.wayne.edu/auth";
my $aca_pub_url = "https://meritcommons.wayne.edu/inbound";
my $tw_consumer_key = '';
my $tw_consumer_secret = '';
my $tw_token = '';
my $tw_token_secret = '';

my $acua = Mojo::UserAgent->new();
$acua->post($aca_auth_url, form => {
        username => $pub_user,
        password => $pub_pass,
});

my $done = AE::cv;

my $start_time = time;
my $submitted = 0;

my $filter = AnyEvent::Twitter::Stream->new(
    consumer_key => $tw_consumer_key,
    consumer_secret => $tw_consumer_secret,
    token => $tw_token,
    token_secret => $tw_token_secret,
    method => 'filter',
    track => 'Pinterest,Bieber,#Detroit,#WayneState,#Michigan,#freshmanadvice,#io13',
    on_tweet => sub {
        my ($tweet) = @_;
        my $this_resp = $acua->post($aca_pub_url, form => {
            stream => "Twitter", 
            render_as => "twitter",
            body => encode_json($tweet),
            public => 1,
            serialized => 1,
        });
    }, 
    on_error => sub {
        my ($error) = @_;
        warn "ERROR: $error\n";
        $done->send;
    },
    on_eof => sub {
        warn "Exiting..\n";
        $done->send;
    },
);

$done->recv;
