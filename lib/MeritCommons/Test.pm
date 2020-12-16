package MeritCommons::Test;

use MeritCommons;
use MeritCommons::Model;
use Mojo::URL;
use ZMQ::LibZMQ3;
use Mojo::Base qw 'Test::Mojo';
use Selenium::Remote::Driver;
use DBD::Oracle;
use DBD::SQLite;
use Mojo::UserAgent;
use Mojo::UserAgent::Server;
use Mojo::IOLoop;
use Mojo::IOLoop::Server;
use Scalar::Util qw/weaken/;
use POSIX ":sys_wait_h";
use Time::HiRes;
use Mojo::File;
use Carp qw/croak/;

use utf8;

has [qw/selenium_config/];

BEGIN: {
    require Mojo::Util;
    require DBIx::Class::Migration;

    Mojo::Util::monkey_patch(
        'DBIx::Class::Migration',
        DEMOLISH => sub { },    # don't do a damn thing, FREW.. not a damn thing.
    );

    Mojo::Util::monkey_patch(
        'Mojo::UserAgent::Server',
        _restart => sub {
            my ($self, $full, $proto) = @_;
            delete @{$self}{qw(nb_port port)} if $full;

            $self->{proto} = $proto ||= 'http';

            # Blocking
            my $server = $self->{server} = Mojo::Server::Daemon->new(ioloop => Mojo::IOLoop->singleton, silent => 1);
            weaken $server->app($self->app)->{app};

            my $ip_addr = $self->{ip_addr} ? $self->{ip_addr} : '127.0.0.1';
            my $port = $self->{port} = $self->{port} ? $self->{port} : Mojo::IOLoop::Server->generate_port;
            $server->listen(["$proto://$ip_addr:$port"])->start;
            warn "[test] blocking url: " . Mojo::URL->new("$proto://$ip_addr:$self->{port}") . "\n" if $ENV{MERITCOMMONS_DEBUG};

            # Non-blocking
            $server = $self->{nb_server} = Mojo::Server::Daemon->new(silent => 1);

            weaken $server->app($self->app)->{app};
            $port = $self->{nb_port} = $self->{nb_port} ? $self->{nb_port} : Mojo::IOLoop::Server->generate_port;
            $server->listen(["$proto://$ip_addr:$port"])->start;
            warn "[test] nonblocking url: " . Mojo::URL->new("$proto://$ip_addr:$self->{nb_port}") . "\n" if $ENV{MERITCOMMONS_DEBUG};
        },
        _url => sub {
            my ($self, $nb) = (shift, shift);
            $self->_restart(0, @_) if !$self->{server} || @_;
            my $port = $nb ? $self->{nb_port} : $self->{port};
            my $ip_addr = $self->{ip_addr} ? $self->{ip_addr} : '127.0.0.1';
            return Mojo::URL->new("$self->{proto}://$ip_addr:$port/");
        },
    );
}

sub new {
    my ($class, $config) = @_;
    $ENV{MERITCOMMONS_TESTING} = 1;

    # share a zmq context for all the tests...
    $MeritCommons::zmq_shared_context = zmq_ctx_new();

    my $base_dir = $ENV{MERITCOMMONS_HOME} ? "$ENV{MERITCOMMONS_HOME}/" : '';

    # filter dist vs/ user-set test configs
    if ($MeritCommons::config_file =~ /^%test-configs%\/(.+)$/) {

        # resolve this to the proper config file...
        my $file_name = $1;
        if (-e "${base_dir}t/configs/$file_name") {
            $MeritCommons::config_file = "t/configs/$file_name";
        } else {
            $MeritCommons::config_file = "t/configs-dist/$file_name";
        }
    }

    unless ($MeritCommons::config_file =~ /^t\//) {
        if (-e "${base_dir}t/configs/meritcommons.conf") {

            # use the override
            $MeritCommons::config_file = 't/configs/meritcommons.conf';
        } else {

            # use the distributed config
            $MeritCommons::config_file = 't/configs-dist/meritcommons.conf';
        }
    }

    $MeritCommons::config_file = 't/configs/meritcommons.conf' unless $MeritCommons::config_file =~ /^t\//; # override the etc, but not another test's
    $MeritCommons::asset_base = '/';

    # set up this test's postgres instance
    $ENV{PGPORT} = '25511';
    system("initdb -A trust -D /var/tmp/meritcommons_test_$$ 2>&1 >> /dev/null");
    system("pg_ctl -w -D /var/tmp/meritcommons_test_$$ -l /var/tmp/meritcommons_test_$$.log start 2>&1 >> /dev/null");

    my $tries = 0;
    until (system("psql --quiet -h localhost -p 25511 -d template1 -c 'create database meritcommons;'") == 0) {
        die "[fatal] can't run tests, error starting PostgreSQL, see /var/tmp/meritcommons_test_$$.log\n" if $tries == 25;
        $tries++;
        Time::HiRes::sleep 0.2;
    }
    system("psql --quiet -h localhost -p 25511 -d template1 -c 'create database meritcommons_async;'");
    
    my $sphinx_is_running = `ps -ef | grep searchd | grep configs-dist | grep -v grep | awk '{print \$2}'`;
    chomp $sphinx_is_running;

    unless ($sphinx_is_running) {
        system("mkdir -p /var/tmp/sphinx/data");
        system("searchd -c $ENV{MERITCOMMONS_HOME}/t/configs-dist/sphinx.conf 2>&1");
    }

    # get and configure a Test::Mojo object
    my $tm  = Test::Mojo->new('MeritCommons');
    my $app = $tm->app;

    # replace the UserAgent with one that will allow for selenium testing (if required)
    if ($ENV{SELENIUM_TESTING}) {
        $tm->{ua} =
          Mojo::UserAgent->new->local_address('0.0.0.0')->max_connections(20)->ioloop(Mojo::IOLoop->singleton);
        $tm->ua->server->app($app);
        $tm->ua->server->{ip_addr} = '0.0.0.0';
    }

    my $self = bless($tm, $class);
    $app->config->{identity_server} = $self->fixup_front_door_url('/')->to_string;

    # for /myws requests!
    $self->app->config->{advertised_websocket} =
      "ws://@{[$self->app->config->{front_door_host}]}:@{[$self->ua->server->nb_url->port]}/hydrant";

    if (my $sc = $ENV{SELENIUM_TESTING} && $self->app->config->{selenium}) {
        $self->{selenium_config} = $sc;
    } else {
        print "[info] selenium testing disabled\n" if $ENV{MERITCOMMONS_DEBUG};
    }

    for (my $i = 0; $i < 3; $i++) {
        $self->ua->ioloop->one_tick;
        Time::HiRes::sleep 0.20;
    }

    return $self;
}

sub _selenium {
    my ($self, $browser) = @_;
    if (my $sc = $self->selenium_config) {
        print "[info] selenium starting browser '$browser'\n" if $ENV{MERITCOMMONS_DEBUG};
        sleep 1;
        return Selenium::Remote::Driver->new(
            error_handler => sub {
                my @tc = localtime(time);
                open my $test_log_file, ">>", "$ENV{MERITCOMMONS_HOME}/log/selenium_tests.log"
                  or die "Can't open file for writing: $!\n";
                print $test_log_file "[Selenium Error " .
                  sprintf("%d/%02d/%02d %02d:%02d:%02d]", $tc[5] + 1900, $tc[4] + 1, $tc[3], $tc[2], $tc[1], $tc[0]) .
                  ": " . $_[1] . "\n";
                close $test_log_file;

                croak "Selenium Test Failed.";
            },
            browser_name => $browser,
            map {
                $_, $sc->{remote}->{$_}
            } keys %{ $sc->{remote} },
        );
    }
}

sub selenium_ie {
    my ($self) = @_;

    unless ($self->{selenium_ie}) {
        $self->{selenium_ie} = $self->_selenium('ie');
    }
    return $self->{selenium_ie};
}

sub selenium_firefox {
    my ($self) = @_;

    unless ($self->{selenium_firefox}) {
        $self->{selenium_firefox} = $self->_selenium('firefox');
    }
    return $self->{selenium_firefox};
}

sub selenium_chrome {
    my ($self) = @_;

    unless ($self->{selenium_chrome}) {
        $self->{selenium_chrome} = $self->_selenium('chrome');
    }
    return $self->{selenium_chrome};
}

#
# Usage:
# $t->selenium_call({
#     browser => 'chrome',
#     method => 'get',
#     args => [
#         {
#             val => '/',
#             is_relative_url => 1,
#         }
#     ],
#     calls => [
#         method => ..., args => [] ...,
#     ],
#     time => 5000, # time in MS
# })
#
sub selenium_call {
    my ($self, $opts) = @_;
    return unless ref $opts eq "HASH";

    if (my $sc = $ENV{SELENIUM_TESTING} && $self->app->config->{selenium}) {

        # default to the first listed browser if one isn't specified in the call
        my $browser = $opts->{browser} || $sc->{browsers}->[0];

        # CHLD handler to indicate the work has been completed...
        $self->{selenium_finished} = {};
        local $SIG{CHLD} = sub {
            while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
                $self->{selenium_finished}->{$pid}->{status} = 1;
            }
        };

        # load browser before-hand so it persists...
        my $bm               = "selenium_$browser";
        my $selenium_browser = $self->$bm;

        # for rudimentary file-based IPC..
        my $call_id      = $self->app->new_uuid;
        my $results_file = "/tmp/selenium_output.$call_id.dat";

        my $start_time = ms_time();
        if (my $pid = fork) {
            $self->{selenium_finished}->{$pid}->{status}     = 0;
            $self->{selenium_finished}->{$pid}->{start_time} = ms_time();
            $self->ua->ioloop->one_tick until $self->{selenium_finished}->{$pid}->{status} == 1;
        } else {

            # re-seed the rng
            srand;

            # we don't respond to SIG{CHLD}
            local $SIG{CHLD} = 'IGNORE';

            eval {
                # we need a new zmq context..
                $MeritCommons::zmq_shared_context = zmq_ctx_new();

                # prevent us from destroying the daemons :)
                $MeritCommons::is_manager_process = 0;

                Mojo::Util::monkey_patch('Selenium::Remote::Driver', DESTROY => sub { },);

                # don't destroy our database handle
                Mojo::Util::monkey_patch('DBD::Oracle::db', DESTROY => sub { },);

                if (ref $opts->{calls} eq "ARRAY") {

                    # this is a multi-call request..

                    my $results = [];
                    foreach my $call (@{ $opts->{calls} }) {
                        my $method = $call->{method};

                        my @args;
                        foreach my $arg (@{ $call->{args} }) {
                            push(@args,
                                  $arg->{is_relative_url}
                                ? $self->fixup_front_door_url($arg->{val})->to_string
                                : $arg->{val});
                        }

                        # make sure this is non-fatal so we eventually return our results.
                        eval { push(@$results, { method => $method, result => $selenium_browser->$method(@args) }); };
                        if (my $error = $@) {
                            push(@$results, { method => $method, result => $error });
                        }
                    }

                    local $Data::Dumper::TERSE = 1;
                    Mojo::File->new($results_file)->spurt($self->app->dumper($results));
                } elsif (ref $opts->{block} eq "CODE") {

                    # execute a block of code....

                    my $res = $opts->{block}->($self, $selenium_browser);

                    local $Data::Dumper::TERSE = 1;

                    # write out our results to a file...
                    Mojo::File->new($results_file)->spurt($self->app->dumper(ref $res ? $self->app->dumper($res) : $res));
                } else {

                    # this is a single call request...
                    my $method = $opts->{method};

                    # format / conditionally transform arguments
                    my @args;
                    foreach my $arg (@{ $opts->{args} }) {
                        push(@args,
                              $arg->{is_relative_url}
                            ? $self->fixup_front_door_url($arg->{val})->to_string
                            : $arg->{val});
                    }
                    my $res = $selenium_browser->$method(@args);

                    local $Data::Dumper::TERSE = 1;

                    # write out our results to a file...
                    Mojo::File->new($results_file)->spurt($self->app->dumper(ref $res ? $self->app->dumper($res) : $res));
                }
            };

            # if we haven't taken at least the amount of time we expected, sleep the difference.
            if ($start_time + $opts->{time} > ms_time()) {
                my $remainder = ((($start_time + $opts->{time}) - ms_time()) / 1000);
                Time::HiRes::sleep($remainder);
            }

            # we're done here.
            exit;
        }

        # return value from the call.
        if (-e $results_file) {
            my $results = Mojo::File->new($results_file)->slurp;
            unlink $results_file;

            # looks like this is perl...
            if (ref($opts->{calls}) eq "ARRAY" || $opts->{returns_serialized}) {
                eval "\$results = $results";
            }

            return $results;
        }

    } else {
        warn "[warning] called selenium_call without selenium config and / or SELENIUM_TESTING=1\n";
    }
}

sub selenium_all {
    my ($self, @args) = @_;
    if (my $sc = $ENV{SELENIUM_TESTING} && $self->app->config->{selenium}) {

        # get the method and massage the arguments.
        my $method = shift @args;
        if ($method eq "get") {
            $args[0] = $self->fixup_front_door_url($args[0])->to_string;
        }

        $self->{selenium_finished} = 0;
        local $SIG{CHLD} = sub {
            while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
                $self->{selenium_finished}->{$pid} = 1;
            }
        };

        if (my $pid = fork) {

            # parent
            $self->ua->ioloop->one_tick until $self->{selenium_finished}->{$pid};
        } else {

            # re-seed the rng
            srand;

            local $SIG{CHLD} = 'IGNORE';

            # we need a new zmq context..
            $MeritCommons::zmq_shared_context = zmq_ctx_new();

            # prevent us from destroying the daemons :)
            $MeritCommons::is_manager_process = 0;

            # selenium worker..
            Mojo::Util::monkey_patch('Selenium::Remote::Driver', DESTROY => sub { },);
            foreach my $browser (@{ $sc->{browsers} }) {
                $self->{"selenium_$browser"}->$method(@args);
            }
            exit;
        }
    }
}

sub ms_time {
    my ($self) = @_;
    return (int(Time::HiRes::time * 1000));
}

sub websocket_ok {
    my ($self, @args) = @_;

    # ensure proper host + referer
    $self->SUPER::websocket_ok($self->fixup_location(shift @args, 1), $self->fixup_headers(shift @args), @args);
}

sub get_ok {
    my ($self, @args) = @_;

    # ensure proper host + referer
    $self->SUPER::get_ok($self->fixup_location(shift @args), $self->fixup_headers(shift @args), @args);
}

sub post_ok {
    my ($self, @args) = @_;

    # ensure proper host + referer
    $self->SUPER::post_ok($self->fixup_location(shift @args), $self->fixup_headers(shift @args), @args);
}

sub fixup_front_door_url {
    my ($self, $path, $nonblock) = @_;

    my $method = $nonblock ? "nb_url" : "url";

    my $pu  = Mojo::URL->new($path);
    my $fdu = Mojo::URL->new($self->app->config->{front_door_url});
    $fdu->host($self->app->config->{front_door_host});
    $fdu->port($self->ua->server->$method->port);
    $fdu->path($pu->path);
    $fdu->query($pu->query);

    return $fdu;
}

sub fixup_location {
    my ($self, $location, $nonblock) = @_;
    if ($location =~ /^http[s]*:\/\// || $location =~ /ws[s]*:\/\//) {
        return $location;
    }
    return $self->fixup_front_door_url($location, $nonblock);
}

sub fixup_headers {
    my ($self, $header) = @_;
    my @fixed;
    if (ref($header)) {
        $header->{Host} = $self->app->config->{front_door_host};
        push(@fixed, $header);
    } else {
        push(@fixed, { Host => $self->app->config->{front_door_host} }, $header);
    }

    return @fixed;
}

sub DESTROY {
    warn "[test/DESTROY] PID $$ " . ($MeritCommons::is_manager_process ? "is" : "isn't") . " a manager process\n" if $ENV{MERITCOMMONS_DEBUG};
    if ($MeritCommons::is_manager_process) {
        # destroy running postgres db...
        system("pg_ctl -w -m immediate -D /var/tmp/meritcommons_test_$$ -l /var/tmp/meritcommons_test_$$.log stop");        
        if (-d "/var/tmp/meritcommons_test_$$") {
            system("rm -rf /var/tmp/meritcommons_test_$$");
        }

        my $sphinx_is_running = `ps -ef | grep searchd | grep configs-dist | grep -v grep | awk '{print \$2}'`;
        chomp $sphinx_is_running;
        system("kill -9 $sphinx_is_running");
        system("rm -rf /var/tmp/sphinx/data");
    }
}

1;
