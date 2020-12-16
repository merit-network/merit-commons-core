#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant;

use strict;

# Requirements.
use EV;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Mojo::IOLoop;
use Time::HiRes;
use Scalar::Util qw/weaken/;
use Mojo::URL;
use Mojo::JSON qw/encode_json to_json decode_json from_json/;
use Mojo::Util qw/camelize/;
use Mojo::Loader qw/load_class/;
use Mojo::File;

use Mojo::Base -base;

has [qw/controller zmq_context zmq_subscriber zmq_fd shutdown_protection/];

has expect_rules => sub {
    {
        stream => sub {
            return shift->controller->stream(shift);
        },
        streams => sub {
            return [ map { $_[0]->controller->stream($_) } @{ $_[1] } ];
        },
        message => sub {
            return shift->controller->message(shift);
        },
        messages => sub {
            return [ map { $_[0]->controller->message($_) } @{ $_[1] } ];
        },
        user => sub {
            return shift->controller->user(shift);
        },
        users => sub {
            return [ map { $_[0]->controller->user($_) } @{ $_[1] } ];
        },
        json => sub {
            return decode_json($_[1]);
        },
        text => sub {
            return $_[1];
        }
    };
};

# $controller should always be a websocket, if it's not, you're gonna have a bad time
sub new {
    my ($class, $controller) = @_;

    my $context = $MeritCommons::zmq_shared_context // zmq_ctx_new();
    my $subscriber = zmq_socket($context, ZMQ_SUB);

    # larger recv buffer
    zmq_setsockopt($subscriber, ZMQ_RCVBUF, 65536);
    zmq_setsockopt($subscriber, ZMQ_LINGER, 0);

    foreach my $publisher (@{ $controller->publishers }) {
        my $connected;
        until ($connected) {
            my $errno = zmq_connect($subscriber, $publisher);
            if ($errno == 0) {
                $connected = 1;
            } else {
                warn "[error] error connecting to $publisher: $!, " . zmq_strerror($errno) . "\n";
            }
        }
    }

    # subscribe to WEBSOCKET events, for alerting the websocket of system changes
    zmq_setsockopt($subscriber, ZMQ_SUBSCRIBE, 'WEBSOCKET');

    # also subscribe to our session_id so we can know when to log out..
    zmq_setsockopt($subscriber, ZMQ_SUBSCRIBE, $controller->meritcommons_session->session_id);

    # get a filehandle from the subscriber socket, so we can watch it in the IOLoop.
    open my $subfh, "<&=", zmq_getsockopt($subscriber, ZMQ_FD)
      or $controller->app->log->error("[error] can't open ZMQ subscription file descriptor!");

    my $hydrant = bless(
        {
            controller     => $controller,
            zmq_subscriber => $subscriber,
            zmq_fd         => $subfh,
            zmq_context    => $context,
        },
        $class
    );

    Mojo::IOLoop->singleton->reactor->io(
        $subfh => sub {
            my ($reactor) = @_;
            my $poll_event = {};
            while (zmq_getsockopt($subscriber, ZMQ_EVENTS) == ZMQ_POLLIN) {

                # read address (stream id) from ZMQ
                my $a_msg = zmq_msg_init();
                zmq_msg_recv($a_msg, $subscriber);
                my $address = zmq_msg_data($a_msg);
                return unless $address;

                # read payload (message id) from ZMQ
                my $c_msg = zmq_msg_init();
                zmq_msg_recv($c_msg, $subscriber);
                my $contents = zmq_msg_data($c_msg);

                # most common first.
                if ($contents =~ /^[0-9a-fA-F\-]+$/) {

                    # it's a message!
                    my $cache_hit = 1;
                    my ($event_uuid, $start_time);
                    if ($ENV{MERITCOMMONS_DEBUG}) {
                        $event_uuid = $controller->new_uuid;
                        $start_time = Time::HiRes::time();
                        warn "[hydrant] Preparing and sending message $contents ($event_uuid)\n";
                    }

                    my $rendered_json;
                    unless ($rendered_json = $controller->cache->get($contents)) {

                        # cache miss!
                        # fetch the message and return its payload
                        my $message =
                          $controller->app->m->resultset('Stream::Message')->find({ unique_id => $contents });
                        my $payload = $controller->app->msg->prepare($message, $controller->active_user);
                        $rendered_json = encode_json($payload);

                        # update the cache.
                        $controller->cache->set($contents, $rendered_json);
                        $cache_hit = 0;
                    }

                    # only send messages over that we haven't just sent over.
                    if ($poll_event->{$contents}) {
                        unless ($cache_hit) {
                            $hydrant->send(0, $rendered_json, 'message:subscribed');
                        }
                    } else {
                        $hydrant->send(0, $rendered_json, 'message:subscribed');
                    }

                    # take note of the fact that we've seen this before.
                    $poll_event->{$contents}++;

                    if ($ENV{MERITCOMMONS_DEBUG}) {
                        warn "[hydrant] sending @{[$controller->active_user->userid]} notice about ID $contents\n";
                        warn "[hydrant] $event_uuid complete in " .
                          sprintf("%.04f", Time::HiRes::time() - $start_time) . " seconds, Cache Hit? $cache_hit\n";
                    }
                } elsif ($contents eq "async:finished") {

                    # this is a task that we have subscribed to that has completed,
                    # run the postflight and clean it up here.
                    $controller->finish_async_task($address, $hydrant);
                } elsif ($address eq "WEBSOCKET") {

                    # this is a system event.  the only one we care about right now is this one
                    if ($contents =~ /^COORDINATOR_NODE_SHUTDOWN_IMMINENT (.+)$/) {
                        my $payload = $1;

                        # make sure we answer calls to /myws with the replacement's hostname from here on out
                        my ($request_id, $instance_id, $replacement_host, @rest) = split(/\s+/, $payload);

                        if ($controller->instance_id eq $instance_id) {
                            my $url = Mojo::URL->new($controller->app->config->{advertised_websocket});
                            $url->host($replacement_host);
                            $controller->app->{meritcommons_myws_override} = $url->to_string;

                            unless (-e '/var/tmp/meritcommons_myws_override') {
                                Mojo::File->new('/var/tmp/meritcommons_myws_override')->spurt($url->to_string);
                            }

                            my $migrate_in = int(1000 + (rand(60) * 1000));

                            # tell our listener, these events come across as id '10'
                            $hydrant->send(
                                10,
                                {
                                    replacement_hydrant => $url->to_string,
                                    migrate_in          => $migrate_in,
                                },
                                'system:hydrant_migration'
                            );

                            # just in case something on the JS side doesn't work right, let's schedule
                            # a shutdown of this socket.
                            $reactor->timer(
                                int(($migrate_in / 1000) + 2) => sub {
                                    my ($reactor) = @_;
                                    unless ($controller->tx && $controller->tx->is_finished) {
                                        warn
                                          "[hydrant] websocket connection for user @{[$controller->active_user->userid]} was not migrated by javascript side during migration, closing.\n"
                                          if $ENV{MERITCOMMONS_DEBUG};
                                        $controller->finish;
                                    }
                                }
                            );
                        }
                    }
                } elsif ($contents eq "session:destroy") {

                    # this is a session destroy.. make sure the address is our sessionid (sanity checks never hurt)
                    if ($address eq $controller->meritcommons_session->session_id) {

                        # time to kill this websocket.
                        $controller->finish;
                    }
                } elsif ($contents eq "session:info") {

                    # this is a message about this session
                    if ($address eq $controller->meritcommons_session->session_id) {
                        my ($notice) = $controller->meritcommons_session->first_attribute_value('info_notice');

                        my $hr;
                        eval { $hr = decode_json($notice) };

                        if (ref $hr eq "HASH") {
                            $hydrant->send(0, $notice, $hr->{notice_type} // 'session:info');
                        } else {
                            $hydrant->send(0, $notice, 'session:info');
                        }
                    }
                }
            }
        }
    )->watch($subfh, 1, 0);

    return $hydrant;
}

sub dispatch {
    my ($self, $message) = @_;

    my ($id, $command, $arg) = $message =~ /^([0-9a-fA-F\-]{36}) (\w+)\s*(.*)[\r\n]*$/;

    # get the command object
    my $cmd = $self->fetch_cmd($id, $command);

    if (ref $cmd && $cmd->isa('MeritCommons::Hydrant::Command')) {

        # first see if it has subcommands..
        my $subcommand;
        if ($cmd->subcommands) {
            if ($arg =~ /^(\w+)\s*/) {
                $subcommand = $1;
                $arg =~ s/^$subcommand//g;
            }
        }

        # convert JSON at first...
        if ($cmd->expects && $cmd->expects eq "json") {
            $arg = $self->expect_rules->{"json"}->($self, $arg);
        }

        if (my $v = $cmd->validate($arg, $subcommand)) {
            if ($v->has_error) {
                my $log_content = $arg;
                if ($cmd->expects eq "json") {
                    $log_content = encode_json($arg);
                }

                foreach my $fail (@{ $v->failed }) {
                    my ($check, $result, @args) = @{ $v->error($fail) };
                    $self->send($id // -1,
                        "hydrant command '$command' validation failed for field '$fail'; field is $check @args",
                        'cmdresponse:error');
                }

                $self->controller->app->log->error(
                    "$command validation error from @{[$self->controller->tx->remote_address]} content '$log_content' failed checks @{[join(', ', @{$v->failed})]}"
                );

                # get rid of the validator so it re-initializes next time.
                delete $cmd->{validation};

                # no dispatch.
                return;
            } else {

                # if it's a hashref, make sure we supply the paired down version
                if (ref($arg) eq "HASH") {
                    $arg = $v->output;
                } elsif (!ref($arg)) {

                    # if it's just a string, let's see if there's just one key in output and make sure they match..
                    my @keys = keys %{ $v->output };
                    unless (scalar(@keys) == 1 && $arg eq $v->output->{ $keys[0] }) {
                        $self->send($id // -1, "validation output did not match input, considering input invalid",
                            'cmdresponse:error');
                        $self->controller->app->log->error(
                            "$command output did not match input; src-ip @{[$self->controller->tx->remote_address]}; content '$arg' passed checks @{[join(', ', @{$v->passed})]} but data was inconsistent.  rejecting."
                        );

                        # no dispatch.
                        return;
                    }
                }

                if ($ENV{MERITCOMMONS_DEBUG}) {
                    my $log_content = $arg;
                    if ($cmd->expects eq "json") {
                        $log_content = encode_json($arg);
                    }
                    $self->controller->app->log->debug(
                        "$command validation passed; src-ip @{[$self->controller->tx->remote_address]}; content '$log_content' passed checks @{[join(', ', @{$v->passed})]}"
                    );
                }
            }
        }

        # convert everything else down here...
        if ($cmd->expects && $cmd->expects ne "json") {
            $arg = $self->expect_rules->{ $cmd->expects }->($self, $arg);
        }

        eval { $cmd->command($arg, $subcommand); };
    }

    if (my $error = $@) {
        $self->send($id // -1, "no.", "cmdresponse:error");
        $self->controller->app->log->error("[fatal hydrant error]: $error, restarting WebSocket.");
        $self->controller->app->agent_write('WEBSOCKET_CLIENT_ERROR ' . $self->controller->app->new_uuid);
        $self->controller->finish;
    } elsif ($cmd->counts_as_user_activity) {
        # allow hydrant commands to heartbeat session
        $self->controller->session_heartbeat(substr(ref($cmd), 0, 254));
    }
}

sub binary_dispatch {
    my ($self, $header, $asset) = @_;

    unless (ref($header) eq "HASH") {
        $self->send(-1, "no.", "cmdresponse:error");
        $self->controller->app->log->error("MERITCOMMONSBINARY did not include valid JSON header ($header)");
        return undef;
    }

    if (my $command = $header->{command}) {
        if ($command =~ /^\w+$/) {

            my $cmd = $self->fetch_cmd($header->{request_id} // $self->controller->new_uuid, $command);

            if (ref $cmd && $cmd->isa('MeritCommons::Hydrant::Command')) {

                # if a request id wasn't provided in the header, make up a new one!
                eval { $cmd->command($header, $asset); };
            }

            if (my $error = $@) {
                $self->send(-1, "no.", "cmdresponse:error");
                $self->controller->app->log->error("[fatal hydrant error]: $error, restarting WebSocket.");
                $self->controller->finish;
            }
        } else {
            $self->send(-1, "no.", "cmdresponse:error");
            $self->controller->app->log->error("MERITCOMMONSBINARY command name did not match \\w");
            return undef;
        }
    } else {
        $self->send(-1, "no.", "cmdresponse:error");
        $self->controller->app->log->error("MERITCOMMONSBINARY JSON header did not specify what command to run");
        return undef;
    }
}

sub fetch_cmd {
    my ($self, $id, $command) = @_;

    my ($cmd, $error, $class);
    if (my $class = $self->{commands}->{$command}) {

        # nope, we have to instantiate new objects.
        $cmd = $class->new($id, $self);
    } else {
        foreach my $namespace ('MeritCommons::Hydrant::Command', @{ $self->controller->hydrant_namespaces }) {
            my $class = $namespace . "::" . camelize($command);

            eval { $cmd = $class->new($id, $self); };

            # not loaded yet!
            if ($@) {
                eval "require $class";
                if ($@) {
                    $error .= "$command not found in $class $@\n";
                } else {
                    eval { $cmd = $class->new($id, $self); };
                    if ($cmd) {
                        print "[hydrant] found command '$command' in class $class, registering.\n"
                          if $ENV{MERITCOMMONS_DEBUG};
                    }
                    $error .= $@;
                }
            }

            last if $self->{commands}->{$command} = ref($cmd);
        }
    }

    unless ($cmd) {
        $self->send(-1, "no.", "cmdresponse:error");
        $self->controller->app->log->error("error loading hydrant command: $error");
        warn "[hydrant error]: $error\n";
        return undef;
    }

    return $cmd;
}

# generic send method for all hydrant stuff.
sub send {
    my ($self, $hydrant_request_id, $body, $type, $render_as) = @_;

    # encode hashrefs or arrayrefs as json.. automagically!
    if (ref($body) eq "HASH" || ref($body) eq "ARRAY") {
        $body = encode_json($body);
    }

    $type      //= "cmdresponse:success";
    $render_as //= "info";

    $self->controller->send(
        to_json(
            {
                ws_msgtype         => $type,
                render_as          => $render_as,
                body               => $body,
                hydrant_request_id => $hydrant_request_id,
            }
        )
    );
}

sub cleanup {
    my ($self) = @_;

    # remove us from the IOLoop
    Mojo::IOLoop->singleton->reactor->remove($self->zmq_fd);
    zmq_close($self->zmq_subscriber);

    if ($MeritCommons::zmq_shared_context) {

        # never close this socket
        push(@{$MeritCommons::dead_zmq_handles}, $self->zmq_fd);
    }

    # let's clear these
    $self->{controller} = undef;
    $self->{commands}   = undef;
    $self->{cleaned_up} = 1;
}

sub DESTROY {
    my ($self) = @_;

    $self->cleanup unless $self->{cleaned_up};
    zmq_ctx_destroy($self->zmq_context) unless $MeritCommons::zmq_shared_context;
}

1;
