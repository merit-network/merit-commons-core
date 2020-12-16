#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::ProxyHref;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'text';
has user_activity_flag  => 0;

sub command {
    my ($self, $href) = @_;
    if ($self->controller->active_user) {
        $self->send($self->controller->proxy_href($href), "proxy_href:response");
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input({ href => $arg })->required('href')->like($self->F_URI);
        return $v;
    }

    return undef;
}

1;
