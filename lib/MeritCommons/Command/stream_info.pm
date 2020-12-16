#    MeritCommons Portal
#    Copyright 2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::stream_info;

use Mojo::Base 'Mojolicious::Command';
use File::Find;
use Text::Wrap;

has description => "Show detailed information about a stream.\n";
has usage       => "Usage: $0 stream_info [stream_name] [section(s) (optional)]\n";

sub run {
    my ($self, @args) = @_;

    my $left_width = 40;

    my $stream;
    unless ($stream = $self->app->stream($args[0])) {
        print $self->usage;
        return;
    }

    my %sections;
    if ($args[1]) {
        my @sections_raw = split(',', $args[1]);
        %sections = map { $_ => 1 } @sections_raw;
    } else {
        $sections{'default'} = 1;
    }

    if ($sections{'basic'} or $sections{'all'} or $sections{'default'}) {
        print "Basic Stream Information\n";
        print "------------------------\n";
        printf("%-${left_width}s: %-50s\n", "Common Name", $stream->common_name);
        printf(
            "%-${left_width}s: %-50s\n",
            "ID / Unique ID / External ID",
            $stream->id . " / " . $stream->unique_id . " / " . ($stream->external_unique_id || "<none>")
        );
        printf("%-${left_width}s: %-50s\n", "URL Name", $stream->url_name);
        printf("%-${left_width}s: %-50s\n",
            "Created",
            scalar(localtime($stream->create_time)) .
              " by " . $stream->creator->common_name . " (" . $stream->creator->userid . ")");
        printf("%-${left_width}s: %-50s\n", "Modified", scalar(localtime($stream->modify_time)));
        printf(
            "%-${left_width}s: %-50s\n",
            "Subs / Authors / Mods",
            $stream->subscriber_count . " / " . $stream->author_count . " / " . $stream->moderator_count
        );
        printf("%-${left_width}s: %-50s\n", "Total Posts (Including Comments)", $stream->messages->count || "<none>");
        printf("%-${left_width}s: %-50s\n", "Configuration",                    $stream->configuration   || "<none>");
        printf("%-${left_width}s: %-50s\n", "Origin",                           $stream->origin          || "<none>");
        printf("%-${left_width}s: %-50s\n", "Type / Subtype", $stream->type . " / " . ($stream->subtype || "<none>"));

        if ($stream->personal_inbox_user) {
            printf(
                "%-${left_width}s: %-50s\n",
                "Personal Inbox?",
                $stream->personal_inbox_user->common_name . " (" . $stream->personal_outbox_user->userid . ")"
            );
        } else {
            printf("%-${left_width}s: %-50s\n", "Personal Inbox?", "No");
        }
        if ($stream->personal_outbox_user) {
            printf(
                "%-${left_width}s: %-50s\n",
                "Personal Outbox?",
                $stream->personal_outbox_user->common_name . " (" . $stream->personal_outbox_user->userid . ")"
            );
        } else {
            printf("%-${left_width}s: %-50s\n", "Personal Outbox?", "No");
        }
        if ($stream->notification_inbox_user) {
            printf(
                "%-${left_width}s: %-50s\n",
                "Notification Inbox?",
                $stream->notification_inbox_user->common_name . " (" . $stream->notification_outbox_user->userid . ")"
            );
        } else {
            printf("%-${left_width}s: %-50s\n", "Notification Inbox?", "No");
        }
        printf("%-${left_width}s: %-50s\n", "Keywords", $stream->keywords || "<none>");

        if ($stream->description && length($stream->description) > 50) {
            print "\nDescription\n";
            print "-----------\n";
            print $stream->description . "\n";
        } else {
            printf("%-${left_width}s: %-50s\n", "Description", $stream->description || "<none>");
        }
        print "\n";
    }

    if ($sections{'perms'} or $sections{'all'} or $sections{'default'}) {
        print "Permissions, Security, and Privacy\n";
        print "----------------------------------\n";
        printf("%-${left_width}s: %-50s\n", "Enabled?", $stream->disabled ? "No" : "Yes");
        printf(
            "%-${left_width}s: %-50s\n",
            "Subscriber Authorization required?",
            $stream->requires_subscriber_authorization ? "Yes" : "No"
        );
        printf(
            "%-${left_width}s: %-50s\n",
            "Author Authorization required?",
            $stream->requires_author_authorization ? "Yes" : "No"
        );
        printf("%-${left_width}s: %-50s\n", "Allow Unsubscribe?",   $stream->allow_unsubscribe   ? "Yes" : "No");
        printf("%-${left_width}s: %-50s\n", "Allow add moderator?", $stream->allow_add_moderator ? "Yes" : "No");
        printf("%-${left_width}s: %-50s\n", "Open reply?",          $stream->open_reply          ? "Yes" : "No");
        printf("%-${left_width}s: %-50s\n", "Show Publicly?",       $stream->show_publicly       ? "Yes" : "No");
        printf("%-${left_width}s: %-50s\n", "Display Subscribers?", $stream->display_subscribers ? "Yes" : "No");
        printf("%-${left_width}s: %-50s\n", "Members can invite?",  $stream->members_can_invite  ? "Yes" : "No");
        printf("%-${left_width}s: %-50s\n", "Private?",             $stream->private             ? "Yes" : "No");
        printf(
            "%-${left_width}s: %-50s\n",
            "Does membership require mod approval?",
            $stream->membership_requires_moderator_approval ? "Yes" : "No"
        );
        print "\n";
    }

    if ($sections{'subs'} or $sections{'all'}) {
        print "Subscribers\n";
        print "-----------\n";

        my @subs = $stream->get_authed_subscribers;

        if (!scalar(@subs)) {
            print "\tNone.\n";
        }

        foreach my $sub (@subs) {
            print "\t" . $sub->meritcommons_user->common_name . " (" . $sub->meritcommons_user->userid . ") as of " .
              scalar(localtime($sub->create_time)) .
              " by " . $sub->added_by->common_name . " (" . $sub->added_by->userid . ")\n";
        }
        print "\n";
    }

    if ($sections{'authors'} or $sections{'all'}) {
        print "Authors\n";
        print "-------\n";

        my @auths = $stream->get_authed_authors;

        if (!scalar(@auths)) {
            print "\tNone.\n";
        }

        foreach my $auth (@auths) {
            print "\t" . $auth->meritcommons_user->common_name . " (" . $auth->meritcommons_user->userid . ") as of " .
              scalar(localtime($auth->create_time)) .
              " by " . $auth->added_by->common_name . " (" . $auth->added_by->userid . ")\n";
        }
        print "\n";
    }

    if ($sections{'mods'} or $sections{'all'}) {
        print "Moderators\n";
        print "----------\n";

        my @mods = $stream->moderators;

        if (!scalar(@mods)) {
            print "\tNone.\n";
        }

        foreach my $mod (@mods) {
            print "\t" . $mod->meritcommons_user->common_name . " (" . $mod->meritcommons_user->userid . ") as of " .
              scalar(localtime($mod->create_time)) .
              " by " . $mod->added_by->common_name . " (" . $mod->added_by->userid . ")\n";
        }
        print "\n";
    }

    if ($sections{'invites'} or $sections{'all'}) {
        print "Invites\n";
        print "-------\n";

        my @invitees = $stream->invitees;

        if (!scalar(@invitees)) {
            print "\tNone.\n";
        }

        foreach my $i (@invitees) {
            print "\t" . $i->invitee->common_name . " (" . $i->invitee->userid . ") as of " .
              scalar(localtime($i->create_time)) . " by " . $i->inviter->common_name .
              " (" . $i->inviter->userid . ")\n" . $i->approved ? ", approved" : ", unapproved";
        }
        print "\n";
    }

    if ($sections{'watchers'} or $sections{'all'}) {
        print "Watchers\n";
        print "--------\n";

        my @watchers = $stream->watchers;

        if (!scalar(@watchers)) {
            print "\tNone.\n";
        }

        foreach my $w (@watchers) {
            print "\t" . $w->watcher->common_name . " (" . $w->watcher->userid . ") as of " .
              scalar(localtime($w->create_time)) . "\n";
        }
        print "\n";
    }
}

1;

