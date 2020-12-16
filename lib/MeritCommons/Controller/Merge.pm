#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Merge;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw/to_json/;

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    return if $self->features_detected;

    # we need to prefetch + stash subscriptions
    $self->util->stash_stream_subscriptions;

    # these pages are big, let's turn gzip on...
    $self->stash(gzip => 1);

    $self->res->headers->cache_control('no-store');

    if ($self->active_user) {
        my @payload_messages = $self->messages->merged({ user => $self->active_user, limit => 7 });

        # We've already stashed all of our subscription above.  This is the same set
        # that we should use to render the merge, so let's use that stashed variable
        my @subscriptions                = ();
        my %all_subscriptions_by_subtype = %{ $self->stash('all_subscriptions_by_subtype') };
        foreach my $subtype (keys %all_subscriptions_by_subtype) {
            push(@subscriptions, @{ $all_subscriptions_by_subtype{$subtype} });
        }

        $self->stash(subscriptions         => [@subscriptions]);
        $self->stash(payload_messages      => \@payload_messages);
        $self->stash(payload_messages_json => to_json(\@payload_messages));
        $self->render(template => "stream/default");
    } else {
        $self->render(template => "general/welcome");
    }
}

1;
