#    MeritCommons Portal
#    Copyright 2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::SessionHeartbeat;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'text';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;

    if (my $session = $self->controller->meritcommons_session) {

        if ($session->is_expired) {
            $self->controller->auth_log(
                "@{[$self->controller->active_user->userid]} - session expired - " . 
                "expired session discovered in hydrant during session_heartbeat call"
            );
            $self->controller->destroy_session('session expired - expired session discovered in hydrant during session_heartbeat call');
        } else {
            my $heartbeat_from = "Hydrant::SessionHeartbeat: " . substr($arg, 0, 220);
            $self->controller->session_heartbeat($heartbeat_from);
            $self->send("heartbeat reason - $heartbeat_from", "session_heartbeat:reply");
        }

    } else {
        die "session_heartbeat called with no session";
    }
}

1;
