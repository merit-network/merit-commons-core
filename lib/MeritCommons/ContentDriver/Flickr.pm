package MeritCommons::ContentDriver::Flickr;

=head1 NAME

    MeritCommons::ContentDriver::Flickr - A ContentDriver for embedding Flickr images.

=head1 SYNOPSIS

=head2 METHODS

=over 4

=item * should_handle

=item * priority

=item * inbound

=item * outbound

=back 

=head1 DESCRIPTION

    A ContentDriver for embedding Flickr images in messages by way of an iframe.

=head1 FUNCTIONS

=cut

use Mojo::Util qw(html_unescape);

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

has priorities => sub {
    {
        generic => FIRST,
        flickr  => FIRST,
    };
};

has handles => sub {
    {
        inbound      => [qw/generic flickr/],
        outbound     => [qw/flickr/],
        notification => [qw/flickr/],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

Finds URLs that look to be from Flickr photos, and registers a replacement for
them that embeds the photo iframe in the message directly


=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    my $body   = $content->body;
    my $config = $controller->app->config;

    my $body_orig = $body;
    my @replacements = ref($content->{replacements}) eq "ARRAY" ? @{ $content->{replacements} } : ();

    while ($body =~ /https?:(\/\/www\.flickr\.com\/photos\/[A-Za-z0-9\@_]+\/(\d+)\/?)/gmi) {
        unless ($content->{render_as} eq "flickr") {
            $content->{render_as} = "flickr";
            return $controller->cd_inbound($content, $actor);
        }

        my $fullmatch = $&;

        my $embed_string =
          qq|<iframe src="https:${1}/player/" frameborder="0" style="width: 100%; height: 375px" allowfullscreen webkitallowfullscreen mozallowfullscreen oallowfullscreen msallowfullscreen></iframe>|;
        $embed_string = html_unescape($embed_string);
        my $placeholder = 'REPLACEMENT' . $content->{'replacement_count'}++;
        push @replacements, { 'from' => $placeholder, 'to' => $embed_string };
        $body_orig =~ s/\Q$fullmatch/$placeholder/;
    }

    $content->{replacements} = \@replacements;
    $content->body($body_orig);
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This is just the usual standard outbound.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;

    if ($content->{render_as} eq "flickr") {

        # set the basic attributes...
        $content = $controller->add_outbound_attributes($content, $actor);

        # this isn't done until here in case you needed the object of the submitter for something
        $content->{submitter} = $content->submitter->unique_id;
    }

    return $content;
}

=head2 C<notification>

  notification($controller, $content, $actor, $notifier);

Sets notification text customized to be specific to Flickr images.

=cut

sub notification {
    my ($self, $controller, $content, $actor, $notifier) = @_;

    if ($content->about->render_as eq "flickr") {

        # if this is a thread...
        if ($notifier->thread) {
            if ($notifier->is_originator($content->recipient)) {

                # NOTIFICATION WHERE RECIPIENT IS THE ORIGINATOR OF THE THREAD
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " replied to your Flickr image '" .
                  $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
                  "' with '" . $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

            } else {

                # NOTIFICATION WHERE RECIPIENT IS A PARTICIPANT IN THE THREAD
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " also commented on " . $notifier->user_as_href($content->thread->submitter) .
                  "'s Flickr image '" . $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
                  "' saying '" . $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";
            }
        } else {
            if ($content->subtype eq "comment") {

                # NOTIFICATION WHERE RECIPIENT IS MENTIONED IN THE TRIGGERING MESSAGE
                $content->{body} =
                  $notifier->user_as_href($content->actor) . " mentioned you in a Flickr image '" .
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
                      " " . $content->subtype . "d $whose_message Flickr image '" .
                      $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";
                } else {

                    # NOTIFICATION IS ABOUT A LIKE-DISLIKE ACTION ON A MESSAGE WHICH DOES HAVE OPPOSITE ACTIONS
                    my $action_icon =
                      $content->subtype eq "like"
                      ? "<i class='icon-thumbs-up'></i>"
                      : "<i class='icon-thumbs-down'></i>";
                    $content->{body} =
                      $notifier->activity_participant_summary($content, $content->actor) .
                      " " . $content->subtype . "d $action_icon and ";

                    # toggle these and get the opposite.
                    $content->{subtype} = $content->{subtype} eq "like" ? "dislike" : "like";
                    $action_icon =
                      $content->subtype eq "like"
                      ? "<i class='icon-thumbs-up'></i>"
                      : "<i class='icon-thumbs-down'></i>";

                    $content->{body} .=
                      $notifier->activity_participant_summary($content) .
                      " " . $content->subtype . "d $action_icon $whose_message Flickr image '" .
                      $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

                    # toggle it back.
                    $content->{subtype} = $content->{subtype} eq "like" ? "dislike" : "like";
                }
            }
        }
    }

    return $content;
}

1;
