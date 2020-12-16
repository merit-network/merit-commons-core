package MeritCommons::Test::HelperLocalAuth;

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
}

sub make_raw_local_user : Test(68) {
    my $self      = shift;
    my $meritcommons = $self->{meritcommons};

    my $test_username    = 'testguy';
    my $test_common_name = 'TEST GUY';
    my $test_pass        = 'testpass';

    my $user = $meritcommons->new_local_user($test_username, $test_common_name, $test_pass);

    my $queried_user = $self->{meritcommons}->m->resultset('User')->search(
        {
            id => $user->id,
        }
    )->first;

    # Sanity
    is($queried_user->userid, $user->userid, 'Sanity username check');

    # Basic stuff
    is($queried_user->userid,            $test_username);
    is($queried_user->common_name,       $test_common_name);
    is($queried_user->identity_resource, 'local:' . $test_username);

    # LocalAuth model instance
    my $localauth = $self->{meritcommons}->m->resultset('LocalAuth')->search(
        {
            meritcommons_user => $user->id,
        }
    )->first;

    ok($localauth->authenticate($test_pass));

    # Outbox stuff
    my @outboxes = $self->{meritcommons}->m->resultset('Stream')->search(
        {
            personal_outbox_user => $user->id,
        }
    )->all;

    cmp_ok(scalar(@outboxes), '==', 1, 'Just one personal outbox');
    my $outbox = $outboxes[0];

    cmp_ok($outbox->id, '==', $queried_user->personal_outbox->id, 'outbox/user link');
    is($outbox->common_name, $queried_user->common_name, 'outbox common name');
    is($outbox->url_name,    $queried_user->userid,      'outbox url name');
    cmp_ok($outbox->creator->id,                   '==', $queried_user->id, 'outbox creator');
    cmp_ok($outbox->single_author,                 '==', 1,                 'outbox single author');
    cmp_ok($outbox->single_subscriber,             '==', 0,                 'outbox single subscriber');
    cmp_ok($outbox->requires_author_authorization, '==', 1,                 'outbox requires author authorization');
    is($outbox->type, 'system', 'outbox stream type');

    # Moderatorships for outbox
    my @outbox_mods = $self->{meritcommons}->m->resultset('Stream::Moderator')->search(
        {
            stream => $outbox->id,
        }
    )->all;
    cmp_ok(scalar(@outbox_mods), '==', 1, 'Just one personal outbox moderator');
    my $outbox_mod = $outbox_mods[0];
    cmp_ok($outbox_mod->meritcommons_user->id, '==', $queried_user->id, 'outbox moderator');
    cmp_ok($outbox_mod->added_by->id, '==', 1, 'outbox moderator added by');

    # Authorships for outbox
    my @outbox_authors = $self->{meritcommons}->m->resultset('Stream::Author')->search(
        {
            stream => $outbox->id,
        }
    )->all;
    cmp_ok(scalar(@outbox_authors), '==', 1, 'Just one personal outbox authorship');
    my $outbox_author = $outbox_authors[0];
    cmp_ok($outbox_author->meritcommons_user->id, '==', $queried_user->id, 'outbox authorship');
    cmp_ok($outbox_author->added_by->id,       '==', 1,                 'outbox authorship added by');
    cmp_ok($outbox_author->authorized,         '==', 1,                 'outbox authorship authorized');
    cmp_ok($outbox_author->allow_edit,         '==', 1,                 'outbox authorship allow edit');

    # Subscriptions for outbox
    my @outbox_subs = $self->{meritcommons}->m->resultset('Stream::Subscriber')->search(
        {
            stream => $outbox->id,
        }
    )->all;
    cmp_ok(scalar(@outbox_subs), '==', 1, 'Just one personal outbox subscription');
    my $outbox_sub = $outbox_subs[0];
    cmp_ok($outbox_sub->meritcommons_user->id, '==', $queried_user->id, 'outbox subscription');
    cmp_ok($outbox_sub->added_by->id,       '==', 1,                 'outbox subcription added by');
    cmp_ok($outbox_sub->authorized,         '==', 1,                 'outbox subscription authorized');
    cmp_ok($outbox_sub->allow_history,      '==', 1,                 'outbox subscription allow edit');

    # Inbox stuff
    my @inboxes = $self->{meritcommons}->m->resultset('Stream')->search(
        {
            personal_inbox_user => $user->id,
        }
    )->all;

    cmp_ok(scalar(@inboxes), '==', 1, 'Just one personal inbox');
    my $inbox = $inboxes[0];

    cmp_ok($inbox->id, '==', $queried_user->personal_inbox->id, 'inbox/user link');
    is($inbox->common_name, '_' . $queried_user->userid, 'inbox common name');
    is($inbox->url_name, undef, 'inbox url name');
    cmp_ok($inbox->creator->id,                   '==', $queried_user->id, 'inbox creator');
    cmp_ok($inbox->single_author,                 '==', 0,                 'inbox single author');
    cmp_ok($inbox->single_subscriber,             '==', 1,                 'inbox single subscriber');
    cmp_ok($inbox->requires_author_authorization, '==', 0,                 'inbox requires author authorization');
    is($inbox->type, 'system', 'inbox stream type');

    # Moderatorships for inbox
    my @inbox_mods = $self->{meritcommons}->m->resultset('Stream::Moderator')->search(
        {
            stream => $inbox->id,
        }
    )->all;
    cmp_ok(scalar(@inbox_mods), '==', 1, 'Just one personal inbox moderator');
    my $inbox_mod = $inbox_mods[0];
    cmp_ok($inbox_mod->meritcommons_user->id, '==', $queried_user->id, 'inbox moderator');
    cmp_ok($inbox_mod->added_by->id, '==', 1, 'inbox moderator added by');

    # Authorships for inbox
    my @inbox_authors = $self->{meritcommons}->m->resultset('Stream::Author')->search(
        {
            stream => $inbox->id,
        }
    )->all;
    cmp_ok(scalar(@inbox_authors), '==', 0, 'No personal inbox authorships');

    # Subscriptions for inbox
    my @inbox_subs = $self->{meritcommons}->m->resultset('Stream::Subscriber')->search(
        {
            stream => $inbox->id,
        }
    )->all;
    cmp_ok(scalar(@inbox_subs), '==', 1, 'Just one personal inbox subscription');
    my $inbox_sub = $inbox_subs[0];
    cmp_ok($inbox_sub->meritcommons_user->id, '==', $queried_user->id, 'inbox subscription');
    cmp_ok($inbox_sub->added_by->id,       '==', 1,                 'inbox subcription added by');
    cmp_ok($inbox_sub->authorized,         '==', 1,                 'inbox subscription authorized');
    cmp_ok($inbox_sub->allow_history,      '==', 1,                 'inbox subscription allow edit');

    # Notification inbox stuff
    my @ninboxes = $self->{meritcommons}->m->resultset('Stream')->search(
        {
            notification_inbox_user => $user->id,
        }
    )->all;

    cmp_ok(scalar(@ninboxes), '==', 1, 'Just one notification inbox');
    my $ninbox = $ninboxes[0];

    cmp_ok($ninbox->id, '==', $queried_user->notification_inbox->id, 'notification inbox/user link');
    is($ninbox->common_name, '__' . $queried_user->userid, 'notification inbox common name');
    is($ninbox->url_name, undef, 'ninbox url name');
    cmp_ok($ninbox->creator->id,       '==', $queried_user->id, 'notification inbox creator');
    cmp_ok($ninbox->single_author,     '==', 0,                 'notification inbox single author');
    cmp_ok($ninbox->single_subscriber, '==', 1,                 'notification inbox single subscriber');
    cmp_ok($ninbox->requires_author_authorization, '==', 0, 'notification inbox requires author authorization');
    is($ninbox->type, 'system', 'notification inbox stream type');

    # Moderatorships for ninbox
    my @ninbox_mods = $self->{meritcommons}->m->resultset('Stream::Moderator')->search(
        {
            stream => $ninbox->id,
        }
    )->all;
    cmp_ok(scalar(@ninbox_mods), '==', 1, 'Just one personal notification inbox moderator');
    my $ninbox_mod = $ninbox_mods[0];
    cmp_ok($ninbox_mod->meritcommons_user->id, '==', $queried_user->id, 'notification inbox moderator');
    cmp_ok($ninbox_mod->added_by->id, '==', 1, 'notification inbox moderator added by');

    # Authorships for ninbox
    my @ninbox_authors = $self->{meritcommons}->m->resultset('Stream::Author')->search(
        {
            stream => $ninbox->id,
        }
    )->all;
    cmp_ok(scalar(@ninbox_authors), '==', 0, 'No personal notification inbox authorships');

    # Subscriptions for ninbox
    my @ninbox_subs = $self->{meritcommons}->m->resultset('Stream::Subscriber')->search(
        {
            stream => $ninbox->id,
        }
    )->all;
    cmp_ok(scalar(@ninbox_subs), '==', 1, 'Just one personal notification inbox subscription');
    my $ninbox_sub = $ninbox_subs[0];
    cmp_ok($ninbox_sub->meritcommons_user->id, '==', $queried_user->id, 'notification inbox subscription');
    cmp_ok($ninbox_sub->added_by->id,       '==', 1,                 'notification inbox subcription added by');
    cmp_ok($ninbox_sub->authorized,         '==', 1,                 'notification inbox subscription authorized');
    cmp_ok($ninbox_sub->allow_history,      '==', 1,                 'notification inbox subscription allow edit');

    # System stream subscription
    my @system_subs = $self->{meritcommons}->m->resultset('Stream::Subscriber')->search(
        {
            stream         => 1,
            meritcommons_user => $queried_user->id,
        }
    )->all;
    cmp_ok(scalar(@system_subs), '==', 1, 'Just one subscription to system stream');
    my $system_sub = $system_subs[0];
    cmp_ok($system_sub->added_by->id,  '==', 1, 'system subcription added by');
    cmp_ok($system_sub->authorized,    '==', 1, 'system subscription authorized');
    cmp_ok($system_sub->allow_history, '==', 1, 'system subscription allow edit');

    # Identity stuff
    cmp_ok(scalar($queried_user->identities), '==', 1);
}

# Most of the authentication coverage is in AuthViaLocalUser.pm.  This is just to finish it up
sub localauth_auth_coverage : Test(4) {
    my $self      = shift;
    my $meritcommons = $self->{meritcommons};

    my $test_username    = 'testguy2';
    my $test_common_name = 'TEST GUY2';
    my $test_pass        = 'testpass2';

    my $user = $meritcommons->new_local_user($test_username, $test_common_name, $test_pass);

    my $queried_user = $self->{meritcommons}->m->resultset('User')->search(
        {
            id => $user->id,
        }
    )->first;
    
    ok(!_ldap_test($meritcommons), "application object does not have ldap support, presumably we're using LocalAuth");
    isnt($meritcommons->authenticate_user($test_username, $test_pass), undef, 'localauth authenticate reference');
    dies_ok { $meritcommons->authenticate_user($test_username, undef) } 'localauth authenticate no pass';
    dies_ok { $meritcommons->authenticate_user(undef,          $test_pass) } 'localauth authenticate no username';
}

sub _ldap_test {
    my ($app) = @_;
    eval {
        $app->fetch_ldap;    
    };
        
    return $@ ? 0 : 1;
}

sub clean_up : Test(shutdown) {
}

1;
