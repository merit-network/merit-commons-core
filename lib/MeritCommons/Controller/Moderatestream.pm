#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Moderatestream;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    my @stream_identifiers = split(/\+\+/, $self->stash('stream_identifier'));
    if (scalar(@stream_identifiers) == 1) {
        my $stream_identifier = $stream_identifiers[0];

        if (my $user = $self->active_user) {
            my $stream;
            if ($stream_identifier eq "You") {
                $stream = $user->personal_inbox if $user->personal_inbox;
            }

            if ($stream || ($stream = $self->stream($stream_identifier))) {

                # Disable moderation on role streams.
                if (($stream->type && $stream->type ne "role") || !$stream->type) {

                    # The helper get_permissions checks for can_moderate too, but I guess I'll do it twice?  Probably a
                    # better way to do this.  Pass $mod to the helper as an option?
                    if (my $mod = $user->can_moderate($stream)) {
                        $self->stash(user   => $user);
                        $self->stash(stream => $stream);

                        my ($subs, $total_subs, $sub_rows_per_page) =
                          $self->get_permissions($user, $stream, 'subscribers', 1);
                        my $num_subscriber_pages = int($total_subs / $sub_rows_per_page) + 1;
                        $self->stash(subscriber_page      => 1);
                        $self->stash(num_subscriber_pages => $num_subscriber_pages);
                        $self->stash(
                            subscriber_table_data => $self->render_mustache(
                                'moderatestream/subscription_table',
                                {
                                    subs => $subs,
                                }
                            )
                        );

                        my ($auts, $total_auts, $aut_rows_per_page) =
                          $self->get_permissions($user, $stream, 'authors', 1);
                        my $num_author_pages = int($total_auts / $aut_rows_per_page) + 1;
                        $self->stash(author_page      => 1);
                        $self->stash(num_author_pages => $num_author_pages);
                        $self->stash(
                            author_table_data => $self->render_mustache(
                                'moderatestream/authorship_table',
                                {
                                    auts => $auts,
                                },
                                {
                                    row => 'moderatestream/author_row',
                                },
                            )
                        );

                        my ($invs, $total_invs, $inv_rows_per_page) =
                          $self->get_permissions($user, $stream, 'invites', 1);
                        my $num_invite_pages = int($total_invs / ($inv_rows_per_page || 1)) + 1;
                        $self->stash(invite_page      => 1);
                        $self->stash(num_invite_pages => $num_invite_pages);
                        $self->stash(
                            invite_table_data => $self->render_mustache(
                                'moderatestream/invite_table',
                                {
                                    invs => $invs,
                                }
                            )
                        );

                        if ($mod->allow_add_moderator || $user->is_admin) {
                            my ($mods, $total_mods, $mod_rows_per_page) =
                              $self->get_permissions($user, $stream, 'moderators', 1);
                            my $num_moderator_pages = int($total_mods / ($mod_rows_per_page || 1)) + 1;
                            $self->stash(moderator_page      => 1);
                            $self->stash(num_moderator_pages => $num_moderator_pages);

                            $self->stash(
                                moderator_table_data => $self->render_mustache(
                                    'moderatestream/moderatorship_table',
                                    {
                                        mods => $mods,
                                    },
                                    {
                                        row           => 'moderatestream/moderator_row',
                                        remove_button => 'moderatestream/moderator_row_remove_button',
                                    },
                                )
                            );
                        }

                        # Find this user's mod record so we know whether to render the Moderator tab
                        #my @this_user_mod = map { $_->{meritcommons_user}->{id} == $user->id ? $_ : ()} @$mods;
                        #$self->stash(this_user_mod => $this_user_mod[0]);
                        $self->stash(this_user_mod => $mod);

                        $self->render(template => "stream/moderate");
                    } else {
                        $self->reply->not_found;
                    }
                } else {
                    $self->reply->not_found;
                }
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

sub update_profile_picture {
    my ($self) = @_;

    my $stream = $self->stream($self->stash('stream_identifier'));

    if ($stream && $self->active_user->can_moderate($stream)) {
        $stream->profile_picture($self->param('profile_picture'));
        $stream->update();
    }

    $self->redirect_to('/s/' . ($stream->url_name // $stream->unique_id) . '/m');
}

1;
