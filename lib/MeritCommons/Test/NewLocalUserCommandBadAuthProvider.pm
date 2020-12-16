package MeritCommons::Test::NewLocalUserCommand;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
use Test::Exception;
use MeritCommons;
use MeritCommons::Test;
use File::Temp;

use Mojo::JSON qw/encode_json/;
use Mojo::URL;
use Mojolicious::Commands;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;

sub make_meritcommons : Test(startup => 2) {
    $MeritCommons::config_file = '%test-configs%/meritcommons.ldapauth.conf';

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

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
}

sub bad_authentication_provider : Test(1) {
    my $self      = shift;
    my $meritcommons = $self->{meritcommons};

    my $test_username    = 'testguy';
    my $test_common_name = 'TEST GUY';
    my $test_pass        = 'testpass';

    my $new_local_user_cmd = MeritCommons::Command::new_local_user->new;
    $new_local_user_cmd->{app} = $meritcommons;

    # Normal call
    $new_local_user_cmd->run($test_username, $test_common_name, $test_pass);
    my @users = $self->{meritcommons}->m->resultset('User')->search(
        {
            userid => $test_username,
        }
    )->all;

    cmp_ok(scalar(@users), '==', 0, 'LocalAuth not configured');

}

sub clean_up : Test(shutdown) {
}

1;
