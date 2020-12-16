#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::RecipientExtractor;

=head1 NAME

    MeritCommons::ContentDriver::RecipientExtractor - A ContentDriver for handling named recipients of messages

=head1 DESCRIPTION

    A ContentDriver for handling named recipients of messages

=head1 FUNCTIONS

=cut

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

# define the stage of execution this content driver is invoked in for various
# message types
has priorities => sub {
    {
        generic => EARLY,
        youtube => EARLY,
        vimeo   => EARLY,
    };
};

# define the action => [typelist] that this content driver handles
has handles => sub {
    {
        inbound  => ['all'],
        outbound => ['all'],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

Finds recipients (accounting for aliases, creating them if appropriate), link-ifies them,
and adds the message to the recipient's personal inbox.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;

    my @replacements = ref($content->{replacements}) eq "ARRAY" ? @{ $content->{replacements} } : ();

    # step 1: parse out the recipients
    my $recipients    = {};
    my $original_body = $content->original_body;
    while ($original_body =~ /(?:^|\W+)\@(([\w\-\']+\s[\w\-\']+\.*|[\w\-\']+)(\=*)(\w*))/g) {
        if ($3 && $4) {
            $recipients->{ lc($4) }->{assigned_alias} = $2;
            push(@{ $recipients->{$4}->{string} }, $1);
        } else {
            push(@{ $recipients->{$2}->{string} }, $1);
        }
    }

    # step 2: create + resolve aliases.
    foreach my $recipient (keys %$recipients) {
        my ($targeted_user, $alias);
        my @recip_words = split(/\s/, $recipient);
        if ($targeted_user =
            $controller->app->m->resultset('User')->search({ 'LOWER(userid)' => lc($recipient) }, { rows => 1 })->first
            ||
            $controller->app->m->resultset('User')->search({ 'LOWER(common_name)' => lc($recipient) }, { rows => 1 })
            ->first) {

            # check if this is an assignment, it's a valid user.
        } elsif ($targeted_user =
            $controller->app->m->resultset('User')->search({ 'LOWER(userid)' => lc($recip_words[0]) }, { rows => 1 })
            ->first) {

            # move over our data
            $recipients->{ $recip_words[0] } = $recipients->{$recipient};
            delete $recipients->{$recipient};

            # change the recipient
            $recipient = $recip_words[0];
            $recipients->{$recipient}->{string} = [ map { $recip_words[0] } @{ $recipients->{$recipient}->{string} } ];
        } elsif ($alias =
            $actor->nicknames_for_others->search({ 'LOWER(common_name)' => lc($recipient) }, { rows => 1 })->first) {

            # this is a legit alias, resolve the targeted user!
            $targeted_user = $alias->meritcommons_user;

            # take note of the fact that this alias was used for future ranking!
            $alias->used($alias->used + 1);
            $alias->update();
        } elsif ($alias =
            $actor->nicknames_for_others->search({ 'LOWER(common_name)' => lc($recip_words[0]) }, { rows => 1 })->first)
        {

            # move over our data
            $recipients->{ $recip_words[0] } = $recipients->{$recipient};
            delete $recipients->{$recipient};

            # change the recipient
            $recipient = $recip_words[0];
            $recipients->{$recipient}->{string} = [ map { $recip_words[0] } @{ $recipients->{$recipient}->{string} } ];

            # this is a legit alias, resolve the targeted user!
            $targeted_user = $alias->meritcommons_user;

            # take note of the fact that this alias was used for future ranking!
            $alias->used($alias->used + 1);
            $alias->update();
        }

        if ($targeted_user) {
            warn "[info] Found targeted user for $recipient\n" if $ENV{MERITCOMMONS_DEBUG};
            if (my $alias_string = $recipients->{$recipient}->{assigned_alias}) {
                unless ($alias =
                    $actor->nicknames_for_others->search({ common_name => $alias_string }, { rows => 1 })->first) {

                    # this one doesn't exist yet, create it!
                    $alias = $actor->nicknames_for_others->create(
                        {
                            common_name    => $alias_string,
                            meritcommons_user => $targeted_user->id,
                            used           => 1,
                        }
                    );
                }
            }

            # we now have $targeted_user and $alias, let's add the user's inbox to our destination streams!
            if ($targeted_user->personal_inbox) {
                my $already_specified;
                foreach my $stream (@{ $content->streams }, @{ $content->attempted_streams }) {
                    $already_specified = 1 if $stream->id == $targeted_user->personal_inbox->id;
                }
                unless ($already_specified) {
                    push(@{ $content->streams }, $targeted_user->personal_inbox); # personal_inbox is always a legal stream!
                }
            }

            # and let's replace the string with the link that makes sense.
            my $replace_text;
            my $placeholder = 'REPLACEMENT' . $content->{'replacement_count'}++;
            if ($alias) {
                $replace_text =
                  '<a class="meritcommons-user-link" href="' . $controller->app->config->{front_door_url} .
                  '/u/' . $targeted_user->userid . '/">@' . $alias->common_name . '</a>';
            } else {
                $replace_text =
                  '<a class="meritcommons-user-link" href="' . $controller->app->config->{front_door_url} .
                  '/u/' . $targeted_user->userid . '/">@' . $targeted_user->common_name . '</a>';
            }

            my $body = $content->body;

            # using placeholders now...
            push(
                @replacements,
                {
                    from => $placeholder,
                    to   => $replace_text,
                }
            );

            foreach my $string (@{ $recipients->{$recipient}->{string} }) {
                warn "[info] Replacing $string with $placeholder\n" if $ENV{MERITCOMMONS_DEBUG};
                $body =~ s/\@$string/$placeholder/;
            }

            $content->body($body);

            # don't forget to put the replacements back for DoReplacements
            $content->{replacements} = \@replacements;
        } else {
            warn "[info] Couldn't find targeted user for $recipient\n" if $ENV{MERITCOMMONS_DEBUG};
        }
    }

    # add the sender's personal inbox if we didn't already.
    if (scalar(keys %$recipients)) {
        my $already_specified;
        foreach my $stream (@{ $content->streams }, @{ $content->attempted_streams }) {
            $already_specified = 1 if $stream->id == $actor->personal_inbox->id;
        }
        unless ($already_specified) {
            push(@{ $content->streams }, $actor->personal_inbox);    # personal_inbox is always a legal stream!
        }
    }

    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

Nothing special is needed here, so C<$content> is returned unchanged.

=cut

sub outbound {
    my ($self, $controller, $content) = @_;
    return $content;
}

1;
