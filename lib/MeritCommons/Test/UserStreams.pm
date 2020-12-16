package MeritCommons::Test::UserStreams;

use Mojo::Base -strict;

use base qw(Test::Class);
use MeritCommons::Test;
use Test::More;

use Mojo::JSON qw/encode_json/;
use Mojolicious::Commands;
use MeritCommons::Model;
use MeritCommons::Command::install_schema;
use MeritCommons::Command::new_local_user;

sub make_meritcommons : Test(startup => 2) {
    my $self = shift;
    my $t    = MeritCommons::Test->new();
    $self->{t} = $t;
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
    my $new_local_user_cmd = MeritCommons::Command::new_local_user->new;
    $new_local_user_cmd->{app} = $meritcommons;
    $new_local_user_cmd->run('testuserone', 'Test UserOne', 'testpassone');
    my $user1 = $meritcommons->m->resultset('User')->search(
        {
            userid => 'testuserone',
        }
    )->single;

    $self->{meritcommons} = $meritcommons;
    $self->{user1}     = $user1;
}

sub test_personal_outbox : Test(18) {
    my $self = shift;

    my @personal_outboxes = $self->{meritcommons}->m->resultset('Stream')->search(
        {
            personal_outbox_user => $self->{user1}->id,
        }
    )->all;
    cmp_ok(scalar(@personal_outboxes), '==', 1, 'just one personal_outbox');
    my $personal_outbox = $personal_outboxes[0];

    # personal_outbox attributes
    is($personal_outbox->common_name, $self->{user1}->common_name, 'personal_outbox common_name');
    is($personal_outbox->url_name,    $self->{user1}->userid,      'personal_outbox url_name');
    is_deeply($personal_outbox->creator,              $self->{user1}, 'personal_outbox creator');
    is_deeply($personal_outbox->personal_outbox_user, $self->{user1}, 'personal_outbox personal_outbox_user');
    cmp_ok($personal_outbox->single_author,                 '==', 1, 'personal_outbox single_author');
    cmp_ok($personal_outbox->requires_author_authorization, '==', 1, 'personal_outbox requires_author_authorization');
    is($personal_outbox->type, 'system', 'personal_outbox type');

    # personal_outbox permissions
    my @moderatorships = $self->{meritcommons}->m->resultset('Stream::Moderator')->search(
        {
            meritcommons_user => $self->{user1}->id,
            stream         => $personal_outbox->id,
        }
    )->all;
    cmp_ok(scalar(@moderatorships), '==', 1, 'just one moderatorship for personal_outbox');
    my $moderatorship = $moderatorships[0];
    cmp_ok($moderatorship->added_by->id, '==', 1, 'personal_outbox moderatorship added_by');

    my @authorships = $self->{meritcommons}->m->resultset('Stream::Author')->search(
        {
            meritcommons_user => $self->{user1}->id,
            stream         => $personal_outbox->id,
        }
    )->all;
    cmp_ok(scalar(@authorships), '==', 1, 'just one authorship for personal_outbox');
    my $authorship = $authorships[0];
    cmp_ok($authorship->authorized,   '==', 1, 'personal_outbox authorship authorized');
    cmp_ok($authorship->allow_edit,   '==', 1, 'personal_outbox authorship allow_edit');
    cmp_ok($authorship->added_by->id, '==', 1, 'personal_outbox authorship added_by');

    my @subscriptions = $self->{meritcommons}->m->resultset('Stream::Subscriber')->search(
        {
            meritcommons_user => $self->{user1}->id,
            stream         => $personal_outbox->id,
        }
    )->all;
    cmp_ok(scalar(@subscriptions), '==', 1, 'just one subscription for personal_outbox');
    my $subscription = $subscriptions[0];
    cmp_ok($subscription->authorized,    '==', 1, 'personal_outbox subscription authorized');
    cmp_ok($subscription->allow_history, '==', 1, 'personal_outbox subscription allow_history');
    cmp_ok($subscription->added_by->id,  '==', 1, 'personal_outbox subscription added_by');

}

sub test_personal_inbox : Tests() {
    my $self = shift;

    my @personal_inboxes = $self->{meritcommons}->m->resultset('Stream')->search(
        {
            personal_inbox_user => $self->{user1}->id,
        }
    )->all;

    cmp_ok(scalar(@personal_inboxes), '==', 1, 'number the query grabs');
    my $personal_inbox = $personal_inboxes[0];
    is($personal_inbox->common_name, '_' . $self->{user1}->userid);
    is_deeply($personal_inbox->creator,             $self->{user1});
    is_deeply($personal_inbox->personal_inbox_user, $self->{user1});
    cmp_ok($personal_inbox->single_subscriber,             '==', 1);
    cmp_ok($personal_inbox->requires_author_authorization, '==', 0);
    is($personal_inbox->type, 'system');
}

sub test_notification_inbox : Test(7) {
    my $self = shift;

    my @notification_inboxes = $self->{meritcommons}->m->resultset('Stream')->search(
        {
            notification_inbox_user => $self->{user1}->id,
        }
    )->all;

    cmp_ok(scalar(@notification_inboxes), '==', 1, 'number the query grabs');
    my $notification_inbox = $notification_inboxes[0];
    is($notification_inbox->common_name, '__' . $self->{user1}->userid);
    is_deeply($notification_inbox->creator,                 $self->{user1});
    is_deeply($notification_inbox->notification_inbox_user, $self->{user1});
    cmp_ok($notification_inbox->single_subscriber,             '==', 1);
    cmp_ok($notification_inbox->requires_author_authorization, '==', 0);
    is($notification_inbox->type, 'system');
}

sub clean_up : Test(shutdown) {
}

1;
