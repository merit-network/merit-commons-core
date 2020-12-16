#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::Twitter;

use Mojo::JSON qw/decode_json from_json/;

=head1 NAME

    MeritCommons::ContentDriver::Twitter - A ContentDriver for handling twitter messages

=head1 DESCRIPTION

    A ContentDriver for handling twitter messages that are fed into MeritCommons.

=head1 FUNCTIONS

=cut

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

# define the stage of execution this content driver is invoked in for various
# message types
has priorities => sub {
    { twitter => FIRST, };
};

# define the action => [typelist] that this content driver handles
has handles => sub {
    {
        inbound      => ['all'],
        outbound     => ['twitter'],
        notification => ['twitter'],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

Handles hashtag and @ links for the messages, making them into links to the appropriate urls on Twitter.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;

    my $body;
    if ($content->serialized) {
        my $hr = decode_json($content->serialized_payload);
        $body = $hr->{text};
    } else {
        $body = $content->body;
    }

    my @replacements = ref($content->{replacements}) eq "ARRAY" ? @{ $content->{replacements} } : ();
    $content->{replacement_count} = scalar(@replacements);

    while ($body =~ /(^|\W)#([A-Za-z0-9-_]{2,})/go) {
        my $placeholder = 'TWITTERHASHREPLACEMENT' . $content->{'replacement_count'}++;
        push(
            @replacements,
            {
                from => $placeholder,
                to   => qq|\#<a href="https://twitter.com/search?q=$2">$2</a>|,
            }
        );
        $body =~ s|\#$2|$placeholder|g;
    }

    while ($body =~ /(^|\W)\@([A-Za-z0-9-_]+)/go) {
        my $placeholder = 'TWITTERATREPLACEMENT' . $content->{'replacement_count'}++;
        push(
            @replacements,
            {
                from => $placeholder,
                to   => qq|\@<a href="https://twitter.com/$2">$2</a>|,
            }
        );
        $body =~ s|\@$2|$placeholder|g;
    }

    # update the twitter content!
    $content->body($body);

    # stash the replacements...
    $content->{replacements} = \@replacements;

    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

Handles the data for the message accounting for the fact it's not
really an MeritCommons message originally, but a Tweet, so things like
the submitter profile URL are for the Twitter user rather than an 
MeritCommons user.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;
    my $tweet     = decode_json($content->serialized_payload);
    my $post_time = $content->post_time;
    $content->{create_time}           = $post_time;
    $content->{modify_time}           = $post_time;
    $content->{day_hhmmss}            = $controller->app->day_hhmmss($post_time);
    $content->{post_time_pretty}      = $controller->app->time_mmddyy_hhmmss($post_time);
    $content->{post_day_pretty}       = $controller->app->time_week_month_day($post_time);
    $content->{abbr_ago}              = $controller->app->abbr_ago($post_time);
    $content->{seconds_since_post}    = (time - $post_time);
    $content->{submitter}             = "twitter.user." . $tweet->{user}->{id};
    $content->{submitter_userid}      = $tweet->{user}->{screen_name};
    $content->{submitter_profile_url} = "https://twitter.com/$tweet->{user}->{screen_name}";
    $content->{submitter_common_name} = $tweet->{user}->{name};

    if ($tweet->{in_reply_to_status_id_str}) {
        $content->{in_reply_to} = "twitter.status." . $tweet->{in_reply_to_status_id_str};
    }

    if (my $profimg_url = $tweet->{user}->{profile_image_url}) {
        $profimg_url =~ s/normal/bigger/go;
        $content->{submitter_profile_thumb_url} = $profimg_url;
    } else {
        $content->{submitter_profile_thumb_url} = $controller->asset_url("img/no_profile_small.png");
    }
    return $content;
}

=head2 C<notification>

  notification($controller, $content, $actor, $notifier);

Sets notification text customized to be specific to Tweets.

=cut

sub notification {
    my ($self, $controller, $content, $actor, $notifier) = @_;

    # if this is a thread...
    if ($notifier->thread) {
        if ($notifier->is_originator($content->recipient)) {

            # NOTIFICATION WHERE RECIPIENT IS THE ORIGINATOR OF THE THREAD
            $content->{body} =
              $notifier->activity_participant_summary($content, $content->actor) .
              " replied to your tweet '" . $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
              "' with '" . $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

        } else {

            # NOTIFICATION WHERE RECIPIENT IS A PARTICIPANT IN THE THREAD
            $content->{body} =
              $notifier->activity_participant_summary($content, $content->actor) .
              " also commented on " . $notifier->user_as_href($content->thread->submitter) .
              "'s tweet '" . $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
              "' saying '" . $controller->truncate_htmlstrip($content->about->original_body,  32, 1) . "'";
        }
    } else {
        if ($content->subtype eq "comment") {

            # NOTIFICATION WHERE RECIPIENT IS MENTIONED IN THE TRIGGERING MESSAGE
            $content->{body} =
              $notifier->user_as_href($content->actor) . " mentioned you in a tweet '" .
              $controller->truncate_htmlstrip($content->about->original_body, 80, 1) . "'";
        } elsif ($content->subtype eq "like" || $content->subtype eq "dislike") {
            my $whose_message =
              $content->recipient->unique_id eq $content->about->submitter->unique_id
              ? "your"
              : $notifier->user_as_href($content->about->submitter) . "'s";
            if (scalar($content->about->like_participants) xor scalar($content->about->dislike_participants)) {

                # NOTIFICATION IS ABOUT A LIKE-DISLIKE ACTION ON A MESSAGE WHICH HAS NO OPPOSITE ACTIONS
                $content->{body} =
                  $notifier->activity_participant_summary($content) .
                  " " . $content->subtype . "d $whose_message tweet '" .
                  $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";
            } else {

                # NOTIFICATION IS ABOUT A LIKE-DISLIKE ACTION ON A MESSAGE WHICH DOES HAVE OPPOSITE ACTIONS
                my $action_icon =
                  $content->subtype eq "like" ? "<i class='icon-thumbs-up'></i>" : "<i class='icon-thumbs-down'></i>";
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " " . $content->subtype . "d $action_icon and ";

                # toggle these and get the opposite.
                $content->{subtype} = $notifier->{subtype} eq "like" ? "dislike" : "like";
                $action_icon =
                  $content->subtype eq "like" ? "<i class='icon-thumbs-up'></i>" : "<i class='icon-thumbs-down'></i>";

                $content->{body} .=
                  $notifier->activity_participant_summary($content) .
                  " " . $content->subtype . "d $action_icon $whose_message tweet '" .
                  $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

                # toggle it back.
                $content->{subtype} = $notifier->{subtype} eq "like" ? "dislike" : "like";
            }
        }
    }

    return $content;
}

1;
