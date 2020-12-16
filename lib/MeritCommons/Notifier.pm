#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Notifier;

use base qw(Class::Accessor);
use MIME::Base64 qw(decode_base64);
use MeritCommons::Content;

__PACKAGE__->mk_accessors(qw/app/);

sub new {
    my ($class, $app, $line) = @_;
    my $self = bless({ app => $app }, $class);
    foreach my $trgrd (split(/\s+/, $line)) {
        if ($trgrd =~ /m\.(.+)$/) {
            push(@{ $self->{messages} }, $1);
        } elsif ($trgrd =~ /s\.(.+)$/) {
            push(@{ $self->{streams} }, $1);
        } elsif ($trgrd =~ /u\.(.+)$/) {
            push(@{ $self->{users} }, $1);
        } elsif ($trgrd =~ /\?\.(.+)$/) {
            push(@{ $self->{extra} }, $1);
        }
    }
    return $self;
}

# the main subroutine here.
sub send_notifications {
    my ($self) = @_;

    foreach my $watcher ($self->watchers) {
        my $content;
        if ($self->type eq "verbatim") {
            my $hr = {
                recipient     => $watcher,
                subtype       => $self->type,
                actor         => $self->actor,
                render_as     => 'notification',
                external_url  => $self->{extra}->[1],
                body          => decode_base64($self->{extra}->[2]),
                original_body => decode_base64($self->{extra}->[2]),
            };

            # this might be about a message!
            if (my $about = $self->about) {
                $hr->{about} = $about;
            }

            # this might be about a stream!
            if (my $regarding_stream = $self->regarding_stream) {
                $hr->{regarding_stream} = $regarding_stream;
            }

            $content = MeritCommons::Content->new($hr);
        } else {
            my $regarding;
            if ($self->type eq "comment" && $self->thread) {
                $regarding = $self->thread;
            } elsif ($self->type eq "comment" && $self->about->thread_id ne $self->about->unique_id) {
                $regarding = $self->app->message($self->about->thread_id);
            } else {
                $regarding = $self->about;
            }
            $content = MeritCommons::Content->new(
                {
                    recipient => $watcher,
                    subtype   => $self->type,
                    thread    => $self->thread,
                    regarding => $regarding,
                    about     => $self->about,
                    actor     => $self->actor,
                    render_as => 'notification',
                }
            );

            # content driver stack.
            $content = $self->app->cd_notification($content, $self->actor, $self);
        }

        # put it to the database and zmq.
        $self->send_notification($content);
    }

}

sub regarding_stream {
    my ($self) = @_;
    unless ($self->{regarding_stream}) {
        if ($self->{streams}->[0]) {
            $self->{regarding_stream} = $self->app->stream($self->{streams}->[0]);
        }
    }
    return $self->{regarding_stream};
}

sub about {
    my ($self) = @_;
    unless ($self->{about}) {
        if ($self->{messages}->[0]) {
            $self->{about} = $self->app->message($self->{messages}->[0]);
        }
    }
    return $self->{about};
}

sub thread {
    my ($self) = @_;
    if ($self->{messages}->[1] && $self->{messages}->[1] ne $self->{messages}->[0]) {
        unless ($self->{regarding}) {
            $self->{regarding} = $self->app->message($self->{messages}->[1]);
        }
    } else {
        return undef;
    }
}

sub actor {
    my ($self) = @_;
    unless ($self->{actor}) {
        $self->{actor} = $self->app->user($self->{users}->[0]);
    }
    return $self->{actor};
}

sub type {
    my ($self, $type) = @_;
    if ($type) {
        $self->{type} = $type;
    } else {
        unless ($self->{type}) {
            if ($type = $self->{extra}->[0]) {
                $self->{type} = $type;
            }
        }
    }
    if (my $type = $self->{extra}->[0]) {
        return $type;
    }
    return undef;
}

sub watchers {
    my ($self) = @_;

    my @watchers;
    if (my $thread = $self->thread) {
        @watchers = $thread->watchers;
        foreach my $msg ($self->thread, $self->about) {

            # add people mentioned in the parent or this message as watchers
            foreach my $stream ($msg->streams({ personal_inbox_user => { '!=' => undef } })) {
                if (my $user = $stream->personal_inbox_user) {
                    my $found = 0;
                    foreach my $w (@watchers) {
                        if ($w->unique_id eq $user->unique_id) {
                            $found = 1;
                            last;
                        }
                    }

                    if (!$found) {
                        push(@watchers, $user);
                    }
                }
            }
        }
    } elsif (my $about = $self->about) {
        @watchers = $about->watchers;

        # add people mentioned in this message as watchers.
        foreach my $stream ($about->streams({ personal_inbox_user => { '!=' => undef } })) {
            if (my $user = $stream->personal_inbox_user) {
                my $found = 0;
                foreach my $w (@watchers) {
                    if ($w->unique_id eq $user->unique_id) {
                        $found = 1;
                        last;
                    }
                }

                if (!$found) {
                    push(@watchers, $user);
                }
            }
        }
    }

    if (my $regarding_stream = $self->regarding_stream) {
        push(@watchers, $regarding_stream->watchers);
    }

    # include every user mentioned in the notification.
    push(@watchers, map { $self->app->user($_) } $self->users);

    # return the watchers that aren't the one who created the notification!
    return grep { ($_ && $_->unique_id ne $self->actor->unique_id) } @watchers;
}

sub is_originator {
    my ($self, $watcher) = @_;
    if (my $thread = $self->thread) {
        if ($thread->submitter->unique_id eq $watcher->unique_id) {
            return 1;
        }
    } elsif (my $msg = $self->about) {
        if ($msg->submitter->unique_id eq $watcher->unique_id) {
            return 1;
        }
    }
    return undef;
}

sub user_as_href {
    my ($self, $user) = @_;
    return '<a href="/u/' . $user->userid . '/">' . $user->common_name . '</a>';
}

# get a summary of all participants in an activity (like or comment or chat) from the perspective of $user.
# Description of behavior:
# Name up to 3 (w/ friend order bias): Bob Simmons, Bob Rudy, and Bob Winehouse
# Name any 2 and count (w/ friend order bias, up to 10): Bob Simmons, Bob Rudy, and 8 others
# Count only (when none friended): 10 people
# Count plus friended associations (when friends w/ some and count over 10): Bob Simmons, Bob Winehouse, and 15 others
sub activity_participant_summary {
    my ($self, $content, $first_participant) = @_;

    my $msg  = $content->thread ? $content->thread : $content->about;
    my $user = $content->recipient;
    my $type = $content->subtype;

    # get this.
    my %following = map { $_->unique_id => $_ } $user->following;

    # also this.
    my @participants;

    if ($type eq "like") {
        @participants = $msg->like_participants;
    } elsif ($type eq "dislike") {
        @participants = $msg->dislike_participants;
    } else {
        @participants = $msg->thread_participants;
    }

    my @count_participants;
    my @named_participants;

    # ensure the first participant comes first.
    if ($first_participant) {

        # we're adding the first participant to named_participants so it will for sure be counted, and counted first!
        @named_participants = ($first_participant);

        # now let's copy over all of the participants except the one we've explicitly named
        my @new_participants;
        foreach my $p (@participants) {
            unless ($p->id == $first_participant->id) {
                push(@new_participants, $p);
            }
        }
        @participants = @new_participants;
    }

    foreach my $participant (@participants) {

        # don't count ourselves!
        next if $participant->unique_id eq $user->unique_id;

        if (exists($following{ $participant->unique_id })) {
            if (scalar(@named_participants) > 3) {
                push(@named_participants, $participant);
            } else {
                push(@count_participants, $participant);
            }
        } else {
            push(@count_participants, $participant);
        }
    }

    # move over one or two count participants to become named participants if we've got less than 2.
    if (scalar(@count_participants) && scalar(@named_participants) < 2) {
        my $pop_off = 0;
        if (scalar(@count_participants) == 1) {
            $pop_off = -1;
        } else {
            $pop_off = 0 - (2 - scalar(@named_participants));
        }
        push(@named_participants, splice(@count_participants, $pop_off));
    }

    my ($countnum, $namednum) = (scalar(@count_participants), scalar(@named_participants));

    my $summary;
    if ($namednum) {
        if ($countnum) {
            $summary =
              join(', ', map { "<a href='/u/" . $_->userid . "/'>" . $_->common_name . "</a>" } @named_participants) .
              " and $countnum others";
        } else {
            if ($namednum == 1) {
                $summary =
                  "<a href='/u/" .
                  $named_participants[0]->userid . "/'>" . $named_participants[0]->common_name . "</a>";
            } else {
                $summary = join(', ',
                    map { "<a href='/u/" . $_->userid . "/'>" . $_->common_name . "</a>" }
                      @named_participants[ 0 .. $namednum - 2 ]);
                $summary .=
                  " and <a href='/u/" . $named_participants[ $namednum - 1 ]->userid .
                  "/'>" . $named_participants[ $namednum - 1 ]->common_name . "</a>";
            }
        }
    } else {
        if ($countnum == 1) {
            $summary = "$countnum person";
        } else {
            $summary = "";
        }
    }

    return $summary;
}

# simple accessors that return lists instead of arrayrefs.
sub extra {
    return (@{ shift->{extra} });
}

sub messages {
    return (@{ shift->{messages} });
}

sub streams {
    return (@{ shift->{streams} });
}

sub users {
    return (@{ shift->{users} });
}

sub send_notification {
    my ($self, $content) = @_;

    my $app = $self->app;
    my $msg;

    # don't try and send notifications to users without notification inboxes (e.g. MeritCommons System)
    my $ni = $content->recipient->notification_inbox;
    return unless $ni;

    # let likes clobber dislike, and dislikes clobber likes.
    if ($content->subtype eq "like" || $content->subtype eq "dislike") {
        $msg = $ni->messages(
            {
                -and => [ regarding => $content->regarding->unique_id, about   => $content->about->unique_id ],
                -or  => [ subtype   => 'like',                         subtype => 'dislike' ],
            },
            {
                order_by => {
                    "-desc" => ['message.post_time'],
                },
            }
        )->first;
    } elsif ($content->subtype ne "verbatim") {
        $msg = $ni->messages(
            {
                regarding => $content->regarding->unique_id,
                subtype   => $content->subtype
            },
            {
                order_by => {
                    "-desc" => ['message.post_time']
                },
            }
        )->first;
    }

    if ($msg && !$msg->is_read_by($content->recipient)) {

        # edit in place
        $msg->body($content->body);
        $msg->original_body($content->body);
        $msg->subtype($content->subtype);
        if ($content->about) {
            $msg->about($content->about->unique_id);
        }
        $msg->post_time(time);
        $msg->submitter($content->actor->id);
        $msg->update;
    } else {

        # create a new one
        my $hr = {
            submitter     => $content->actor->id,
            render_as     => "notification",
            unique_id     => $app->new_uuid,
            public        => 1,
            serialized    => 0,
            body          => $content->body,
            original_body => $content->body,
            subtype       => $content->subtype,
        };

        # we're regarding a message or a thread
        if (my $regarding = $content->regarding) {
            $hr->{regarding} = $content->regarding->unique_id;
        }

        # we might be regarding a thread about a message
        if (my $about = $content->about) {
            $hr->{about} = $content->about->unique_id;
        }

        # we're regarding a stream
        if (my $regarding_stream = $content->regarding_stream) {
            $hr->{regarding_stream} = $regarding_stream->unique_id;
        }

        # if we have an external url make sure to set it
        if (my $external_url = $content->external_url) {
            $hr->{external_url} = $external_url;
        }

        $msg = $app->m->resultset('Stream::Message')->create($hr);

        # stream assignment.
        $self->app->m->resultset('Stream::MessageStream')->create(
            {
                stream  => $ni->id,
                message => $msg->id,
            }
        );
    }

    # tell the publisher.
    $app->pub_write(join(" ", $ni->unique_id, $msg->unique_id));
}

1;
