#!/usr/bin/env perl

# This plugin does not maintain it's state.
use utf8;
use Time::Local;
use Mojo::UserAgent;
use JSON::XS;
use Date::Parse;
use HTTP::Cookies;
use XML::Simple;
use Weather::Underground;

# hardcode!
my $pub_user = 'devinfo';
my $pub_pass = '';
my $aca_auth_url = "https://meritcommons.wayne.edu/auth";
my $aca_myws_url = "https://meritcommons.wayne.edu/myws";

#my $aca_auth_url = "http://meritcommons-dev.wayne.edu:3000/auth";
#my $aca_websocket_url = "ws://meritcommons-dev.wayne.edu:3000/hydrant";

# releases.
my $releases = {
    January => '12/20/13',
    February => '01/31/14',
    March => '02/28/14',
    April => '03/28/14',
    May => '04/25/14',
    June => '05/30/14',
    July => '06/27/14',
    August => '07/25/14',
};

my ($epoch_rev_rel, $epoch_rel) = ({}, {});

foreach my $key (keys %$releases) {
    my ($m, $d, $y) = split(/\//, $releases->{$key});
    my $time = timelocal(0, 0, 18, $d, $m - 1, $y + 100);
    $epoch_rev_rel->{$time} = $key;
    $epoch_rel->{$key} = $time;
}

my $json = new JSON::XS;
my $acua = Mojo::UserAgent->new();
$acua->post($aca_auth_url, form => {
        username => $pub_user,
        password => $pub_pass,
});

my $release = current_release();
my $days_remaining;
my $previous_phase;

print "[info]: devinfo startup refereeing MeritCommons $release\n";
my $aca_websocket_url = $acua->get($aca_myws_url)->res->body;
print "[info]: resolved websocket to $aca_websocket_url\n";

$acua->websocket($aca_websocket_url, sub {
    my ($ua, $tx) = @_;    
    $tx->on(finish => sub {
        my ($tx, $code, $reason) = @_;
        print "WebSocket closed with status $code.\n";
        exit();
    });

    my $send_msg = sub {
        my ($to_who, $in_reply_to) = @_;
        my $new_days_remaining = days_til_release();
        my $new_release = current_release();
        if (!$to_who && $new_release ne $release) {
            ### THIS IS A NEW RELEASE.
            my $message = "REJOICE!  New Release cycle begins for **MeritCommons $new_release** " . 
                          "releasing _$releases->{$new_release}_!  Feel free to hack on the " . 
                          "codebase as we're back to Phase 1!";

            ### SEND IT!
            $tx->send({ text => "inbound " . $json->encode({
                stream => ["MeritCommons Developers"],
                render_as => "generic",
                public => 1,
                in_reply_to => $in_reply_to ? $in_reply_to : undef,
                body => $message,
            })});
        } elsif (!$to_who && $new_days_remaining != $days_remaining) {
            ### THIS IS A NEW DAY.

            # get phase.
            my ($phase, $phase_rules) = get_phase();

            my $message;
            if (!$previous_phase || ($previous_phase < $phase)) {
                $message = "PHASE **$phase** OF **MeritCommons $new_release** DEVELOPMENT IS UPON US!  Remember phase **$phase** rules; *$phase_rules*";
            } else {
                $message = "This is your friendly DevInfo bot with a helpful reminder that you are an " .
                           "MeritCommons developer, and that we are in phase **$phase** of release **MeritCommons $new_release** which means you have to " . 
                           "remember to follow these rules; *$phase_rules*  Now you know!  And knowing is... ";
            }

            ### SEND IT!
            $tx->send({ text => "inbound " . $json->encode({
                stream => ["MeritCommons Developers"],
                render_as => "generic",
                public => 1,
                in_reply_to => $in_reply_to ? $in_reply_to : undef,
                body => $message,
            })});
        } else {
            my ($phase, $phase_rules) = get_phase();
            my $message = $to_who ? "$to_who, " : '';
            $message .= "CURRENT RELEASE: **MeritCommons $new_release** in phase **$phase**.  Remember the " .
                        "rules; *$phase_rules* p.s. we release " . days_til_release_wordy() . " ($releases->{$new_release})";
            
            ### OFF WE GO            
            $tx->send({ text => "inbound " . $json->encode({
                stream => ["MeritCommons Developers"],
                render_as => "generic",
                public => 1,
                in_reply_to => $in_reply_to ? $in_reply_to : undef,
                body => $message,
            })});
        }
        $release = $new_release;
        $days_remaining = $new_days_remaining;
    };

    $tx->on(message => sub {
        my ($tx, $msg) = @_;
        my $hr = $json->decode($msg);
        if (exists($hr->{sent})) {
            print "[info]: added message $hr->{sent}->[0]->{message_id}\n";
        } elsif ($hr->{original_body} =~ /^\+(\w+)\s*([\w\s\@]*)$/) {
            # this is a bot command!
            my $command = $1;
            my $args = $2;

            if ($command eq "phaseinfo") {
                $send_msg->($hr->{submitter_common_name}, $hr->{message_id});
            } elsif ($command eq "weather") {
                $args =~ s/\@DevInfo//gi;
                # default to Detroit.
                $args = "48202" unless $args;
                my $weather = Weather::Underground->new( place => "$args" );
                my $whr = $weather->getweather()->[0];

                $tx->send({ text => "inbound " . $json->encode({
                    stream => ["MeritCommons Developers"],
                    render_as => "generic",
                    in_reply_to => $hr->{message_id},
                    public => 1,
                    body => <<"EOF"
### $whr->{place} Weather
$whr->{temperature_fahrenheit}F, $whr->{humidity}% humidity.
Windspeed $whr->{wind_milesperhour} out of the $whr->{wind_direction}.
EOF
                })});
            } elsif ($command eq "megainfo") {
                $tx->send({ text => "inbound " . $json->encode({
                    stream => ["MeritCommons Developers"],
                    render_as => "generic",
                    in_reply_to => $hr->{message_id},
                    public => 1,
                    body => "# MEGATHREAD\n## MEGATHREAD\n### MEGA-THREAD!!!!!!",
                })});
            } elsif ($command eq "attabot") {
                $tx->send({ text => "inbound " . $json->encode({
                    stream => ["MeritCommons Developers"],
                    render_as => "generic",
                    in_reply_to => $hr->{message_id},
                    public => 1,
                    body => ":)",
                })});
            }
        }
    });

    Mojo::IOLoop->recurring(5 => sub {
        unless ($tx->can('send')) {
            print "[info]: no web socket, exiting.\n";
            exit();
        }
        $tx->send("ping hello");
    });

    #Mojo::IOLoop->recurring(60 => sub {
    #    my @tc = localtime;

    #    if ($tc[1] == 0) {
    #        # send the message at 7am, noon, 4pm, and 8pm.
    #        if ($tc[2] == 7 || $tc[2] == 12 || $tc[2] == 16 || $tc[2] == 20) {
    #            $send_msg->();
    #        }
    #    }
    #});

    $tx->send("subscribe MeritCommons Developers");
    $tx->send("subscribe _devinfo");
});

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

sub current_release {
    my $last_key;
    foreach my $key (sort {$a <=> $b} keys %$epoch_rev_rel) {
        if ($last_key) {
            if (time > $last_key && time < $key) {
                return $epoch_rev_rel->{$key};
            }
        } else {
            if (time < $key) {
                return $epoch_rev_rel->{$key};
            }
        }
        $last_key = $key;
    }
}

sub days_til_release {
    my $cr = current_release();
    my $release_epoch = $epoch_rel->{$cr};
    my $secs_remaining = $release_epoch - time;
    my $days = int($secs_remaining / 60 / 60 / 24);

    return $days;
}

sub days_til_release_wordy {
    my $cr = current_release();
    my $release_epoch = $epoch_rel->{$cr};
    my $secs_remaining = $release_epoch - time;
    my $days = int($secs_remaining / 60 / 60 / 24);

    if ($days < 1) {
        return "TODAY";
    } elsif ($days == 1) {
        return "TOMORROW";
    } elsif ($days == 2) {
        return "THE DAY AFTER TOMORROW";
    } else {
        return "in $days days";
    }
}

sub get_phase {
    my $days_remaining = days_til_release();
    my $release = current_release();
    my ($phase, $phase_rules);
    if ($days_remaining < 2) {
        $phase = 4;
        $phase_rules = "Emergency bugfixes and release preparation only!";
    } elsif ($days_remaining < 14) {
        $phase = 3;
        $phase_rules = "Every commit needs to reference a ticket!";
    } elsif ($days_remaining < 21) {
        $phase = 2;
        $phase_rules = "Anything goes cont.  Whatever code is left in trunk/ at the end of this week will make it into MeritCommons $release";
    } else {
        $phase = 1;
        $phase_rules = "Anything goes.  Merge your branches, go to town.";
    }

    return ($phase, $phase_rules);
}
