# MeritCommons Portal
# Copyright 2015 Wayne State University
# All Rights Reserved

package MeritCommons::Hydrant::Command::Stream;

use Mojo::Base qw/MeritCommons::Hydrant::Command/;
use Mojo::JSON qw/decode_json true false/;

has subcommands         => 1;
has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data, $command) = @_;

    my $c = $self->controller;

    if ($command) {
        if ($command eq "verify") {
            my $attr    = $data->{attribute};
            my $command = "verify_" . $attr;
            if ($self->can($command)) {
                $self->send($self->$command($data));
            } else {
                $self->send("You cannot verify that stream attribute.");
            }
        } elsif ($self->can($command . "_stream")) {
            $command = $command . "_stream";
            $self->send($self->$command($data));
        } else {
            $self->send("Invalid command.");
        }
    } else {
        $self->send("No command specified.");
    }
}

sub update_stream {
    my ($self, $data) = @_;

    my $c = $self->controller;

    my $url = $data->{url} or return { error => "Invalid URL." };
    my $stream = $c->m->resultset('Stream')->find({ unique_id => $data->{id} });

    my $stream_settings;
    if ($stream) {
        $stream_settings = {
            unique_id     => $data->{id},
            common_name   => $data->{name},
            url_name      => $url,
            description   => $data->{description},
            keywords      => $data->{keywords},
            private       => $data->{is_private},
            show_publicly => $data->{is_private} ? 0 : $data->{is_listed},    # implied value if stream is private
            requires_subscriber_authorization => $data->{is_private} ? 1 : ($data->{is_membership_open} ? 0 : 1), # implied value if stream is private
            requires_author_authorization => $data->{membership_includes_authorship} ? 0 : 1,
            members_can_invite => $data->{members_can_invite},
            membership_requires_moderator_approval => $data->{invites_require_approval},
            display_subscribers                    => $data->{list_members},

            #role_restricted => $data->{role_restricted},
            #permitted_roles =>$data->{permitted_roles},
        };
    } else {
        return { error => "Stream does not exist." };
    }

    return $c->update_stream($c->active_user, $stream_settings, $c->active_user);
}

sub create_stream {
    my ($self, $data) = @_;

    my $c = $self->controller;

    my $url = $data->{url} or return { error => 'Invalid URL.' };

    my $stream_settings = {
        unique_id     => $c->new_uuid,
        creator       => $c->active_user->id,
        common_name   => $data->{name},
        url_name      => $url,
        description   => $data->{description},
        keywords      => $data->{keywords},
        private       => $data->{is_private},
        show_publicly => $data->{is_private} ? 0 : $data->{is_listed},    # implied value if stream is private
        requires_subscriber_authorization => $data->{is_private} ? 1 : ($data->{is_membership_open} ? 0 : 1), # implied value if stream is private
        requires_author_authorization => $data->{membership_includes_authorship} ? 0 : 1,
        members_can_invite => $data->{members_can_invite},
        membership_requires_moderator_approval => $data->{invites_require_approval},
        display_subscribers                    => $data->{list_members},
        type                                   => 'user',

        #role_restricted => $data->{role_restricted},
        #permitted_roles =>$data->{permitted_roles},
    };

    return $c->create_stream($stream_settings, $c->active_user);
}

sub verify_url {
    my ($self, $data) = @_;

    my $c = $self->controller;

    my $response;
    $response->{verified} = "url";

    my $stream;
    if ($data->{id}) {
        $stream = $c->m->resultset('Stream')->find({ unique_id => $data->{id} });
    }

    if ($data->{url}) {
        my $url_name = $data->{url};
        if ($stream && $stream->url_name eq $url_name) {
            $response->{valid} = 1;
        } else {
            $response->{valid} = $c->check_valid_stream_url_name($url_name);
        }
    } else {
        $response->{valid} = 0;
    }

    return $response;
}

sub validate {
    my ($self, $arg, $command) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        if ($command eq "verify") {
            $v->required('attribute')->like($self->F_WORD);
            $v->optional('id')->like($self->F_UUID);
            $v->optional('url')->like($self->F_WORD);
        } elsif ($command eq "update") {
            $v->required('id')->like($self->F_UUID);
            $v->required('name')->like($self->F_STREAM_NAME);
            $v->required('url')->like($self->F_WORD);
            $v->required('description');
            $v->optional('keywords');
            $v->required('is_private')->like($self->F_INT);
            $v->required('is_listed')->like($self->F_INT);
            $v->required('is_membership_open')->like($self->F_INT);
            $v->required('membership_includes_authorship')->like($self->F_INT);
            $v->required('members_can_invite')->like($self->F_INT);
            $v->required('invites_require_approval')->like($self->F_INT);
            $v->required('list_members')->like($self->F_INT);

            #$v->required('role_restricted')->like($self->F_INT);
            #$v->required('permitted_roles')->like($self->F_WORD);
        } elsif ($command eq "create") {
            $v->required('name')->like($self->F_STREAM_NAME);
            $v->required('url')->like($self->F_WORD);
            $v->required('description');
            $v->optional('keywords');
            $v->required('is_private')->like($self->F_INT);
            $v->required('is_listed')->like($self->F_INT);
            $v->required('is_membership_open')->like($self->F_INT);
            $v->required('membership_includes_authorship')->like($self->F_INT);
            $v->required('members_can_invite')->like($self->F_INT);
            $v->required('invites_require_approval')->like($self->F_INT);
            $v->required('list_members')->like($self->F_INT);

            #$v->required('role_restricted')->like($self->F_INT);
            #$v->required('permitted_roles')->like($self->F_WORD);
        }

        return $v;
    }

    return undef;
}

1;
