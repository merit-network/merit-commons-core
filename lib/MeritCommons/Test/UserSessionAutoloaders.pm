package MeritCommons::Test::UserSessionAutoloaders;

use Mojo::Base -strict;

use base qw(Test::Class);
use Test::More;
use MeritCommons::Test;
use File::Temp;
use Time::HiRes;

use Mojo::JSON qw/encode_json decode_json/;
use Mojo::URL;
use Mojo::Util qw(url_escape);
use Mojolicious::Commands;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;

my $username1 = 'justin';
my $password1 = 'abc123';
my $username2 = 'bailey';
my $password2 = 'lewlz';

sub user_autoloader_test : Test(no_plan) {
    my $self = shift;
    my $t    = $self->{t};

    $self->_login;

    my $user = $t->app->user($username1);
    ok(ref($user) eq "MeritCommons::Model::User", "do we have an MeritCommons::Model::User object?");
    my $session = $user->sessions->first;
    ok(ref($session) eq "MeritCommons::Model::Session", "do we have an MeritCommons::Model::Session object?");
    
    ok(!$session->is_expired, "make sure the session isn't expired");
    ok($user->id, "make sure the user has an id");

    # random keys, random values.
    my (@keys, @values);
    no warnings 'experimental';
    for (my $i = 0; $i < 30; $i++) {
        my $k = $t->app->random_b64u;
        $k =~ s/\W//g;
        $k =~ s/^\d+//g;
        my $v = [ map { $t->app->random_b64u } (0..int(rand(8))) ];
        my $waldo_idx = int(rand($#{$v}));
        splice($v, $waldo_idx - 1, 0, "waldo");
        push(@keys, $k);
        push(@values, $v);

        # evens go in the user.. odds go in the session.
        if ($i == 0 || !($i % 2)) {
            $user->$k(@$v);
        } elsif ($i == 1 || ($i % 2)) {
            $session->$k(@$v);
        }
    }
    
    my $i = 0;
    foreach my $key (@keys) {
        my @v = @{$values[$i]};
        if ($i == 0 || !($i % 2)) {            
            ok(ref $user->$key eq "Mojo::Collection", "making sure user autoloader returned value is a Mojo::Collection object");
            is($user->first_attribute_value($key), $v[0], "random check first_attribute_value on user");
            is($user->last_attribute_value($key), $v[$#v], "random check last_attribute_value on user");
            ok($user->$key->grep(qr/waldo/)->first eq "waldo", "found waldo with grep method on Mojo::Collection");
            is_deeply([@{$user->$key}], \@v, "making sure all multiple values are the same for this key");
        } elsif ($i == 1 || ($i % 2)) {
            ok(ref $session->$key eq "Mojo::Collection", "making sure session autoloader returned value is a Mojo::Collection object");
            is($session->first_attribute_value($key), $v[0], "random check first_attribute_value on session");
            is($session->last_attribute_value($key), $v[$#v], "random check last_attribute_value on session");
            ok($session->$key->grep(qr/waldo/)->first eq "waldo", "found waldo with grep method on Mojo::Collection");
            is_deeply([@{$session->$key}], \@v, "making sure all multiple values are the same for this key");
        }
        
        my $context_key = "__$key";
        my $val = $session->$context_key;
        my @vals = $session->$context_key;
        
        is($session->first_attribute_value($key), $val, "make sure calls to session autoloader in scalar context return the first value");
        ok(scalar(@v) == scalar(@vals), "make sure calls to session autoloader in list context return the full list");
        
        $i++;
    }
    
}

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

    # Add test data
    my $new_local_user_cmd1 = MeritCommons::Command::new_local_user->new;
    $new_local_user_cmd1->{app} = $meritcommons;
    $new_local_user_cmd1->run($username1, 'Test UserOne', $password1);
    my $user1 = $meritcommons->m->resultset('User')->search(
        {
            userid => $username1,
        }
    )->single;
    $new_local_user_cmd1->run($username2, 'Test UserTwo', $password2);
    my $user2 = $meritcommons->m->resultset('User')->search(
        {
            userid => $username2,
        }
    )->single;

    $self->{t}         = $t;
    $self->{meritcommons} = $meritcommons;
    $self->{user1}     = $user1;
    $self->{user2}     = $user2;
}

sub _login {    # Does 12 tests
    my $self     = shift;
    my $t        = $self->{t};
    my $username = shift || $username1;
    my $password = shift || $password1;

    # make sure we allow redirects.
    $t->ua->max_redirects(50);

    $t->post_ok('/auth' => { Referer => $t->app->config->{identity_server} } => form =>
          { username => $username, password => $password })->status_is(200)
      ->element_exists('html head meta[content]', 'Looking for meta refresh to the merge');
    $t->get_ok('/')->status_is(200)->element_exists('html body meta', 'Looking for meta refresh');
    my $location = (split("'", (split(';', $t->tx->res->dom->find('html body meta')->[0]->attr('content')))[1]))[1];

    # turn redirects off.
    $t->ua->max_redirects(0);

    $t->get_ok($location)->status_is(302)->header_is('location' => $t->app->url_for('/'));
    $t->get_ok('/')->status_is(200)->element_exists('html body div#inbound', 'Looking for inbound div');
}

sub _logout {    # Does 3 tests
    my $self = shift;
    my $t    = $self->{t};

    # Check logout
    $t->get_ok('/auth' => form => { logout => 1 })->status_is(302)
      ->header_is('location' => $t->app->url_for('/')->query([ logout => undef ])->to_string);
}

sub clean_up : Test(shutdown) {
    my ($self) = @_;
    my $t = $self->{t};

    # cleanup one last time
    my $daemon    = $t->ua->server->{server};
    my $nb_daemon = $t->ua->server->{nb_server};
    for my $d ($daemon, $nb_daemon) {
        $d->_remove($_) for keys %{ $_->{connections} || {} };
        $d->ioloop->remove($_) for @{ $d->acceptors };
    }
    $t->ua->ioloop->one_tick;
}

1;
