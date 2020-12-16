#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::GetModerationPage;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

use Mojo::JSON qw/encode_json decode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    my $controller = $self->controller;
    my $actor      = $controller->active_user;

    my $stream = $controller->stream($data->{streamId});

    if ($stream) {
        my $page = $data->{page};
        if ($page < 1) {
            $page = 1;
        }

        my $type = $data->{type};

        # This is ugly, but I'm trying to keep the terminology in the DOM the same here...
        if ($type eq 'subscription') {
            $type = 'subscribers';
        } elsif ($type eq 'authorship') {
            $type = 'authors';
        } elsif ($type eq 'moderatorship') {
            $type = 'moderators';
        } elsif ($type eq 'invite') {
            $type = 'invites';
        }

        # Permissions are enforced in the get_permissions helper
        my @result = $controller->get_permissions($actor, $stream, $type, $page);

        if (@result) {
            $self->send(
                {
                    streamId    => $stream->unique_id,
                    type        => $type,
                    page        => $page,
                    permissions => $result[0],
                },
                'permission_page:fetched'
            );
        }
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->required('streamId')->like($self->F_UUID);
        $v->required('type')
          ->in(qw/subscription subscribers authorship authors moderatorship moderators invite invites/);
        $v->optional('page')->like($self->F_INT);
        return $v;
    }

    return undef;
}

1;
