#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::StreamDropdown;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'message';
has user_activity_flag  => 1;

sub command {
    my ($self, $message) = @_;

    my $controller = $self->controller;
    my $user       = $controller->active_user;

    my $streams = [];
    foreach my $stream ($message->streams) {
        my $pou = $stream->personal_outbox_user;
        my $piu = $stream->personal_inbox_user;
        push(
            @$streams,
            {
                common_name => $pou ? $pou->common_name : $piu ? "\@@{[$piu->userid]}" : $stream->common_name,
                unique_id => $stream->unique_id,
                url => $pou ? "/u/@{[$pou->userid]}" : $piu ? "/u/@{[$piu->userid]}" : "/s/@{[$stream->url_name]}",
                can_read        => $user->can_read($stream)      ? 1 : 0,
                is_subscriber   => $user->is_subscriber($stream) ? 1 : 0,
                can_unsubscribe => $stream->type eq "role"       ? 0 : 1,
                can_subscribe => $stream->requires_subscriber_authorization ? 0 : $piu ? 0 : 1,
                personal_inbox     => $piu                                        ? 1 : 0,
                is_moderator       => $user->is_moderator($stream)                ? 1 : 0,
                my_personal_outbox => ($user->personal_outbox->id == $stream->id) ? 1 : 0,
            }
        );
    }

    $controller->stash(
        dropdown_streams => [
            sort { $a->{personal_inbox} <=> $b->{personal_inbox} }
            sort { $a->{common_name} cmp $b->{common_name} } @$streams
        ]
    );
    my $dropdown = $controller->render_to_string(template => 'message/stream_summary_dropdown');

    if ($ENV{MERITCOMMONS_DEBUG}) {
        warn "[hydrant] shoving across stream summary dropdown payload " . length($dropdown) . " bytes in size.\n";
    }

    $self->send($dropdown, 'stream_dropdown:response');
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        return $v->input({ message => $arg })->required('message')->like($self->F_UUID);
    }

    return undef;
}

1;
