#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::Emote;

=head1 NAME

    MeritCommons::ContentDriver::Emote - A ContentDriver for doing IRC-like /me actions

=head1 DESCRIPTION

    A ContentDriver for doing IRC-like /me actions.

=head1 FUNCTIONS

=cut

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

has priorities => sub {
    {
        generic => EARLIER,
        emote   => LAST,
    };
};

has handles => sub {
    {
        inbound      => [qw/generic emote/],
        outbound     => ['emote'],
        notification => ['emote'],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

If the message starts with "/me", make sure the render_as attribute 
is also "emote". If it already is, remove the /me from the text so
the action reads as expected in the body content.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    my $body = $content->body;

    if ($body =~ /^\/me / && $content->{render_as} ne 'emote') {
        $content->{render_as} = 'emote';
        return $controller->cd_inbound($content, $actor);
    } elsif ($content->{render_as} eq 'emote') {
        if ($body =~ /^\/me (.+)$/) {
            $body = $1;
            $content->body($body);
            return $content;
        }
    }

    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This is just a usual outbound with truncation if the body is more than 500 chars

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;

    if ($content->{render_as} eq "emote") {

        # set the basic attributes...
        $content = $controller->add_outbound_attributes($content, $actor);

        # this isn't done until here in case you needed the object of the submitter for something
        $content->{submitter} = $content->submitter->unique_id;
    }

    return $content;
}

=head2 C<notification>

  notification($controller, $content, $actor, $notifier);

Sets notification text customized to be specific to emotes.

=cut

sub notification {
    my ($self, $controller, $content, $actor, $notifier) = @_;

    # if this is a thread...
    if ($notifier->thread) {
        if ($notifier->is_originator($content->recipient)) {

            # NOTIFICATION WHERE RECIPIENT IS THE ORIGINATOR OF THE THREAD
            $content->{body} =
              $notifier->activity_participant_summary($content, $content->actor) .
              " replied to your emote '" . $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
              "' with '" . $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

        } else {

            # NOTIFICATION WHERE RECIPIENT IS A PARTICIPANT IN THE THREAD
            $content->{body} =
              $notifier->activity_participant_summary($content, $content->actor) .
              " also commented on " . $notifier->user_as_href($content->thread->submitter) .
              "'s emote '" . $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
              "' saying '" . $controller->truncate_htmlstrip($content->about->original_body,  32, 1) . "'";
        }
    } else {
        if ($content->subtype eq "comment") {

            # NOTIFICATION WHERE RECIPIENT IS MENTIONED IN THE TRIGGERING MESSAGE
            $content->{body} =
              $notifier->user_as_href($content->actor) . " mentioned you in a emote '" .
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
                  " " . $content->subtype . "d $whose_message emote '" .
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
                  " " . $content->subtype . "d $action_icon $whose_message emote '" .
                  $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

                # toggle it back.
                $content->{subtype} = $notifier->{subtype} eq "like" ? "dislike" : "like";
            }
        }
    }

    return $content;
}

1;
