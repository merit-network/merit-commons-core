#    MeritCommons Portal
#    Copyright 2018 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Unwatch;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;
    my $user = $self->controller->active_user;

    if ($user) {
        my $unwatched_count = 0;
        foreach my $item (qw/message stream user/) {
            my $method = "watched_${item}s";
            if (my $id = $data->{$item}) {
                if (my $watch = $user->$method->find({ target => $id })) {
                    $watch->delete;
                    $unwatched_count++;
                }
            }
        }

        $self->send(
            { success => 1, message => "Unwatched $unwatched_count item(s).", unwatched_count => $unwatched_count },
            "unwatch:response");
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input($arg);
        $v->optional('message')->like($self->F_UUID);
        $v->optional('stream')->like($self->F_UUID);
        $v->optional('user')->like($self->F_UUID);
        return $v;
    }

    return undef;
}

1;
