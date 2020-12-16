package MeritCommons::Test::Summernote;

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

    # add test user
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

sub test_summernote_selenium_setup : Test(7) {
    my ($self) = @_;
    return unless $ENV{SELENIUM_TESTING};
    my $t = $self->{t};

    my %test_results = (
        'logging into meritcommons' => {
            'order'  => 0,
            'result' => 0,
        },
        'inbound showed up 1' => {
            'order'  => 1,
            'result' => 0,
        },
        'a post showed up 1' => {
            'order'  => 2,
            'result' => 0,
        },
        'basic post correctness' => {
            'order'  => 3,
            'result' => 0,
        },
        'inbound showed up 2' => {
            'order'  => 4,
            'result' => 0,
        },
        'a post showed up 2' => {
            'order'  => 5,
            'result' => 0,
        },
        'long post correctness' => {
            'order'  => 6,
            'result' => 0,
        },
    );

    my $summernote_test = sub {
        my ($t, $driver) = @_;

        $driver->set_implicit_wait_timeout(5000);
        $driver->set_timeout("page load", 10000);
        $driver->set_window_size(720, 1280);
        $driver->get($t->fixup_front_door_url('/')->to_string);

        my $current_path = $driver->get_path;
        unless ($current_path eq $t->fixup_front_door_url('/')->path) {
            return \%test_results;
        }

        # login
        my $username_field = $driver->find_element_by_name('username');
        unless ($username_field) {
            return \%test_results;
        }

        $driver->send_keys_to_active_element('bob');

        my $password_field = $driver->find_element_by_name('password');
        if (!($password_field)) {
            return \%test_results;
        }

        $password_field->click;
        $driver->send_keys_to_active_element('abc123');

        my $login = $driver->find_element_by_class('btn');
        unless ($login) {
            return \%test_results;
        }

        $login->click;
        $test_results{'logging into meritcommons'}->{'result'} = 1;

        my $new_post_button = $driver->find_element_by_id('open-inbound');
        unless ($new_post_button) {
            return \%test_results;
        }

        # wait for the new post button to show up on the page, if it never does, stop now
        unless (_it_shows_up($driver, $new_post_button)) {
            return \%test_results;
        }

        $test_results{'inbound showed up 1'}->{'result'} = 1;

        my $post_showed_up   = 0;
        my $post_was_correct = 0;
        my $html;
        my $text;

        # BASIC MESSAGE TEST

        $new_post_button->click;

        # create needed vars, get various needed buttons and select the default stream
        my $stream_selector   = $driver->find_element_by_class('select2-search__field');
        my $submit_button     = $driver->find_element_by_id('post-it');
        my $message_input_box = $driver->find_element_by_class('note-editable');

        # if any of them were not found, stop now
        unless ($stream_selector && $submit_button && $message_input_box) {
            return \%test_results;
        }

        # wait for the stream selector to show up on the page, if it never does, stop now
        unless (_it_shows_up($driver, $stream_selector)) {
            return \%test_results;
        }

        $stream_selector->click;
        $driver->send_keys_to_active_element(KEYS->{'return'});

        $text = "this is some test text";
        $html = "<p>this is some test text</p>\n";

        _input_text($driver, $message_input_box, $text);

        # submit this one
        $submit_button->click;

        $post_showed_up   = 0;
        $post_was_correct = 0;

        # if a post shows up
        if (_posts_increased($driver, 0)) {
            $post_showed_up = 1;

            # check if the post has the correct text
            if (_check_post($driver, $html)) {
                $post_was_correct = 1;
            }
        }

        $test_results{'a post showed up 1'}->{'result'}     = $post_showed_up;
        $test_results{'basic post correctness'}->{'result'} = $post_was_correct;

        # LONG MESSAGE TEST

        # wait until the inbound fades out
        unless (_it_shows_up($driver, $new_post_button)) {
            return \%test_results;
        }

        $test_results{'inbound showed up 2'}->{'result'} = 1;

        $new_post_button->click;

        # create needed vars, get various needed buttons and select the default stream
        $stream_selector   = $driver->find_element_by_class('select2-search__field');
        $submit_button     = $driver->find_element_by_id('post-it');
        $message_input_box = $driver->find_element_by_class('note-editable');

        # if any of them were not found, stop now
        unless ($stream_selector && $submit_button && $message_input_box) {
            return \%test_results;
        }

        # wait for the stream selector to show up on the page, if it never does, stop now
        unless (_it_shows_up($driver, $stream_selector)) {
            return \%test_results;
        }

        $stream_selector->click;
        $driver->send_keys_to_active_element(KEYS->{'return'});

        # generate long message
        $text = 'text';
        for (my $i = 0 ; $i < 400 ; $i++) {
            $text = $text . ' text';
        }

        _input_text($driver, $message_input_box, $text);

        # what the html should be
        $html = "<p>" . $text . "</p>\n";

        # submit this one
        $submit_button->click;

        $post_showed_up   = 0;
        $post_was_correct = 0;

        # if a post shows up
        if (_posts_increased($driver, 1)) {
            $post_showed_up = 1;

            # check if the post has the correct text
            if (_check_post($driver, $html)) {
                $post_was_correct = 1;
            }
        }

        $test_results{'a post showed up 2'}->{'result'}    = $post_showed_up;
        $test_results{'long post correctness'}->{'result'} = $post_was_correct;

        return \%test_results;
    };

    my $res = $t->selenium_call(
        {
            browser            => 'chrome',
            block              => $summernote_test,
            time               => 3000,
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

# inputs text into the input
sub _input_text {
    my ($driver, $input, $text) = @_;

    $input->click;
    $driver->send_keys_to_active_element($text);
}

sub _check_post {
    my ($driver, $my_html) = @_;

    my $get_body = q{
        return $('.thread').first().find('.body').html();
    };

    my $get_full_body = q{
        return $('.thread').first().find('.full-body').html();
    };

    # try and grab the full body
    my $full_body = $driver->execute_script($get_full_body);
    my $post_html;

    # if the full body was there
    if ($full_body) {

        # use that
        $post_html = $full_body;

        # otherwise
    } else {

        # use the regular body
        $post_html = $driver->execute_script($get_body);
    }

    return $my_html eq $post_html;
}

sub _posts_increased {
    my ($driver, $starting_number_of_posts) = @_;

    my $max_attempts = 100;

    # print "Post increased called\n";
    # print "I was given $starting_number_of_posts as the starting number\n";
    # print "I will look for one more post to show up $max_attempts times\n";
    # print "Entering loop\n";

    my $current = $starting_number_of_posts;

    # loop until your attempts run out or the post shows up or is already there
    my @posts;
    my $attempts = 0;
    while ($attempts < $max_attempts && !($current == $starting_number_of_posts + 1)) {

        # print "attempt $attempts\n";
        @posts = $driver->find_elements('thread-parent', 'class');
        $current = (scalar @posts);

        # print "found $current posts\n";
        $driver->pause(100);
        $attempts += 1;
    }

    return !($attempts >= $max_attempts);
}

# returns 1 if the web element shows up or 0 if it never does
sub _it_shows_up {
    my ($driver, $web_element) = @_;

    my $max_attempts = 20;

    my $attempts = 0;
    while ($web_element->is_hidden && $attempts < $max_attempts) {
        $driver->pause(100);
        $attempts += 1;
    }

    # have to wait just a bit more
    # doing things immediately cause errors
    $driver->pause(200);

    return $web_element->is_displayed;
}

1;
