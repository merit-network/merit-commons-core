#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::delete_user;

use Mojo::Base 'Mojolicious::Command';

has description => "delete a user\n";
has usage       => "Usage: $0 delete_user [USER]\n";

sub run {
    my ($self, $username) = @_;
    unless ($username) {
        print $self->usage;
        return;
    }

    my $user = $self->app->user($username);

    unless ($user) {
        print "Can't find user $username!\n";
        return;
    }

    foreach my $stream ((map { $user->$_ } qw/personal_inbox personal_outbox notification_inbox/), $user->streams) {
        #print "Deleting " . $stream->common_name . "\n";
        if ($stream && $stream->messages->count > 0) {
            foreach my $message ($stream->messages->all) {

                # this is a parent.
                if ($message->thread_id && ($message->thread_id eq $message->unique_id)) {
                    print "DELETING DIRECT REPLIES\n";
                    foreach (my $reply = $message->replies) {
                        $reply->delete;
                    }

                    print "DELETING REGARDINGS\n";
                    foreach (my $reply = $message->regarding_me) {
                        $reply->delete;
                    }

                    print "DELETING THREAD REPLIES\n";
                    foreach (my $reply = $message->thread_replies) {
                        $reply->delete;
                    }

                    print "DELETING VOTES\n";
                    foreach (my $vote = $message->votes) {
                        $vote->delete;
                    }

                }

                print "DELETING MESSAGE\n";
                $message->delete;
                $message->message_streams->delete;
            }
        }
        
        if (my $rs = $self->app->m->resultset('Stream::Message')->search({regarding_stream => $stream->unique_id})) {    
            foreach my $message ($rs->all) {
                print "DELETING MESSAGE REGARDING STREAM @{[$stream->common_name]}\n";
                $message->delete;
            }
        }
    }

    if (my $local_auth = $self->app->m->resultset('LocalAuth')->find({ meritcommons_user => $user->id })) {
        $local_auth->delete;
    }

    foreach my $vote ($user->votes) {
        $vote->delete;
    }

    foreach my $tag ($user->message_tags) {
        $tag->delete;
    }

    foreach my $submitted ($user->submitted_messages) {
        $submitted->delete;
    }

    # move added bys...
    foreach my $sam (qw/Stream::Subscriber Stream::Moderator Stream::Author/) {
        foreach my $added ($self->app->m->resultset($sam)->search({added_by => $user->id})->all) {
            $added->added_by(1);
            $added->update;
        }
    }

    $user->delete;

    warn "User '$username' deleted.\n";

}

1;
