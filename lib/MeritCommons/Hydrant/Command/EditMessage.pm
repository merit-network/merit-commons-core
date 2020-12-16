#   MeritCommons Portal
#   Copyright 2016 Wayne State University
#   All Rights Reserved

package MeritCommons::Hydrant::Command::EditMessage;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::Util qw/decode encode/;
use MeritCommons::Content;
use Mojo::JSON qw/to_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    my $msg = $self->controller->message($data->{message_id});

    if ($msg) {

        # sometimes we need one more decoding pass on the body (&nbsp;, etc).
        my $body = decode('UTF-8', $data->{body}) // $data->{body};

        # our message
        my $content = MeritCommons::Content->new(
            {
                message_id    => $data->{message_id},
                render_as     => exists($data->{render_as}) ? $data->{render_as} : "generic",
                serialized    => exists($data->{serialized}) ? $data->{serialized} : 0,
                subject       => exists($data->{subject}) ? $data->{subject} : undef,
                body          => $body,
                original_body => $body,
                attempted_streams => [ map { $self->controller->stream($_) } @{ $data->{stream} } ],
                streams           => [],
                read_only   => exists($data->{read_only})   ? $data->{read_only}   : 0,
                public      => exists($data->{public})      ? $data->{public}      : 0,
                in_reply_to => exists($data->{in_reply_to}) ? $data->{in_reply_to} : undef,
                submitter_mask => $data->{message_from},
            }
        );

        # our user
        my $user = $self->controller->active_user;

        # send our message to the controller so it can do work
        my $inbound_log = $self->controller->edit_inbound_message($user, $content);

        # return encoded payload
        $self->send($inbound_log, 'inbound:messageedit');

        # clear message cache and let the publisher know
        $self->controller->cache->delete($data->{message_id});
        $self->controller->pub_write($data->{message_id} . " " . $data->{message_id});
    }
}

sub validate {
    my ($self, $arg) = @_;

    # assuming we'll allow users to edit more than just the body in the future
    # so, we'll validate the whole payload

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('message_id')->like($self->F_UUID);
        $v->required('render_as')->in(qw/generic twitter youtube vimeo flickr emote circuitsio sponsored latex/);
        $v->required('body');
        $v->optional('serialized_payload');
        $v->optional('stream')->like($self->F_UUID);
        $v->optional('serialized')->in(0, 1);
        $v->optional('public')->in(0, 1);
        $v->optional('submitter_mask')->like(qr/^\w+\:[A-F0-9-]{36}$/i);
        $v->optional('in_reply_to')->like($self->F_UUID);
        $v->optional('read_only')->in(0, 1);
        $v->optional('subject');

        return $v;
    }

    return undef;
}

1;
