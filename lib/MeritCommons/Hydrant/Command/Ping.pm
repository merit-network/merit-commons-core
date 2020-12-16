#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Ping;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'text';
has user_activity_flag  => 0;

sub command {
    my ($self, $arg) = @_;

    unless ($self->controller->{was_websocket}) {

        # connect on first successful ping!
        if ($self->controller->tx->is_websocket) {
            $self->controller->{was_websocket} = 1;
            $self->controller->agent_write('WEBSOCKET_CLIENT_CONNECT ' . $self->controller->new_uuid);
        }
    }

    $self->send("pong $arg", "ping:reply");
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input({ timestamp => $arg })->required('timestamp')->like($self->F_TIMESTAMP);
        return $v;
    }

    return undef;
}

1;
