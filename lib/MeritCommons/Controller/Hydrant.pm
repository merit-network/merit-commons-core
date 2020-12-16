#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Hydrant;

# declare our @ISA
our @ISA;
use utf8;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw/decode_json/;
use Mojo::Asset;
use Mojo::Asset::File;
use Mojo::Asset::Memory;
use Mojo::ByteStream;
use Scalar::Util qw/weaken/;

# Requirements.
use MeritCommons::Hydrant;

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    unless ($self->meritcommons_session) {
        $self->render(text => '');
        return;
    }

    # mojo 60 minute connection timeouts
    Mojo::IOLoop->stream($self->tx->connection)->timeout($self->app->config->{websocket_inactivity_timeout} || 3600);

    # 100MB websocket message size limit.
    $self->tx->max_websocket_size($self->app->config->{websocket_max_message_size} || 1024000 * 100);

    my $hydrant = MeritCommons::Hydrant->new($self);

    $self->on(
        text => sub {
            my ($ws, $msg) = @_;
            $hydrant->dispatch($msg);
        }
    );

    $self->on(
        binary => sub {
            my ($ws, $msg) = @_;

            if (substr($msg, 0, 15) eq "MERITCOMMONSBINARY") {

                # this is a binary payload, get header length, which ends at the first non-numeric byte
                my $header_length;
                my $header_starts;

                #
                for ($header_starts = 15 ; $header_starts < 256 ; $header_starts++) {
                    my $pos = substr($msg, $header_starts, 1);
                    if (substr($msg, $header_starts, 1) =~ /^\d$/) {
                        $header_length .= $pos;
                    } else {
                        last;
                    }
                }

                # this is where the header ends!
                my $header_ends = $header_starts + $header_length;

                # bytes -> utf-8 -> json decode -> hash ref.
                my $header = decode_json(Mojo::ByteStream->new(substr($msg, $header_starts, $header_length)));

                # now some information about the binary.
                my $binary_starts = $header_ends;
                my $binary_length = length($msg) - $header_ends;

                # depending on the size of this file we may write it to disk or load it into memory.  we write to file if
                # it's greater than or equal to 256KB.
                my $asset;
                if ($binary_length >= 131072 * 2) {
                    $asset = Mojo::Asset::File->new();
                } else {
                    $asset = Mojo::Asset::Memory->new();
                }
                $asset->add_chunk(substr($msg, $binary_starts, $binary_length));

                # dispatch
                $hydrant->binary_dispatch($header, $asset);
            }
        }
    );

    $self->on(
        finish => sub {
            my ($ws, $msg) = @_;
            $hydrant->cleanup;
            warn "[hydrant] connection finished and cleaned up for " . $self->active_user->userid . "\n"
              if $ENV{MERITCOMMONS_DEBUG};
        }
    );
}

sub watch {
    my ($self) = @_;
    $self->render(template => "general/watch");
}

sub DESTROY {
    my ($self) = @_;
    if ($self->{was_websocket}) {
        $self->agent_write('WEBSOCKET_CLIENT_FINISH ' . $self->new_uuid);
    }
}

1;
