#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::Superclick;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $data) = @_;

    if (my $link = $self->controller->link_by_short_loc($data->{short_loc})) {
        my $user = $self->controller->active_user;
        if ($user) {
            my $self_identity = $user->identities->search({}, { order_by => { -desc => 'multiplier' } })->first;

            # now get the highest number of clicks..
            my $highest_click =
              $self->controller->m->resultset('Link::Click')->search({ identity => $self_identity->id })
              ->get_column('counter')->max();
            my $counter;
            if ($highest_click >= 10000) {
                $counter = int($highest_click * 1.01);    # add 1%
            } else {
                $counter = 10000;                         # default to 10k.
            }

            # Look for existing link clicks to update
            my $link_click = $self->controller->m->resultset('Link::Click')->search(
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

            my $session_id = $self->controller->meritcommons_session->session_id;

            # clear this user's most clicked links cache.
            $self->controller->cache->set('mc_links:' . $session_id . ':5',  '');
            $self->controller->cache->set('mc_links:' . $session_id . ':10', '');
            $self->controller->cache->set('mc_links:' . $session_id . ':15', '');
        }

        $self->send("superclick of @{[$link->short_loc]} by @{[$user->userid]} successful", 'superclick:success');
    } else {
        $self->reply->not_found;
    }
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure link short aliases look like words
        $v = $v->input($arg);
        $v->required('short_loc')->like($self->F_WORD);
        return $v;
    }

    return undef;
}

1;
