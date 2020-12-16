#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::OptionsDropdown;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'message';
has user_activity_flag  => 1;

sub command {
    my ($self, $message) = @_;

    my $controller = $self->controller;
    my $user       = $controller->active_user;

    my @m_streams = ();
    foreach my $stream ($message->streams) {
        if ($user->can_moderate($stream) || $user->id == $message->submitter->id) {
            push(@m_streams, $stream);
        }
    }

    # populate the stash!
    $controller->stash(
        {
            message   => $message,
            user      => $user,
            m_streams => \@m_streams,
        }
    );

    my $dropdown = $controller->render_to_string(template => 'message/message_options_dropdown');

    if ($ENV{MERITCOMMONS_DEBUG}) {
        warn "[hydrant] shoving across options dropdown payload " . length($dropdown) . " bytes in size.\n";
    }

    $self->send($dropdown, 'options_dropdown:response');
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
