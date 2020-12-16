#    MeritCommons Portal
#    Copyright 2013-2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::MailUtil;
use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/croak/;
use File::Path qw/make_path/;
use Mail::Sender;

sub register {
    my ($self, $app) = @_;

    # we're going to override Mail::Sender's X-Mailer
    $Mail::Sender::NO_X_MAILER = 1;

    my $ms_opts = {
        smtp    => $app->global_config->{smtp_host},
        from    => $app->global_config->{smtp_from},
        port    => $app->global_config->{smtp_port} || 25,
        headers => {
            'X-Mailer' => $app->version_banner,
        },
    };

    # if authenticated SMTP is enabled, let's add that info too
    if (my $method = $app->global_config->{smtp_auth}) {
        $ms_opts->{auth}         = $method;
        $ms_opts->{authid}       = $app->global_config->{smtp_username};
        $ms_opts->{authpwd}      = $app->global_config->{smtp_password};
        $ms_opts->{tls_required} = 1;
    }

    # create the object and throw it in a helper
    my $mail_sender = Mail::Sender->new($ms_opts);
    $app->helper(
        mail_sender => sub {
            return $mail_sender;
        }
    );

    $app->helper(send_digest        => \&_send_digest);
    $app->helper(send_digest_daily  => \&_send_digest_daily);
    $app->helper(send_digest_weekly => \&_send_digest_weekly);
    $app->helper(send_email         => \&_send_email);
    $app->helper(render_digest      => \&_render_digest);
    $app->helper(exclude_shown      => \&_exclude_shown);
}

sub _exclude_shown {
    my ($c, @list) = @_;
    no warnings 'uninitialized';
    return grep {
        $_ &&
          !(exists $c->stash->{shown}->{ $_->{message_id} } || exists $c->stash->{shown}->{ $_->{regarding} })
    } @list;
}

sub _send_email {
    my ($c, $recipient, $subject, $plaintext_body, $html_body) = @_;

    # allow for named arguments, too.
    if (ref($recipient) eq "HASH") {
        $subject        = $recipient->{subject};
        $plaintext_body = $recipient->{plaintext_body};
        $html_body      = $recipient->{html_body};
        $recipient      = $recipient->{recipient};
    }

    # transform user object into recipient string
    if (ref($recipient) eq "MeritCommons::Model::User") {
        $recipient = "@{[$recipient->common_name]} <@{[$recipient->email_address]}>";
    }

    eval {
        $c->mail_sender->OpenMultipart(
            {
                to        => $recipient,
                subject   => $subject,
                multipart => 'mixed',
            }
          )->Part(
            {
                ctype => 'multipart/alternative',
            }
          )->Part(
            {
                ctype       => 'text/plain',
                disposition => 'NONE',
                msg         => $plaintext_body,
            }
          )->Part(
            {
                ctype       => 'text/html',
                disposition => 'NONE',
                msg         => $html_body,
            }
          )->EndPart('multipart/alternative')->Close;
    } or $c->app->log->error("Error sending mail to '$recipient': $Mail::Sender::Error; $@");
}

sub _send_digest_daily {
    my ($c) = @_;

    my @digest_users = $c->app->rorm->resultset("User")->search(
        {
            "attributes.k" => "_config_email-digest-interval",
            "vals.v"       => 24,
        },
        {
            join => {
                attributes => {
                    vals => "attribute",
                },
            },
            distinct => 1,
        }
    )->all;

    foreach my $user (@digest_users) {
        my $opts = {
            interval => $user->config('email-digest-interval'),
            after    => time - $user->config('email-digest-interval') * 3600,
            limit    => 100,
            user     => $user,
        };

        _send_digest($c, $opts);
    }
}

sub _send_digest_weekly {
    my ($c) = @_;

    my @digest_users = $c->app->rorm->resultset("User")->search(
        {
            "attributes.k" => "_config_email-digest-interval",
            "vals.v"       => 168,
        },
        {
            join => {
                attributes => {
                    vals => "attribute",
                },
            },
            distinct => 1,
        }
    )->all;

    foreach my $user (@digest_users) {
        my $opts = {
            interval => $user->config('email-digest-interval'),
            after    => time - $user->config('email-digest-interval') * 3600,
            limit    => 100,
            user     => $user,
        };

        _send_digest($c, $opts);
    }
}

sub _send_digest {
    my ($c, $opts) = @_;

    my $user     = $opts->{user};
    my $after    = $opts->{after} || time;
    my $interval = $opts->{interval};

    my $digest = __generate_digest($c, $opts);

    my @tc = localtime(time);

    my $system_title = $c->app->config('system_title') || 'MeritCommons';

    my $subject;
    my $interval_sent;
    if ($interval == 24) {
        $subject = $system_title . " Daily Digest for " . sprintf("%02d/%02d/%d", $tc[4] + 1, $tc[3], $tc[5] + 1900);
        $interval_sent = "daily";
    } elsif ($interval == 168) {
        my @otc = localtime(time - $interval * 3600);
        $subject =
          $system_title . " Weekly Digest for " .
          sprintf("%02d/%02d/%d", $otc[4] + 1, $otc[3], $otc[5] + 1900) . " to " .
          sprintf("%02d/%02d/%d", $tc[4] + 1,  $tc[3],  $tc[5] + 1900);
        $interval_sent = "weekly";
    }

    my $digest_html;
    if ($digest_html = $digest->{digest_html}) {

        # everything _send_email needs to know about our digest to send it
        my $digest_email = {
            subject        => $subject,
            plaintext_body => "View this digest in your browser by heading to " . $digest->{digest_url},
            html_body      => $digest_html,
            recipient      => $user,
        };

        _send_email($c, $digest_email);

        # let's log this momentous occasion of sending a digest
        $c->app->log->info("[email_digest] " . $interval_sent .
              " digest " . $digest->{digest_id} . " delivered to " . $user->email_address . " (" . $user->userid . ")");
        $c->app->audit_log("sent an email digest (" .
              $digest->{digest_id} . ") to " . $user->email_address . " (" . $user->userid . ")");
    }

    return $digest_html;
}

sub _render_digest {
    my ($c, $opts) = @_;

    my $after = $opts->{after} || time;
    my $lim   = $opts->{limit} || 100;
    my $user  = $opts->{user};
    my $digest_id  = $opts->{digest_id}  // $c->new_uuid;
    my $digest_url = $opts->{digest_url} // '';

    # stash our digest content before rendering
    $c->stash(mentioned_you => [ __mentioned_you($c, $opts) ]);
    $c->stash(you_moderate => [ __you_moderate($c, $opts) ]);
    $c->stash(replies => [ __replies($c, $opts) ]);
    $c->stash(subscribed_to => [ __subscribed_to($c, $opts) ]);
    $c->stash(email_digest_notifications => [ __notifications($c, $opts) ]);
    $c->stash(digest_url => $digest_url);

    # for keeping track of what we've already rendered
    $c->stash(shown => {});

    # render
    my $digest_html;
    if (@{ $c->stash('mentioned_you') }[0] ||
        @{ $c->stash('you_moderate') }[0] ||
        @{ $c->stash('replies') }[0]      ||
        @{ $c->stash('subscribed_to') }[0]) {
        $digest_html = $c->render_to_string('mail/digest');
    }

    return $digest_html;
}

sub __generate_digest {
    my ($c, $opts) = @_;

    my $after = $opts->{after} || time;
    my $lim   = $opts->{limit} || 100;
    my $user  = $opts->{user};

    # generate UUID for this digest
    my $digest_id = $c->new_uuid;

    # set up digest write directory
    my @tc = localtime(time);
    my $digest_path = "digests" . sprintf("/%d/%02d/%02d", $tc[5] + 1900, $tc[4] + 1, $tc[3]);
    make_path("$ENV{MERITCOMMONS_UPLOAD_PATH}/$digest_path");
    my $digest_url = $c->asset_url("$digest_path/$digest_id.html");

    # render
    my $digest_html = $c->render_digest(
        {
            after      => $after,
            limit      => $lim,
            user       => $user,
            digest_id  => $digest_id,
            digest_url => $digest_url,
        }
    );

    # write to file
    if ($digest_html) {
        open my $digest_file, ">", "$ENV{MERITCOMMONS_UPLOAD_PATH}/$digest_path/$digest_id.html"
          or die "Can't open file for writing: $!\n";
        print $digest_file $digest_html;
        close $digest_file;
    }

    # return html and url
    my $result = {
        digest_id   => $digest_id,
        digest_html => $digest_html,
        digest_url  => $digest_url,
    };

    return $result;
}

sub __mentioned_you {
    my ($c, $opts) = @_;

    my $after = $opts->{after} || time;
    my $lim   = $opts->{limit} || 100;
    my $user  = $opts->{user};

    my $message_streams = $c->app->rorm->resultset('Stream::MessageStream')->search(
        {
            'me.stream' => [ $user->personal_inbox->id ],
        }
    );

    # list of message unique_ids
    my @mentioned_you = map { $_->unique_id } $c->app->rorm->resultset('Stream::Message')->search(
        {
            -and => [
                'me.post_time' => { '>' => $after },
                'me.id'        => {
                    -in => $message_streams->get_column('message')->as_query,
                },
                'me.submitter' => { '!=' => $user->id },
                'me.thread_id' => \'= me.unique_id',
            ]
        },
        {
            prefetch => ['submitter'],
            rows     => $lim,
            order_by => {
                "-desc" => ['me.post_time']
            },
        }
    )->all;

    if (scalar @mentioned_you) {
        return
          map { $c->app->msg->prepare($_, $user) } $user->authorized_messages_filter(@mentioned_you)->all;
    }
}

sub __you_moderate {
    my ($c, $opts) = @_;

    my $after = $opts->{after} || time;
    my $lim   = $opts->{limit} || 100;
    my $user  = $opts->{user};

    my @moderated_streams;
    my @streams = $c->streams->moderated_by($user);
    foreach my $stream (@streams) {
        push(@moderated_streams, $stream->id);
    }

    my $message_streams = $c->rorm->resultset('Stream::MessageStream')->search(
        {
            'me.stream' => {
                -in => \@moderated_streams,
            },
        }
    );

    # list of message ids
    my @you_moderate = map { $_->unique_id } $c->rorm->resultset('Stream::Message')->search(
        {
            -and => [
                'me.post_time' => { '>' => $after },
                'me.id'        => {
                    -in => $message_streams->get_column('message')->as_query,
                },
                'me.submitter' => { '!=' => $user->id },
            ]
        },
        {
            prefetch => ['submitter'],
            rows     => $lim,
            order_by => {
                "-desc" => ['me.post_time']
            },
        }
    )->all;

    if (scalar @you_moderate) {
        return map { $c->app->msg->prepare($_, $user) } $user->authorized_messages_filter(@you_moderate)->all;
    }
}

sub __notifications {
    my ($c, $opts) = @_;

    my $after = $opts->{after} || time;
    my $lim   = $opts->{limit} || 100;
    my $user  = $opts->{user};

    my @subscribed_streams = ($user->notification_inbox->id);

    my $message_streams = $c->rorm->resultset('Stream::MessageStream')->search(
        {
            'me.stream' => {
                -in => \@subscribed_streams,
            },
        }
    );

    # list of message ids (uuid)
    my @messages = map { $_->unique_id } $c->rorm->resultset('Stream::Message')->search(
        {
            -and => [
                'me.post_time' => { '>' => $after },
                'me.id'        => {
                    -in => $message_streams->get_column('message')->as_query,
                },
                'me.submitter' => { '!=' => $user->id },
            ]
        },
        {
            prefetch => ['submitter'],
            rows     => $lim,
            order_by => {
                "-desc" => ['me.post_time']
            }
        }
    )->all;

    # return only unread notifications
    if (scalar @messages) {
        return grep { !$_->{read} }
          map { $c->msg->prepare($_, $user) } $user->authorized_messages_filter(@messages)->all;
    }
}

sub __subscribed_to {
    my ($c, $opts) = @_;

    my $after = $opts->{after} || time;
    my $lim   = $opts->{limit} || 100;
    my $user  = $opts->{user};

    my @subscribed_streams;
    my @streams = grep { !$_->notification_inbox_user } map { $_->stream } $user->subscriptions;
    foreach my $stream (@streams) {
        push(@subscribed_streams, $stream->id);
    }

    my $message_streams = $c->rorm->resultset('Stream::MessageStream')->search(
        {
            'me.stream' => {
                -in => \@subscribed_streams,
            },
        }
    );

    # list of message ids (uuid)
    my @messages = map { $_->unique_id } $c->rorm->resultset('Stream::Message')->search(
        {
            -and => [
                'me.post_time' => { '>' => $after },
                'me.id'        => {
                    -in => $message_streams->get_column('message')->as_query,
                },
                'me.submitter' => { '!=' => $user->id },
            ]
        },
        {
            prefetch => ['submitter'],
            rows     => $lim,
            order_by => {
                "-desc" => ['me.post_time']
            }
        }
    )->all;

    if (scalar @messages) {
        return map { $c->msg->prepare($_, $user) } $user->authorized_messages_filter(@messages)->all;
    }
}

sub __replies {
    my ($c, $opts) = @_;

    my $after = $opts->{after} || time;
    my $lim   = $opts->{limit} || 100;
    my $user  = $opts->{user};

    my $message_streams = $c->app->rorm->resultset('Stream::MessageStream')->search(
        {
            'me.stream' => [ $user->personal_inbox->id ],
        }
    );

    my $messages = $c->app->rorm->resultset('Stream::Message');

    # list of message ids
    my @replies = map { $_->unique_id } $messages->search(
        {
            -and => [
                'me.post_time' => { '>' => $after },
                'me.id'        => {
                    -in => $message_streams->get_column('message')->as_query,
                },
                'me.submitter' => { '!=' => $user->id },
                'me.thread_id' => \'!= me.unique_id',
                -exists        => $messages->search(
                    {
                        -and => [
                            'parent.submitter' => $user->id,
                            'parent.unique_id' => { -ident => 'me.thread_id' },
                        ]
                    },
                    { alias => 'parent' }
                )->get_column('unique_id')->as_query
            ]
        },
        {
            prefetch => ['submitter'],
            rows     => $lim,
            order_by => {
                "-desc" => ['me.post_time']
            },
        }
    )->all;

    if (scalar @replies) {
        return map { $c->app->msg->prepare($_, $user) } $user->authorized_messages_filter(@replies)->all;
    }
}

1;
