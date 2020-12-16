#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::GetMore;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/encode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $arg) = @_;

    my @args = ($arg);
    if (my $user = $self->controller->active_user) {
        push(@args, $user->id);

        $self->controller->run_async_task(
            get_more => sub {
                my ($cmd, $doc) = @_;

                foreach my $payload (@{ $doc->{payload}->{message} }) {
                    if ($ENV{MERITCOMMONS_DEBUG}) {
                        warn "[hydrant] shoving across message payload " .
                          length(encode_json($payload)) . " bytes in size.\n";
                    }

                    # notice we're not using $self->hydrant->send() here, as these are full messages.
                    $cmd->send(encode_json($payload), 'message:subscribed', $payload->{render_as});
                }
            },
            {
                command  => $self,
                priority => 5,
                args     => \@args
            }
        );
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('streams')->like($self->F_UUID);
        $v->optional('afterId')->like($self->F_UUID);
        $v->optional('after')->like($self->F_INT);
        $v->optional('searchFilter')->size(3, 255);
        return $v;
    }

    return undef;
}

1;
