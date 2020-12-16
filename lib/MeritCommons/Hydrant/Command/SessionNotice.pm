#    MeritCommons Portal
#    Copyright 2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::SessionNotice;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;

    if (my $session = $self->controller->meritcommons_session) {

        my $cache_key = "@{[$session->session_id]}-$arg->{attempt_id}";
        if (my $notice = $self->controller->cache->get($cache_key)) {
            $self->send($notice, "session_notice:reply");
            $self->controller->cache->set($cache_key, '{"consumed": true}');
        } else {
            $self->send('', "session_notice:reply");
        }
    } else {
        die "session_notice called with no session";
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('attempt_id')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
