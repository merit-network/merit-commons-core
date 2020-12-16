#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::GetRecipientCount;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/encode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;

    my $c = $self->controller;

    if (my $user = $c->active_user) {
        my @streams;

        # see if any of these "streams" are actually users..
        foreach my $stream (@{ $arg->{streams} }) {

            # if it is a user, add their personal inbox
            if (my $user = $c->m->resultset('User')->find({ unique_id => $stream })) {
                push(@streams, $user->personal_inbox->unique_id);
            } else {

                # assume it's a stream unique id
                push(@streams, $stream);
            }
        }

        foreach my $mention (@{ $arg->{mentions} }) {
            my $mentioned;
            if ($mention =~ /=([\w\-\.]+)$/) {
                my $cap = $1;
                $mentioned = $c->user($cap);
            } elsif ($mention =~ /^\@([\w\-\.]+)/) {
                my $cap = $1;
                $mentioned = $c->user($cap);
            }

            # if this matched a real user, add their personal inbox stream
            if ($mentioned) {
                if (my $stream = $mentioned->personal_inbox) {
                    push(@streams, $stream->unique_id);
                }
            }
        }

        my $count = $self->controller->subscriber_count(@streams);
        $count = 0 unless $count;

        my $balance = $user->meritcommonscoin_balance;
        $balance = 0 unless $balance;

        $self->send(
            encode_json(
                {
                    recipient_count => $count,
                    balance         => $user->meritcommonscoin_balance,
                }
            ),
            'getrecipientcount:reply'
        );
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('streams')->like($self->F_UUID);
        $v->optional('mentions')->like($self->F_MENTION);
        return $v;
    }

    return undef;
}

1;
