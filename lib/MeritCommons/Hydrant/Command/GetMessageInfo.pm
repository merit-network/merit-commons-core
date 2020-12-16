#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::GetMessageInfo;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'message';
has user_activity_flag  => 1;

sub command {
    my ($self, $message) = @_;

    my $controller = $self->controller;
    my $user       = $controller->active_user;

    my ($for, $against) = ([], []);
    foreach my $vote ($message->votes) {
        my $profile_picture = $controller->profile_picture_url_for($vote->voter, 'tiny');
        if ($vote->vote > 0) {

            # this is a like
            push(
                @$for,
                {
                    vote => $vote->vote,
                    who  => {
                        url             => "/u/" . $vote->voter->userid . "/",
                        userid          => $vote->voter->userid,
                        common_name     => $vote->voter->common_name,
                        profile_picture => $profile_picture,
                    },
                    when => $vote->create_time,
                }
            );
        } else {

            # this is a dislike
            push(
                @$against,
                {
                    vote => $vote->vote,
                    who  => {
                        url             => "/u/" . $vote->voter->userid . "/",
                        userid          => $vote->voter->userid,
                        common_name     => $vote->voter->common_name,
                        profile_picture => $profile_picture,
                    },
                    when => $vote->create_time,
                }
            );
        }
    }

    # pack the stream info up here..
    my $stream_info = {};
    foreach my $stream ($message->streams) {
        if (my $user = $stream->personal_inbox_user || $stream->personal_outbox_user) {
            $stream_info->{ '@' . $user->userid } = {
                href        => "/u/@{[$user->userid]}/",
                common_name => '<strong>@</strong>' . $user->userid,
            };
        } else {
            $stream_info->{ $stream->url_name } = {
                href        => "/s/@{[$stream->url_name]}/",
                common_name => $stream->common_name,
            };
        }
    }

    my $stream_count = scalar(keys(%$stream_info));

    # populate the stash!
    $controller->stash(
        {
            message      => $message,
            user         => $user,
            stream_info  => $stream_info,
            stream_count => $stream_count,
            stream_word  => $stream_count == 1 ? 'stream' : 'streams',
            for     => [ sort { $a->{who}->{common_name} cmp $b->{who}->{common_name} } @$for ],
            against => [ sort { $a->{who}->{common_name} cmp $b->{who}->{common_name} } @$against ],
        }
    );

    my $panel = $controller->render_to_string(template => 'message/message_info_panel');

    if ($ENV{MERITCOMMONS_DEBUG}) {
        warn "[hydrant] shoving across message info panel payload " . length($panel) . " bytes in size.\n";
    }

    $self->send($panel, 'get_message_info:response:' . $message->unique_id);
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input({ message_id => $arg })->required('message_id')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
