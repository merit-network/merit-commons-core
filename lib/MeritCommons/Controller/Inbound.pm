#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Inbound;

# declare our @ISA
our @ISA;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use MeritCommons::Content;

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    my $actor = $self->active_user;
    my (
        @attempted_streams, $in_reply_to, $public,             $body, $original_body,
        $render_as,         $serialized,  $serialized_payload, $thread_id
    );

    if (my $json_data = $self->req->json) {
        my @attempted_streams;

        # see if any of these "streams" are actually users..
        foreach my $stream (@{ $json_data->{stream} }) {

            # if it is a user, add their personal inbox
            if (my $user = $self->m->resultset('User')->find({ unique_id => $stream })) {
                push(@attempted_streams, $user->personal_inbox);
            } else {

                # assume it's a stream unique id
                push(@attempted_streams, $self->m->resultset('Stream')->find({ unique_id => $stream }));
            }
        }

        $public      = $json_data->{public};
        $body        = $json_data->{body};
        $render_as   = $json_data->{render_as} || "generic";
        $in_reply_to = $json_data->{in_reply_to};
        $serialized  = 0;
    } else {
        my @attempted_streams;

        # see if any of these "streams" are actually users..
        foreach my $stream (@{ $self->every_param('stream') }) {

            # if it is a user, add their personal inbox
            if (my $user = $self->m->resultset('User')->find({ unique_id => $stream })) {
                push(@attempted_streams, $user->personal_inbox);
            } else {

                # assume it's a stream unique id
                push(@attempted_streams, $self->m->resultset('Stream')->find({ unique_id => $stream }));
            }
        }

        $public             = $self->param('public');
        $body               = $self->param('body');
        $render_as          = $self->param('render_as') || "generic";
        $serialized         = $self->param('serialized') ? $self->param('serialized') : 0;
        $serialized_payload = $serialized ? $self->param('body') : undef;
        $in_reply_to        = $self->param('in_reply_to');
    }

    my $content = MeritCommons::Content->new(
        {
            render_as          => $render_as,
            serialized         => $serialized,
            body               => $body,
            original_body      => $body,
            attempted_streams  => \@attempted_streams,
            streams            => [],
            public             => $public,
            in_reply_to        => $in_reply_to,
            serialized_payload => $serialized_payload,
            thread_id          => $thread_id,
        }
    );

    if ($in_reply_to) {
        $self->app->cache->delete($in_reply_to);
    }

    # add to tha database
    $self->render(json => $self->add_inbound_message($actor, $content));
}

sub attach_file {
    my ($self) = @_;

    my $uploader = $self->active_user;

    my $attachment = $self->app->m->resultset('Stream::Message::Attachment')->create(
        {
            uploader => $uploader->id,
        }
    );

    if (my $msg = $self->app->message($self->param('message_id'))) {
        $attachment->message($msg->id);
    }

    $attachment->file($self->param('attachment_file'));
    $attachment->update();

    $self->render(
        json => {
            attachment_id => $attachment->id,
        }
    );
}

1;
