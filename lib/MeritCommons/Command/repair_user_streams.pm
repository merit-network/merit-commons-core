#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::repair_user_streams;

use Mojo::Base 'Mojolicious::Command';

has description => "repairs a user's streams\n";
has usage       => "Usage: $0 repair_user_streams [USER]\n";

sub run {
    my ($self, $username) = @_;
    unless ($username) {
        print $self->usage;
        return;
    }

    my $repaired;
    my $user  = $self->app->user($username);
    my $model = $self->app->m;

    if ($user) {
        unless ($user->personal_outbox && $user->personal_outbox->unique_id) {

            # create the user's personal_outbox, or establish the relationship.
            my $outbox;
            unless ($outbox = $model->resultset('Stream')->find({ url_name => $user->userid })) {
                $outbox = $model->resultset('Stream')->create(
                    {
                        common_name                   => $user->common_name,
                        url_name                      => $user->userid,
                        unique_id                     => $self->app->new_uuid,
                        creator                       => $user->id,
                        single_author                 => 1,
                        requires_author_authorization => 1,
                        personal_outbox_user          => $user->id,
                        type                          => 'system',
                    }
                );
            }

            unless ($user->is_moderator($outbox)) {
                $model->resultset('Stream::Moderator')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $outbox->id,
                        added_by       => 1,             # the system user.
                    }
                );
            }

            unless ($user->is_author($outbox)) {
                $model->resultset('Stream::Author')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $outbox->id,
                        authorized     => 1,
                        allow_edit     => 1,
                        added_by       => 1,             # the system user.
                    }
                );
            }

            unless ($user->is_subscriber($outbox)) {

                # subscribe them to their own stream
                $model->resultset('Stream::Subscriber')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $outbox->id,
                        authorized     => 1,
                        allow_history  => 1,
                        added_by       => 1,             # the system user.
                    }
                );
            }

            # make sure we're the outbox user.
            $user->personal_outbox($outbox);
            $user->update;

            $outbox->personal_outbox_user($user);
            $outbox->update;

            $self->app->add_stream_index($outbox);

            print "[info]: repaired personal_outbox relationship...\n";

            $repaired = 1;
        }

        unless ($user->personal_inbox && $user->personal_inbox->unique_id) {

            # create the user's personal_inbox, or establish the relationship.
            my $inbox;
            unless ($inbox = $model->resultset('Stream')->find({ common_name => '_' . $user->userid })) {
                $inbox = $model->resultset('Stream')->create(
                    {
                        common_name                   => '_' . $user->userid,
                        unique_id                     => $self->app->new_uuid,
                        creator                       => $user->id,
                        single_subscriber             => 1,
                        requires_author_authorization => 0,
                        personal_inbox_user           => $user->id,
                        type                          => 'system',
                    }
                );
            }

            unless ($user->is_moderator($inbox)) {
                $model->resultset('Stream::Moderator')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $inbox->id,
                        added_by       => 1,            # the system user.
                    }
                );
            }

            unless ($user->is_author($inbox)) {
                $model->resultset('Stream::Author')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $inbox->id,
                        authorized     => 1,
                        allow_edit     => 1,
                        added_by       => 1,            # the system user.
                    }
                );
            }

            unless ($user->is_subscriber($inbox)) {

                # subscribe them to their own stream
                $model->resultset('Stream::Subscriber')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $inbox->id,
                        authorized     => 1,
                        allow_history  => 1,
                        added_by       => 1,            # the system user.
                    }
                );
            }

            # make sure we're the inbox user.
            $user->personal_inbox($inbox);
            $user->update;

            $inbox->personal_inbox_user($user);
            $inbox->update;

            print "[info]: repaired personal_inbox relationship...\n";

            $repaired = 1;
        }

        unless ($user->notification_inbox && $user->notification_inbox->unique_id) {

            # create the user's personal_inbox, or establish the relationship.
            my $notification_inbox;
            unless ($notification_inbox = $model->resultset('Stream')->find({ common_name => '__' . $user->userid })) {
                $notification_inbox = $model->resultset('Stream')->create(
                    {
                        common_name                   => '__' . $user->userid,
                        unique_id                     => $self->app->new_uuid,
                        creator                       => $user->id,
                        single_subscriber             => 1,
                        requires_author_authorization => 0,
                        notification_inbox_user       => $user->id,
                        type                          => 'system',
                    }
                );
            }

            unless ($user->is_moderator($notification_inbox)) {
                $model->resultset('Stream::Moderator')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $notification_inbox->id,
                        added_by       => 1,                         # the system user.
                    }
                );
            }

            unless ($user->is_subscriber($notification_inbox)) {

                # subscribe them to their own stream
                $model->resultset('Stream::Subscriber')->create(
                    {
                        meritcommons_user => $user->id,
                        stream         => $notification_inbox->id,
                        authorized     => 1,
                        allow_history  => 1,
                        added_by       => 1,                         # the system user.
                    }
                );
            }

            # make sure we're the notification_inbox user.
            $user->notification_inbox($notification_inbox);
            $user->update;

            $notification_inbox->notification_inbox_user($user);
            $notification_inbox->update;

            print "[info]: repaired notification_inbox relationship...\n";

            $repaired = 1;
        }

        unless ($user->is_subscriber($self->app->stream(1))) {

            # make sure they sub to MeritCommons System Messages
            $model->resultset('Stream::Subscriber')->create(
                {
                    meritcommons_user => $user->id,
                    stream         => 1,
                    authorized     => 1,
                    allow_history  => 1,
                    added_by       => 1,           # the system user.
                }
            );

            print "[info]: repaired subscribership to MeritCommons System Messages\n";

            $repaired = 1;
        }

        if ($repaired) {
            print "[info]: finished repairing user $username\n";
        } else {
            print "[info]: couldn't find anything wrong with $username\'s streams\n";
        }
    }
}

1;
