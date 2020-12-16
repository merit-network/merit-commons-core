#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::StreamSearch;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/encode_json decode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $search) = @_;

    $search->{requestor} = $self->controller->active_user->unique_id;

    $self->controller->run_async_task(
        stream_search => sub {
            my ($cmd, $doc) = @_;

            # return the search results
            $cmd->send(encode_json($doc->{payload}), "stream_search:results");
        },
        {
            command  => $self,
            priority => 5,
            args     => [$search],
        }
    );
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->optional('search_string')->like($self->F_SEARCH_STRING)->size(3, 255);
        $v->optional('type')->in(qw/ role system user /);
        $v->optional('minimum_subscribers')->like($self->F_INT);
        $v->optional('private')->in(0, 1);

        return $v;
    }

    return undef;
}

1;
