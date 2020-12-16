package MeritCommons::Test::StreamCreationSelenium;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
use MeritCommons::Test;
use File::Temp;
use Time::HiRes;
use ZMQ::LibZMQ3;
use Mojo::JSON qw/encode_json decode_json/;
use Mojo::URL;
use Mojo::Util qw(url_escape);
use Mojolicious::Command;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;
use MeritCommons::Command::minion_mp;
use Selenium::Remote::WDKeys;

sub make_meritcommons : Test(startup => 2) {
    my $self      = shift;
    my $t         = MeritCommons::Test->new();
    my $meritcommons = $t->app;

    # make our base schema
    my $install_schema_cmd = MeritCommons::Command::install_schema->new;
    $install_schema_cmd->{app} = $meritcommons;
    $install_schema_cmd->run();

    # check that we have a new + clean db
    my @users = $meritcommons->m->resultset('User')->all;
    cmp_ok(scalar(@users), '==', 1);
    my @messages = $meritcommons->m->resultset('Stream::Message')->all;
    cmp_ok(scalar(@messages), '==', 0);

    # add test data
    my $new_local_user_cmd = MeritCommons::Command::new_local_user->new;
    $new_local_user_cmd->{app} = $meritcommons;
    $new_local_user_cmd->run('bob', 'Bob Loblaw', 'abc123');
    my $user_one = $meritcommons->m->resultset('User')->search(
        {
            userid => 'bob',
        }
    )->single;

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
    $self->{user_one}  = $user_one;
}

sub test_stream_creation_selenium_setup : Test(2) {
    my ($self) = @_;
    return unless $ENV{SELENIUM_TESTING};
    my $t = $self->{t};

    my %test_results = (
        'logging into meritcommons' => {
            'order'  => 0,
            'result' => 0,
        },
        'number of streams in list' => {
            'order'  => 1,
            'result' => 0,
        },
    );

    my $stream_creation_test = sub {
        my ($t, $driver) = @_;

        $driver->set_implicit_wait_timeout(5000);
        $driver->set_window_size(720, 1280);
        $driver->get($t->fixup_front_door_url('/')->to_string);

        my $current_path = $driver->get_path;
        unless ($current_path eq $t->fixup_front_door_url('/')->path) {
            return \%test_results;
        }

        # login
        my $username_field = _get_element($driver, 'name', 'username', 1000);
        unless ($username_field) {
            return \%test_results;
        }
        $username_field->send_keys('bob');

        my $password_field = _get_element($driver, 'name', 'password', 1000);
        unless ($password_field) {
            return \%test_results;
        }
        $password_field->send_keys('abc123');

        my $login = _get_element($driver, 'class', 'btn', 1000);
        unless ($login) {
            return \%test_results;
        }

        $login->click;
        $test_results{'logging into meritcommons'}->{'result'} = 1;

        my $new_post_button;

        # wait for the new post button to show up on the page, if it never does, stop now
        unless ($new_post_button = _get_element($driver, 'id', 'open-inbound', 1000)) {
            return \%test_results;
        }

        my $num_streams = 5;

        # let's make some streams!
        my @streams = ();
        for my $i (1 .. $num_streams) {

            my $stream_name = MeritCommons::Helper::MiscUtil::__get_random_word(45, '/usr/share/dict/words');

            # handling stream name collisions
            while (grep { $_ eq $stream_name } @streams) {
                $stream_name = MeritCommons::Helper::MiscUtil::__get_random_word(45, '/usr/share/dict/words');
            }
            push @streams, $stream_name;

            $driver->get($t->fixup_front_door_url('/s/' . $stream_name)->to_string);

            my $stream_description;
            unless ($stream_description = _get_element($driver, 'id', 'input_description', 1000)) {
                return \%test_results;
            }
            $stream_description->send_keys($stream_name);

            my $stream_keywords;
            unless ($stream_keywords = _get_element($driver, 'id', 'input_keywords', 1000)) {
                return \%test_results;
            }
            $stream_keywords->send_keys($stream_name);

            my $next_step;
            unless ($next_step = _get_element($driver, 'id', 'streamInfo_next', 1000)) {
                return \%test_results;
            }
            $next_step->click;

            # keeping the default permissions for now

            unless ($next_step = _get_element($driver, 'id', 'streamPerms_next', 1000)) {
                return \%test_results;
            }
            $next_step->click;

            my $stream_create;
            unless ($stream_create = _get_element($driver, 'id', 'create', 1000)) {
                return \%test_results;
            }
            $stream_create->click;

            sleep(1);
        }

        $driver->get($t->fixup_front_door_url('/u/bob/s')->to_string);

        my $moderations;
        unless ($moderations = _get_element($driver, 'link_text', 'Moderations', 1000)) {
            return \%test_results;
        }
        $moderations->click;

        my $script = q{
            return $('#moderatorship-removal-form').find('tr').length - 1;
        };

        my $num_streams_in_list = $driver->execute_script($script);
        my $test_result         = 0;

        if ($num_streams_in_list == $num_streams) {
            $test_result = 1;
        }

        $test_results{'number of streams in list'}->{'result'} = $test_result;

        return \%test_results;
    };

    my $res = $t->selenium_call(
        {
            browser            => 'chrome',
            block              => $stream_creation_test,
            time               => 5000,
            returns_serialized => 1,
        }
    );

    # if selenium returned anything, grab that
    if ($res) {
        %test_results = %{$res};
    }

    # change response into an array so it can have order when outputted
    my @array_res = ();
    while (my ($description, $information) = each %test_results) {
        $array_res[ $information->{'order'} ] = { 'description' => $description, 'result' => $information->{'result'} };
    }

    # roll through results and see how we did
    foreach my $result (@array_res) {
        ok($result->{'result'}, $result->{'description'});
    }
}

sub clean_up : Test(shutdown) {
}

sub _get_element {
    my ($driver, $selector, $element, $max_wait) = @_;

    my $el;
    my $find = 'find_element_by_' . $selector;

    while ($max_wait > 0 && !($el = $driver->$find($element))) {
        sleep(0.1);
        $max_wait = $max_wait - 100;
    }

    sleep(1);

    if ($el) {
        return $el;
    } else {
        return 0;
    }
}

1;
