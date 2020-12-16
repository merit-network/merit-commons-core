#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Inbound;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::Util qw/decode encode/;
use MeritCommons::Content;
use Mojo::JSON qw/to_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $json_data) = @_;

    # sometimes we need one more decoding pass on the body (&nbsp;, etc).
    my $body = decode('UTF-8', $json_data->{body}) // $json_data->{body};

    my @attempted_streams;

    my ($user_count, $stream_count);
    # see if any of these "streams" are actually users..
    foreach my $stream (@{ $json_data->{streams} }, @{ $json_data->{stream} }) {

        # if it is a user, add their personal inbox
        if (my $user = $self->controller->m->resultset('User')->find({ unique_id => $stream })) {
            push(@attempted_streams, $user->personal_inbox);
            $user_count++;
        } else {
            # assume it's a stream unique id
            push(@attempted_streams, $self->controller->m->resultset('Stream')->find({ unique_id => $stream }));
            $stream_count++;
        }
    }

    # get the user up here so we can add their personal_inbox if need be
    my $user = $self->controller->active_user;

    if ($user_count && !$stream_count) {
        # add the personal inbox if it went to users but not to streams
        push(@attempted_streams, $user->personal_inbox);
    }

    my $content = MeritCommons::Content->new(
        {
            render_as  => exists($json_data->{render_as})  ? $json_data->{render_as}  : "generic",
            serialized => exists($json_data->{serialized}) ? $json_data->{serialized} : 0,
            subject    => exists($json_data->{subject})    ? $json_data->{subject}    : undef,
            body       => $body,
            original_body     => $body,
            attempted_streams => \@attempted_streams,
            streams           => [],
            read_only         => exists($json_data->{read_only}) ? $json_data->{read_only} : 0,
            public            => exists($json_data->{public}) ? $json_data->{public} : 0,
            in_reply_to       => exists($json_data->{in_reply_to}) ? $json_data->{in_reply_to} : undef,
            submitter_mask    => $json_data->{message_from},
        }
    );

    if (my $from = $json_data->{message_from}) {
        my ($entity_type, $unique_id) = split(/:/, $from, 2);

        # right now we can only mask with streams we moderate.
        if ($entity_type eq "stream" &&
            $self->controller->active_user->can_moderate($self->controller->stream($unique_id))) {
            $content->{submitter_mask} = $from;
            $content->{masked}         = 1;
        }
    }

    if ($json_data->{serialized_payload}) {

        # we want this UTF-8 encoded (needs to work across Perl versions)
        $content->{serialized_payload} =
          decode('UTF-8', $json_data->{serialized_payload})
          ? $json_data->{serialized_payload}
          : encode('UTF-8', $json_data->{serialized_payload}),
          ;
    }

    # clear the cache for this.
    if (my $in_reply_to = $content->in_reply_to) {
        $self->controller->cache->delete($in_reply_to);
    }

    # refresh this row from the database to get the most up-to-date meritcommonscoin balance
    $user->discard_changes;

    my $inbound_log = $self->controller->add_inbound_message($user, $content);

    # return as encoded payload
    $self->send($inbound_log, 'inbound:messagerecv');
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('render_as')->in(qw/generic twitter youtube vimeo flickr emote circuitsio sponsored latex/);
        $v->required('body');
        $v->optional('serialized_payload');
        $v->optional('stream')->like($self->F_UUID);
        $v->optional('streams')->like($self->F_UUID);
        $v->optional('serialized')->in(0, 1);
        $v->optional('public')->in(0, 1);
        $v->optional('message_from')->like(qr/^\w+\:[A-F0-9-]{36}$/i);
        $v->optional('in_reply_to')->like($self->F_UUID);
        $v->optional('read_only')->in(0, 1);
        $v->optional('subject');
        return $v;
    }

    return undef;
}

1;
