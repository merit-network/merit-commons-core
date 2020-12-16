#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::YouTube;

use Mojo::Util qw(html_unescape);

=head1 NAME

    MeritCommons::ContentDriver::YouTube - A ContentDriver for embedding YouTube videos.

=head1 DESCRIPTION

    A ContentDriver for embedding YouTube videos.

=head1 FUNCTIONS

=cut

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

# define the stage of execution this content driver is invoked in for various
# message types
has priorities => sub {
    {
        generic => EARLIER,
        youtube => EARLY,
    };
};

# define the action => [typelist] that this content driver handles
has handles => sub {
    {
        inbound      => [qw/generic youtube/],
        outbound     => ['youtube'],
        notification => ['youtube'],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

Finds URLs that look to be from YouTube videos, and 
embeds the video player in the message directly.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    my $body   = $content->body;
    my $config = $controller->app->config;

    my $body_orig = $body;
    my @replacements = ref($content->{replacements}) eq "ARRAY" ? @{ $content->{replacements} } : ();
    my @mkdwn;
    my $mkdwncount = 0;

    # Find markdown, and replace them so the
    # link stuff doesn't interfere with them
    while ($body =~ /!?(\[.*?\]\([^\)]+\)|\[[^\]]+\]\: *\<*[^\s\>]+\>*|\[[^\]]+\]\[[^\]]+\])/g) {
        my $found_mkdwn = $&;
        push(@mkdwn, $found_mkdwn);
        $body_orig =~ s|\Q$found_mkdwn\E|\{\{REPLACEMARKDOWN$mkdwncount\}\}|;
        $body =~ s|\Q$found_mkdwn\E|\{\{REPLACEMARKDOWN$mkdwncount\}\}|;
        $mkdwncount++;
    }

    while ($body =~ /(?:https?)?:?\/?\/?(?:www\.)?youtu(?:\.be|be\.com)\/(?:v\/|watch\?v=|embed\/|)?([^\&\?\s]+)/gmi) {
        unless ($content->{render_as} eq "youtube") {
            $content->{render_as} = "youtube";
            return $controller->cd_inbound($content, $actor);
        }

        my $fullmatch = $&;
        my $vid       = $1;

        my $embed_string =
          qq|<iframe class="ytplayer" type="text/html" width="560" height="315" src="https://www.youtube.com/embed/$vid" frameborder="0"></iframe>|;

        $embed_string = html_unescape($embed_string);
        my $placeholder = 'REPLACEMENT' . $content->{'replacement_count'}++;
        push @replacements, { 'from' => $placeholder, 'to' => $embed_string };
        $body_orig =~ s/\Q$fullmatch/$placeholder/;
    }

    # put the markdown back where we found it.
    $mkdwncount = 0;
    foreach my $mkdwn (@mkdwn) {
        $body_orig =~ s/\{\{REPLACEMARKDOWN$mkdwncount\}\}/$mkdwn/g;
        $mkdwncount++;
    }

    $content->{replacements} = \@replacements;
    $content->body($body_orig);

    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This is a usual outbound with truncation for long messages.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;

    # generics that were ignored are passed to outbound, so we need to ensure that we don't
    # interfere with those messages
    if ($content->{render_as} eq "youtube") {

        # set the basic attributes...
        $content = $controller->add_outbound_attributes($content, $actor);

        # this isn't done until here in case you needed the object of the submitter for something
        $content->{submitter} = $content->submitter->unique_id;
    }

    return $content;
}

=head2 C<notification>

  notification($controller, $content, $actor, $notifier);

Sets notification text customized to be specific to YouTube videos.

=cut

sub notification {
    my ($self, $controller, $content, $actor, $notifier) = @_;

    if ($content->regarding->render_as eq "youtube") {

        # if this is a thread...
        if ($notifier->thread) {
            if ($notifier->is_originator($content->recipient)) {

                # NOTIFICATION WHERE RECIPIENT IS THE ORIGINATOR OF THE THREAD (REGARDING THREAD, ABOUT MESSAGE)
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " replied to your YouTube video with '" .
                  $controller->truncate_htmlstrip($content->about->body, 32, 1) . "'";

            } else {

                # NOTIFICATION WHERE RECIPIENT IS A PARTICIPANT IN THE THREAD (REGARDING THREAD, ABOUT MESSAGE)
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " also commented on " . $notifier->user_as_href($content->thread->submitter) .
                  "'s YouTube video saying '" . $controller->truncate_htmlstrip($content->about->body, 32, 1) . "'";
            }
        } else {
            if ($content->subtype eq "comment") {

                # NOTIFICATION WHERE RECIPIENT IS MENTIONED IN THE TRIGGERING MESSAGE
                $content->{body} =
                  $notifier->user_as_href($content->actor) . " mentioned you in a post on a YouTube video thread";
            } elsif ($content->subtype eq "like" || $content->subtype eq "dislike") {
                my $whose_message =
                  $content->recipient->unique_id eq $content->about->submitter->unique_id
                  ? "your"
                  : $notifier->user_as_href($content->about->submitter) . "'s";
                if (scalar($content->about->like_participants) xor scalar($content->about->dislike_participants)) {

                    # NOTIFICATION IS REGARDING A LIKE-DISLIKE ACTION ON A MESSAGE WHICH HAS NO OPPOSITE ACTIONS
                    $content->{body} =
                      $notifier->activity_participant_summary($content, $content->actor) .
                      " " . $content->subtype . "d $whose_message YouTube video";
                } else {

                    # NOTIFICATION IS REGARDING A LIKE-DISLIKE ACTION ON A MESSAGE WHICH DOES HAVE OPPOSITE ACTIONS
                    my $action_icon =
                      $content->subtype eq "like"
                      ? "<i class='fa fa-thumbs-up'></i>"
                      : "<i class='fa fa-thumbs-down'></i>";

                    my $summary = $notifier->activity_participant_summary($content, $content->actor);

                    if ($summary) {
                        $content->{body} = $summary . " " . $content->subtype . "d $action_icon ";
                    }

                    # toggle these and get the opposite.
                    $content->{subtype} = $content->{subtype} eq "like" ? "dislike" : "like";
                    $action_icon =
                      $content->subtype eq "like"
                      ? "<i class='fa fa-thumbs-up'></i>"
                      : "<i class='fa fa-thumbs-down'></i>";

                    $summary = $notifier->activity_participant_summary($content);

                    if ($summary) {
                        $content->{body} .= "and " . $summary . " " . $content->subtype . "d $action_icon ";
                    }

                    $content->{body} .= "$whose_message YouTube video";

                    # toggle it back.
                    $content->{subtype} = $content->{subtype} eq "like" ? "dislike" : "like";
                }
            }
        }
    }

    return $content;
}

1;
