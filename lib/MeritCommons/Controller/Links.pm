#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Links;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

use MIME::Base64 qw/encode_base64url decode_base64url/;
use Crypt::Digest qw/digest_data/;
use Mojo::URL;
use Mojo::UserAgent;
use File::Basename qw/fileparse/;

# proxy assets with signed urls!
sub asset_proxy {
    my ($self) = @_;

    if ($self->app->config->{enable_ssl_asset_proxy}) {

        # get the actual URL...
        my ($b64_encoded) = $self->stash('encoded_url') =~ /^([^\.]+)/;
        my $asset_url = decode_base64url($b64_encoded);

        # verify the hash..
        if (my $secret = $self->app->config->{ssl_asset_proxy_secret}) {
            if (digest_data('SHA256', $asset_url . $secret) eq decode_base64url($self->stash('proxy_hmac'))) {
                $self->ua->get(
                    $asset_url => { 'X-Forwarded-For' => $self->tx->remote_address } => sub {
                        my ($ua, $tx) = @_;
                        if (my $code = $tx->res->code) {
                            if ($code eq "404") {
                                $self->reply->not_found;
                            } else {

                                # copy over a few things...
                                $self->res->headers->content_type($tx->res->headers->content_type);
                                $self->res->body($tx->res->body);
                                $self->res->fix_headers;
                                $self->rendered($tx->res->code);
                            }
                        } else {
                            $self->reply->not_found;
                        }
                    }
                );
            } else {
                $self->reply->not_found;
            }
        } else {
            $self->reply->not_found;
        }
    } else {
        $self->reply->not_found;
    }
}

#
# the default handler method! :)
#
sub short_loc_redirect {
    my ($self) = @_;
    if (my $link = $self->app->link_by_short_loc($self->stash('short_loc'))) {
        my $user = $self->active_user;
        if ($user && ($link->collections->count >= 1)) {
            my @identities = $user->identities;

            my @identity_ids = map { $_->id } @identities;

            # Look for existing link clicks to update
            my $link_click_resultset = $self->app->m->resultset('Link::Click')->search(
                {
                    'identity' => [@identity_ids],
                    'link'     => $link->id,
                }
            );

            # Increment existing link clicks by 1
            $link_click_resultset->update(
                {
                    counter => \'counter + 1'
                }
            );

            # Identify link click ids that already exist
            my @link_clicks = $link_click_resultset->all;
            my @link_click_identity_ids = map { $_->get_column('identity') } @link_clicks;

            # Insert new link_click records if one doesn't already exist for the identitiy
            my @new_identities;
            foreach my $identity (@identities) {
                if (!(grep $_ eq $identity->id, @link_click_identity_ids)) {
                    push(@new_identities,
                        { identity => $identity->id, create_time => time, link => $link->id, counter => 1 });
                }
            }
            $link->clicks->populate(\@new_identities);    # bulk insert
        }

        $self->redirect_to($link->href);
    } else {
        $self->reply->not_found;
    }
}

# superclick.  the self identity clicks this link 10,000 times.
sub superclick {
    my ($self) = @_;
    if (my $link = $self->app->link_by_short_loc($self->stash('short_loc'))) {
        my $user = $self->active_user;
        if ($user && ($link->collections->count >= 1)) {
            my $self_identity = $user->identities->search({}, { order_by => { -desc => 'multiplier' } })->first;

            # now get the highest number of clicks..
            my $highest_click = $self->app->m->resultset('Link::Click')->search({ identity => $self_identity->id })
              ->get_column('counter')->max();
            my $counter;
            if ($highest_click >= 10000) {
                $counter = int($highest_click * 1.01);    # add 1%
            } else {
                $counter = 10000;                         # default to 10k.
            }

            # Look for existing link clicks to update
            my $link_click = $self->app->m->resultset('Link::Click')->search(
                {
                    'identity' => $self_identity->id,
                    'link'     => $link->id,
                }
            )->first;

            if ($link_click) {
                $link_click->update(
                    {
                        counter => $counter,
                    }
                );
            } else {
                $link->clicks->create(
                    {
                        identity    => $self_identity->id,
                        create_time => time,
                        link        => $link->id,
                        counter     => $counter,
                    }
                );
            }

            # clear this user's most clicked links cache.
            $self->app->cache->set('mc_links:' . $self->meritcommons_session->session_id . ':5',  '');
            $self->app->cache->set('mc_links:' . $self->meritcommons_session->session_id . ':10', '');
            $self->app->cache->set('mc_links:' . $self->meritcommons_session->session_id . ':15', '');
        }

        my $url = $self->url_for($self->tx->req->headers->referrer) || $self->url_for('/');

        $self->redirect_to($url);
    } else {
        $self->reply->not_found;
    }
}

# unsuperclick.  the self identity unclicks this link 10,000 times.
sub unsuperclick {
    my ($self) = @_;
    if (my $link = $self->app->link_by_short_loc($self->stash('short_loc'))) {
        my $user = $self->active_user;
        if ($user) {
            my $self_identity = $user->identities->search({}, { order_by => { -desc => 'multiplier' } })->first;

            # Look for existing link clicks to update
            my $link_click = $self->app->m->resultset('Link::Click')->search(
                {
                    'identity' => $self_identity->id,
                    'link'     => $link->id,
                }
            )->first;

            if ($link_click) {
                $link_click->update(
                    {
                        counter => 0,
                    }
                );
            } else {
                $link->clicks->create(
                    {
                        identity    => $self_identity->id,
                        create_time => time,
                        link        => $link->id,
                        counter     => 0,
                    }
                );
            }

            # clear this user's most clicked links cache.
            $self->app->cache->set('mc_links:' . $self->meritcommons_session->session_id . ':5',  '');
            $self->app->cache->set('mc_links:' . $self->meritcommons_session->session_id . ':10', '');
            $self->app->cache->set('mc_links:' . $self->meritcommons_session->session_id . ':15', '');
        }

        my $url = $self->url_for($self->tx->req->headers->referrer) || $self->url_for('/');

        $self->redirect_to($url);
    } else {
        $self->reply->not_found;
    }
}

1;
