#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Sysinfo;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::UserAgent;
use Mojo::Base 'Mojolicious::Controller';
use YAML qw(LoadFile);

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    if ($self->app->mode eq "development") {
        my $meritcommons_sys;
        $self->stash(meritcommons_sys => $meritcommons_sys);
        $self->render(template => "sysinfo/default");
    } else {
        $self->reply->not_found;
    }
}

# quick self sanity check for monitoring
sub self_check {
    my ($c) = @_;

    # by default we pass.
    $c->res->code(200);
    $c->res->headers->content_type('text/plain');
    $c->res->body("PASS");

    # these errors might get clobbered by the core system errors checked for below
    $c->app->emit('self_check' => $c);

    # check database
    my $db_ping;
    eval { $db_ping = $c->m->storage->dbh->ping; };

    if (my $error = $@) {
        $c->app->log->error("self_check - database unavailable!");
    }

    unless ($db_ping) {
        $c->res->body(
            "FAIL - @{[$c->instance_id]} - database unavailable; application is down; please contact tier 2 support immediately!"
        );
    }

    # check async_master
    if ($db_ping && `ps -ef | grep async_master | grep -v grep | wc -l` < 1) {
        $c->res->body(
            "FAIL - @{[$c->instance_id]} - async_master not found in process table; application is up; please escalate to tier 2"
        );
    }

    # check publisher
    if ($db_ping && `ps -ef | grep meritcommons_publisher | grep -v grep | wc -l` < 1) {
        $c->res->body(
            "FAIL - @{[$c->instance_id]} - meritcommons_publisher not found in process table; application is up; please escalate to tier 2"
        );
    }

    # check notifier
    if ($db_ping && `ps -ef | grep meritcommons_notifier | grep -v grep | wc -l` < 1) {
        $c->res->body(
            "FAIL - @{[$c->instance_id]} - meritcommons_notifier not found in process table; application is up; please escalate to tier 2"
        );
    }

    # check system_agent
    if ($db_ping && `ps -ef | grep meritcommons_system_agent | grep -v grep | wc -l` < 1) {
        $c->res->body(
            "FAIL - @{[$c->instance_id]} - meritcommons_system_agent not found in process table; application is up; please escalate to tier 2"
        );
    }

    $c->rendered;
}

# redirects to the bundle URL
sub css_bundle {
    my ($self) = @_;

    if ($self->app->mode eq "production") {
        $self->redirect_to($self->production_css_bundle);
    } else {
        $self->redirect_to($self->development_css_bundle);
    }
}

# reidrects to the bundle URL
sub js_bundle {
    my ($self) = @_;
    if ($self->app->mode eq "production") {
        $self->redirect_to($self->production_js_bundle);
    } else {
        $self->render(text => "alert('MeritCommons in development mode, there is no development JavaScript bundle.')",);
    }
}

1;
