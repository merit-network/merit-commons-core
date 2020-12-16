#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::BlockEntities;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Array::Utils qw(:all);
use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/decode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;

    $self->send($self->controller->block_entities(@{ $arg->entities }) . " entities blocked", 'blockentities:response');
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        return $v->input($arg)->required('entities')->like($self->F_UUID);
    }

    return undef;
}
1;
