#!/usr/bin/env perl

# This plugin does not maintain it's state.
use utf8;
use Time::HiRes qw/time/;
use Time::Local;
use Mojo::UserAgent;
use JSON::XS;

# hardcode!
my $pub_user = '';
my $pub_pass = '';

unless ($pub_user && $pub_pass) {
    local $| = 1;
    print "No Login & Password configured, please log in.\n";

    print "User: ";
    chomp ($pub_user = <STDIN>);

    print "Password: ";
    chomp ($pub_pass = <STDIN>);
}

my $identity_server_url = "https://meritcommons.wayne.edu";
my $aca_auth_url = "$identity_server_url/auth";
my $aca_myws_url = "$identity_server_url/myws";

my $json = new JSON::XS;

# non-blocking user agent
my $nbua = Mojo::UserAgent->new();
$nbua->post($aca_auth_url, {Referer => $identity_server_url} => form => {
        username => $pub_user,
        password => $pub_pass,
});

# blocking user agent.
my $bua = Mojo::UserAgent->new();
$bua->post($aca_auth_url, {Referer => $identity_server_url} => form => {
    username => $pub_user,
    password => $pub_pass,
});


print "[info]: starting $ARGV[0] websocket connections... \n";

my $coverage = {};
my ($start_time);

my $listening = 0;
for (my $i = 1; $i <= $ARGV[0]; $i++) {
    my $aca_websocket_url = $bua->get($aca_myws_url)->res->body;
    print "[info] connection #$i to $aca_websocket_url\n";
    my $string = "$i";
    my $done = 0;

    $nbua->websocket($aca_websocket_url, sub {
        my ($ua, $tx) = @_;    

        $tx->on(finish => sub {
            my ($tx, $code, $reason) = @_;
            print "[bye] WebSocket #$string closed with status $code.\n";
            $listening--;
        });
    
        $tx->on(message => sub {
            my ($tx, $msg) = @_;
            my $hr = $json->decode($msg);
            if ($hr->{ws_msgtype} eq "cmdresponse:error") {
                print "[$string] error: $hr->{body}\n";
            } elsif (!($hr->{ws_msgtype} eq "cmdresponse:success")) {
                print "[$string] message received '" . $hr->{original_body} . "' bytes (" . $hr->{message_id} . ")\n";
                $coverage->{$string}++;
                if (scalar(keys %$coverage) == 1) {
                    $start_time = time;
                } elsif (scalar(keys %$coverage) == $listening) {
                    my $time_taken = sprintf("%.04f", time - $start_time);
                    print "[info]: message $hr->{message_id} has complete coverage ($listening of $listening delivered) in $time_taken seconds\n";
                    $coverage = {};
                    $start_time = undef;
                }
            }
        });
    
        #Mojo::IOLoop->recurring(30 => sub {
        #    if ($tx->can('send')) {
        #        $tx->send("ping hello");
        #    } else {
        #        print "[info]: connection $string went away, finishing.\n";
        #    }
        #});

        if ($tx->is_websocket) {
            $listening++;
            $tx->send("subscribe WebSocketTest");
            #$tx->send("subscribe Twitter");
        }
    });
}

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

