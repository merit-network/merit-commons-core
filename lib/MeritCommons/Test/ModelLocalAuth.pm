package MeritCommons::Test::ModelLocalAuth;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
use Test::Exception;
use MeritCommons::Test;
use File::Temp;

use Mojo::JSON qw/encode_json/;
use Mojo::URL;
use Mojolicious::Commands;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;

sub make_meritcommons : Test(startup => 2) {
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

    # Add test data
    my $new_local_user_cmd1 = MeritCommons::Command::new_local_user->new;
    $new_local_user_cmd1->{app} = $meritcommons;
    $new_local_user_cmd1->run('testuserone', 'Test UserOne', 'testpassone');
    my $user1 = $meritcommons->m->resultset('User')->search(
        {
            userid => 'testuserone',
        }
    )->single;

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
    $self->{user1}     = $user1;
}

sub update_password_field : Test(no_plan) {
    my $self      = shift;
    my $meritcommons = $self->{meritcommons};
    my $user      = $self->{user1};

    my @local_auths = $self->{meritcommons}->m->resultset('LocalAuth')->search(
        {
            meritcommons_user => $user->id,
        }
    )->all;

    cmp_ok(scalar(@local_auths), '==', 1, 'Just one LocalAuth row');

    my $local_auth   = $local_auths[0];
    my $new_password = 'a new password';
    $local_auth->password($new_password);
    $local_auth->update;

    ok($local_auth->authenticate($new_password), 'use new password');
    is($local_auth->authenticate('testpassone'), undef, 'use old password');
}

sub clean_up : Test(shutdown) {
}

1;
