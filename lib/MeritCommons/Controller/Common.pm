#    MeritCommons Portal
#    Copyright 2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Common;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

sub loading {
    my ($c) = @_;
    my $app_name = $c->param('app_name');
    unless ($app_name =~ /^[\w\s\-]+$/) {
        $app_name = "Your Application";
    }

    my $attempt_id = $c->param('attempt_id');
    if ($attempt_id && ($attempt_id =~ /^[A-F0-9-]{36}$/)) {
        $c->render(
            'general/loading',
            app_name   => $app_name,
            attempt_id => $attempt_id,
        );
    } else {
        $c->render(
            'general/loading',
            app_name   => $app_name,
            attempt_id => '',
        );
    }
}

1;
