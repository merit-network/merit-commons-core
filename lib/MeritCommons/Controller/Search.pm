#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Search;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw/to_json/;

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    if (my $user = $self->active_user) {

        # Establish the collection of search streams.  If a search stream was passed, validate that
        # the user has access to it.  If there was no search scope, use authorized subscribed streams.
        my $search_streams;
        if ($self->param('stream') && ($self->param('stream') =~ /^\d+?$/)) {
            $search_streams = [ $self->active_user->authorized_streams_filter(@{ $self->every_param('stream') }) ];
            $self->stash(search_stream_filter => $self->param('stream'));
        } else {
            $search_streams = [ $self->active_user->authorized_subscribed_streams ];
        }

        # From the collection of search streams, create a subscription hash.
        # Also, create an array of the stream stream IDs, to pass to the Sphinx search
        my $subscriptions = {};
        my @search_stream_ids;
        foreach my $search_stream (@$search_streams) {
            $subscriptions->{ $search_stream->unique_id } = $search_stream->id;
            push @search_stream_ids, $search_stream->id;
        }

        # Search Messages
        my @message_results =
          $self->active_user->search_messages($self->sphinx_h, $self->param('query'), undef, undef, @search_stream_ids);

        # Links
        my @link_results = $user->search_links($self->sphinx_h, $self->param('query'));

        # Streams (we pass the user object)
        my @stream_results = $user->search_streams($self->sphinx_h, $self->param('query'));

        # Users
        my @user_results = $self->search_users($self->sphinx_h, $self->param('query'));

        # Get contents of matching messages
        my @message_results_payload = $self->app->prepare_payload(\@message_results, $user, 1);

        # encode search options query as JSON to prevent JS injection
        $self->stash(
            "search_options",
            $self->json_encode(
                {
                    query      => $self->param('query'),
                    stream_ids => [@search_stream_ids]
                }
            )
        );

        $self->stash(query                   => $self->param('query'));
        $self->stash(link_results            => \@link_results);
        $self->stash(stream_results          => \@stream_results);
        $self->stash(user_results            => \@user_results);
        $self->stash(message_results_payload => \@message_results_payload);
        $self->stash(subscriptions           => $self->json_encode($subscriptions));
        $self->stash(payload_messages        => \@message_results_payload);
        $self->stash(payload_messages_json   => to_json(\@message_results_payload));

        $self->render(template => "search/default");
    } else {
        $self->reply->not_found;
    }

}

sub identify {
    my ($self) = @_;

    my ($who, $user) = ($self->param('who'), undef);
    if ($who eq "_me") {
        $user = $self->active_user;
    } else {
        $user = $self->user($self->param('who'));
    }

    if ($user) {
        $self->render(text => $user->public_key->aa_public);
    } else {
        $self->render(text => '');
    }
}

sub identify_options {
    my ($self) = @_;
    $self->res->headers->add('Access-Control-Allow-Origin'  => '*');
    $self->res->headers->add('Access-Control-Allow-Methods' => 'IDENTIFY');
    $self->res->headers->allow('GET, POST, IDENTIFY');
    $self->render(text => '');
}

1;
