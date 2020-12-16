#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::Generic;

=head1 NAME

    MeritCommons::ContentDriver::Generic - A ContentDriver for generic text messages

=head1 DESCRIPTION

    A ContentDriver for generic text messages

=head1 FUNCTIONS

=cut

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

has priorities => sub {
    {
        generic       => LAST,
        'aom-generic' => LAST,
    };
};

has handles => sub {
    {
        inbound      => ['all'],
        outbound     => ['all'],
        notification => ['generic'],
    };
};

=cut

=head2 C<inbound>

  inbound($controller, $content, $actor);

No real work to be done here, as it's just plain text, so this just returns the C<$content> unchanged.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This is just the usual standard outbound with body truncation.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;

    # set the basic attributes...
    $content = $controller->add_outbound_attributes($content, $actor);

    # this isn't done until here in case you needed the object of the submitter for something
    $content->{submitter} = $content->submitter->unique_id;

    return $content;
}

=head2 C<notification>

  notification($controller, $content, $actor, $notifier);

Sets notification text appropriate for generic messages.

=cut

sub notification {
    my ($self, $controller, $content, $actor, $notifier) = @_;

    if ($content->regarding->render_as eq "generic") {

        # if this is a thread...
        if ($notifier->thread) {
            if ($notifier->is_originator($content->recipient)) {

                # NOTIFICATION WHERE RECIPIENT IS THE ORIGINATOR OF THE THREAD (REGARDING THREAD, ABOUT MESSAGE)
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " replied to your message '" . $controller->truncate_htmlstrip($content->thread->body, 32, 1) .
                  "' with '" . $controller->truncate_htmlstrip($content->about->body, 32, 1) . "'";

            } else {

                # NOTIFICATION WHERE RECIPIENT IS A PARTICIPANT IN THE THREAD (REGARDING THREAD, ABOUT MESSAGE)
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " also commented on " . $notifier->user_as_href($content->thread->submitter) .
                  "'s message '" . $controller->truncate_htmlstrip($content->thread->body, 32, 1) .
                  "' saying '" . $controller->truncate_htmlstrip($content->about->body, 32, 1) . "'";
            }
        } else {
            if ($content->subtype eq "comment") {

                # NOTIFICATION WHERE RECIPIENT IS MENTIONED IN THE TRIGGERING MESSAGE
                $content->{body} =
                  $notifier->user_as_href($content->actor) . " mentioned you in a message '" .
                  $controller->truncate_htmlstrip($content->regarding->body, 80, 1) . "'";
            } elsif ($content->subtype eq "like" || $content->subtype eq "dislike") {
                my $whose_message =
                  $content->recipient->unique_id eq $content->about->submitter->unique_id
                  ? "your"
                  : $notifier->user_as_href($content->about->submitter) . "'s";
                if (scalar($content->about->like_participants) xor scalar($content->about->dislike_participants)) {

                    # NOTIFICATION IS REGARDING A LIKE-DISLIKE ACTION ON A MESSAGE WHICH HAS NO OPPOSITE ACTIONS
                    $content->{body} =
                      $notifier->activity_participant_summary($content, $content->actor) .
                      " " . $content->subtype . "d $whose_message message '" .
                      $controller->string->truncate_htmlstrip($content->about->body, 32, 1) . "'";
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

                    $content->{body} .=
                      "$whose_message message '" . $controller->truncate_htmlstrip($content->about->body, 32, 1) . "'";

                    # toggle it back.
                    $content->{subtype} = $content->{subtype} eq "like" ? "dislike" : "like";
                }
            }
        }
    } elsif ($content->regarding->render_as eq "aom-generic") {
        $content->{body} = $notifier->user_as_href($content->actor) . " sent you an encrypted message.";
    }

    return $content;
}

1;
