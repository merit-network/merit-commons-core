#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::InboundDebug;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Array::Utils qw(:all);
use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::Util qw/b64_decode/;

has expects             => 'text';
has user_activity_flag  => 0;

sub command {
    my ($self, $arg) = @_;

    if ($self->controller->config->{inbound_debug}) {
        $self->controller->app->log->info("[inbound_debug] @{[b64_decode($arg)]}");
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        return $v->input({ log_data => $arg })->required('log_data')->size(1, 40960);
    }

    return undef;
}

1;
