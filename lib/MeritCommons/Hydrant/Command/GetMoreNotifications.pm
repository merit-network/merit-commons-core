#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::GetMoreNotifications;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/encode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;
    my @args = ($arg);
    push(@args, $self->controller->active_user->id);

    $self->controller->run_async_task(
        get_more_notifications => sub {
            my ($cmd, $doc) = @_;
            foreach my $payload (@{ $doc->{payload}->{message} }) {
                if ($ENV{MERITCOMMONS_DEBUG}) {
                    warn "[hydrant] shoving across notification payload " .
                      length(encode_json($payload)) . " bytes in size.\n";

                }

                $cmd->send($payload, 'message:subscribed', $payload->{render_as});
            }
        },
        $self,
        @args
    );
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('beforeId')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
