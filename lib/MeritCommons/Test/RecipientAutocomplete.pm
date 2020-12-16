package MeritCommons::Test::RecipientAutocomplete;

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
    $new_local_user_cmd->run('bobina', 'Bobina Loblaw', 'abc123');
    my $user_two = $meritcommons->m->resultset('User')->search(
        {
            userid => 'bobina',
        }
    )->single;

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
    $self->{user_one}  = $user_one;
    $self->{user_two}  = $user_two;
}

sub test_recipient_autocomplete_selenium_setup : Test(6) {
    my ($self) = @_;
    return unless $ENV{SELENIUM_TESTING};
    my $t = $self->{t};

    my %test_results = (
        'logging into meritcommons' => {
            'order'  => 0,
            'result' => 0,
        },
        'following user' => {
            'order'  => 1,
            'result' => 0,
        },
        'selecting recipient with click' => {
            'order'  => 2,
            'result' => 0,
        },
        'selecting recipient with tab' => {
            'order'  => 3,
            'result' => 0,
        },
        'deleting recipient last name' => {
            'order'  => 4,
            'result' => 0,
        },
        'deleting and starting over' => {
            'order'  => 5,
            'result' => 0,
        },
    );

    my $recipient_autocomplete_test = sub {
        my ($t, $driver) = @_;

        $driver->set_implicit_wait_timeout(5000);
        $driver->set_timeout("page load", 10000);
        $driver->set_window_size(720, 1280);

        $driver->get($t->fixup_front_door_url('/')->to_string);

        my $current_path = $driver->get_path;
        unless ($current_path eq $t->fixup_front_door_url('/')->path) {
            return \%test_results;
        }

        my $script = q{
            return $('.note-editable').html();
        };

        # login
        my $username_field = $driver->find_element_by_name('username');
        unless ($username_field) {
            return \%test_results;
        }

        $driver->send_keys_to_active_element('bob');

        my $password_field = $driver->find_element_by_name('password');
        unless ($password_field) {
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

        # follow
        $driver->get($t->fixup_location('/u/bobina')->to_string);
        my $follow = $driver->find_element_by_id('follow-button-form');
        my $follow_button = $driver->find_child_element($follow, 'button', 'tag_name');
        unless ($follow && $follow_button) {
            return \%test_results;
        }
        $follow_button->click;

        $test_results{'following user'}->{'result'} = 1;

        # give it time to follow?
        $driver->pause(1000);

        # go to home
        $driver->get($t->fixup_front_door_url('/')->to_string);

        my $new_post_button = $driver->find_element_by_id('open-inbound');
        unless ($new_post_button) {
            return \%test_results;
        }

        # wait for the new post button to show up on the page, if it never does, stop now
        unless (_it_shows_up($driver, $new_post_button)) {
            return \%test_results;
        }

        # SELECT RECIPIENT WITH CLICk

        $new_post_button->click;

        # get the input box
        my $message_input_box = $driver->find_element_by_class('note-editable');

        unless (_it_shows_up($driver, $message_input_box)) {
            return \%test_results;
        }

        $message_input_box->click;
        $driver->send_keys_to_active_element('Hey @Bobina');

        # wait for recipient popover to show up
        my $recipient_popover = $driver->find_element_by_class('note-recipient-popover');
        unless (_it_shows_up($driver, $recipient_popover)) {
            return \%test_results;
        }

        my $person = $driver->find_child_element($recipient_popover, 'aRecipient', 'class');
        $person->click;

        $driver->send_keys_to_active_element(KEYS->{'backspace'}, '!');

        my $contents = $driver->execute_script($script);

        my $test_result = 0;
        if ($contents eq '<p>Hey <span class="recipient" data-id="bobina">@bobina</span>!</p>') {
            $test_result = 1;
        }
        $test_results{'selecting recipient with click'}->{'result'} = $test_result;

        # submit this one
        $driver->find_element_by_id('post-it')->click;

        # SELECT RECIPIENT WITH TAB

        # wait until the inbound fades out
        unless (_it_shows_up($driver, $new_post_button)) {
            return \%test_results;
        }

        $new_post_button->click;

        # get the input box
        $message_input_box = $driver->find_element_by_class('note-editable');

        # wait for the inbound to show back up
        unless (_it_shows_up($driver, $message_input_box)) {
            return \%test_results;
        }

        $message_input_box->click;
        $driver->send_keys_to_active_element('Hey @Bobina');

        # wait for recipient popover to show up
        $recipient_popover = $driver->find_element_by_class('note-recipient-popover');
        unless (_it_shows_up($driver, $recipient_popover)) {
            return \%test_results;
        }

        $driver->send_keys_to_active_element(KEYS->{'tab'}, KEYS->{'backspace'}, '!');

        $contents = $driver->execute_script($script);

        $test_result = 0;
        if ($contents eq '<p>Hey <span class="recipient" data-id="bobina">@bobina</span>!</p>') {
            $test_result = 1;
        }
        $test_results{'selecting recipient with tab'}->{'result'} = $test_result;

        # submit this one
        $driver->find_element_by_id('post-it')->click;

        # DELETE RECIPIENT LAST NAME

        # wait until the inbound fades out
        unless (_it_shows_up($driver, $new_post_button)) {
            return \%test_results;
        }

        $new_post_button->click;

        # get the input box
        $message_input_box = $driver->find_element_by_class('note-editable');

        # wait for the inbound to show back up
        unless (_it_shows_up($driver, $message_input_box)) {
            return \%test_results;
        }

        $message_input_box->click;
        $driver->send_keys_to_active_element('Hey @Bobina Loblaw');

        # wait for recipient popover to show up
        $recipient_popover = $driver->find_element_by_class('note-recipient-popover');
        unless (_it_shows_up($driver, $recipient_popover)) {
            return \%test_results;
        }

        $driver->send_keys_to_active_element(KEYS->{'tab'}, KEYS->{'backspace'},
            KEYS->{'backspace'}, KEYS->{'backspace'}, '!');

        $contents = $driver->execute_script($script);

        # test the input
        $test_result = 0;
        if ($contents eq '<p>Hey <span class="recipient" data-id="bobina">@Bobina</span>!</p>') {
            $test_result = 1;
        }
        $test_results{'deleting recipient last name'}->{'result'} = $test_result;

        # submit this one
        $driver->find_element_by_id('post-it')->click;

        # DELETE EVERYTHING AND START OVER

        # wait until the inbound fades out
        unless (_it_shows_up($driver, $new_post_button)) {
            return \%test_results;
        }

        $new_post_button->click;

        # get the input box
        $message_input_box = $driver->find_element_by_class('note-editable');

        # wait for the inbound to show back up
        unless (_it_shows_up($driver, $message_input_box)) {
            return \%test_results;
        }

        $message_input_box->click;
        $driver->send_keys_to_active_element('Hey @Bobina');

        # wait for recipient popover to show up
        $recipient_popover = $driver->find_element_by_class('note-recipient-popover');
        unless (_it_shows_up($driver, $recipient_popover)) {
            return \%test_results;
        }

        $driver->send_keys_to_active_element(KEYS->{'tab'});
        $driver->send_keys_to_active_element(
            KEYS->{'backspace'}, KEYS->{'backspace'}, KEYS->{'backspace'}, KEYS->{'backspace'},
            KEYS->{'backspace'}, KEYS->{'backspace'}, KEYS->{'backspace'}, 'Sup @Bobina'
        );

        # wait for recipient popover to show up
        $recipient_popover = $driver->find_element_by_class('note-recipient-popover');
        unless (_it_shows_up($driver, $recipient_popover)) {
            return \%test_results;
        }

        $driver->send_keys_to_active_element(KEYS->{'tab'}, KEYS->{'backspace'}, '?');

        $contents = $driver->execute_script($script);

        # test the input
        $test_result = 0;
        if ($contents eq '<p>Sup <span class="recipient" data-id="bobina">@bobina</span>?&nbsp;</p>') {
            $test_result = 1;
        }
        $test_results{'deleting and starting over'}->{'result'} = $test_result;

        # submit this one
        $driver->find_element_by_id('post-it')->click;

        return \%test_results;
    };

    my $res = $t->selenium_call(
        {
            browser            => 'chrome',
            block              => $recipient_autocomplete_test,
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

# returns 1 if the web element shows up or 0 if it never does
sub _it_shows_up {
    my ($driver, $web_element) = @_;

    my $max_attempts = 20;

    # my $class = $web_element->get_attribute('class');
    my $attempts = 0;
    while ($web_element->is_hidden && $attempts < $max_attempts) {

        # print "this is attempt $attempts out of $max_attempts to find $class\n";
        $driver->pause(100);
        $attempts += 1;
    }

    # have to wait just a bit more
    # doing things immediately causes errors
    $driver->pause(200);

    return $web_element->is_displayed;
}

1;
