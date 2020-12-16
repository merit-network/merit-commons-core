#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::Notification;

=head1 NAME

    MeritCommons::ContentDriver::CircuitsIo - A ContentDriver for handling MeritCommons notifications

=head1 DESCRIPTION

    A ContentDriver for handling MeritCommons notifications. It's not immediately
    obvious from the user perspective, but notifications are really just a 
    specific type of message in MeritCommons, and this content handler handles
    them.

=head1 FUNCTIONS

=cut

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

# define the stage of execution this content driver is invoked in for various
# message types
has priorities => sub {
    { notification => LAST, };
};

# define the action => [typelist] that this content driver handles
has handles => sub {
    {
        inbound  => ['notification'],
        outbound => ['notification'],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

Notifications don't have a usual content body, so there's nothing to do
on the inbound, since that's normally what goes on here. This just returns
C<$content> unchanged.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This handles the information for the notification that shows up in the
notification list.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;

    # generics that were ignored are passed to outbound, so we need to ensure that we don't
    # interfere with those messages
    $content->{day_hhmmss}                   = $controller->app->day_hhmmss($content->post_time);
    $content->{abbr_ago}                     = $controller->app->wordy_abbr_ago($content->post_time);
    $content->{seconds_since_post}           = (time - $content->post_time);
    $content->{submitter_userid}             = $content->submitter->userid;
    $content->{submitter_profile_url}        = "/u/" . $content->submitter->userid . "/";
    $content->{submitter_common_name}        = $content->submitter->common_name;
    $content->{submitter_gravatar_thumb_url} = $content->submitter->gravatar_thumb_url;
    $content->{submitter_gravatar_tiny_url}  = $content->submitter->gravatar_tiny_url;

    if ($content->{subtype} eq "comment") {
        $content->{notification_icon} = "fa fa-comment";
    } elsif ($content->{subtype} eq "reply") {
        $content->{notification_icon} = "fa fa-share-square";
    } elsif ($content->{subtype} eq "dislike") {
        $content->{notification_icon} = "fa fa-thumbs-down";
    } elsif ($content->{subtype} eq "like") {
        $content->{notification_icon} = "fa fa-thumbs-up";
    }

    if ($content->{message}) {
        if (my $regarding = $content->{message}->get_column('regarding')) {
            my $msg = $controller->message($regarding);
            if (my $about = $content->{message}->get_column('about')) {
                $content->{notification_href} = "/m/@{[$msg->thread_id]}#m$about";
            } else {
                $content->{notification_href} = "/m/@{[$msg->thread_id]}";
            }
        }
    }

    if ($content->{external_url} && !$content->{notification_href}) {
        $content->{notification_href} = $content->{external_url};
    }

    $content->{submitter_profile_thumb_url} = $controller->util->profile_picture_url_for($content->submitter, 'thumbnail');
    $content->{submitter_profile_tiny_url}  = $controller->util->profile_picture_url_for($content->submitter, 'tiny');

    # now that we're done with it, replace the object with its uuid.
    $content->{submitter} = $content->submitter->unique_id;

    # shorten this.
    if (length($content->{body}) >= 500) {
        my $truncated_body = $controller->truncate($content->{body}, 500, 1);
        if (length($truncated_body) >= 500 && (length($content->{body}) > length($truncated_body))) {
            $content->{full_body} = $content->{body};
            $content->{body}      = $truncated_body;
        }
    }

    # strip out html for browser notifications
    my $stripped_body = $content->{body};

    $stripped_body =~ s/\<[\\A-Za-z0-9\/\=\"\'\%\s\_\-\?\!\.\&:;]+\>//g;

    $stripped_body =~ s/^\s+//g;
    $stripped_body =~ s/\s+$//g;

    $content->{stripped_body} = $stripped_body;

    return $content;
}

1;
