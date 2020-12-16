#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Settings;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

#
# the default handler method! :)
#
sub session_variable {
    my ($self) = @_;
    if (my $session = $self->meritcommons_session) {
        my @params = @{ $self->req->params->names };

        my ($set_options, @supported_features);
        foreach my $k (@params) {
            next if $k eq "back";
            next if $k eq "k";
            next if $k =~ /^_/ && $k ne "__clear__";
            $session->$k(@{ $self->every_param($k) });

            $set_options += scalar @{ $self->every_param($k) };

            if ($k =~ /_supported$/) {

                # if this is something designating feature support, let's keep track of it
                if ($self->param($k) == 1) {
                    push(@supported_features, $k);
                }
            }
        }
        if ($set_options) {

            # keep track of the supported features in a cookie...
            $self->signed_cookie(
                supported_features => join(':', @supported_features),
                {
                    expires => time + 86400 * 7,                 # supported features cookies last a week
                    domain  => $self->config->{cookie_domain},
                }
            );

            # we wrote something so we're done, session_variable is read only or write only per request
            if (my $back = $self->param('back')) {
                $self->redirect_to($back);
            } else {
                $self->render(text => "set $set_options options");
            }
        } elsif (my @k = @{ $self->every_param('k') }) {

            # this is a read request, get the values of what was specified by 'k'
            my @values;
            foreach my $k (@k) {
                foreach my $v (@{$session->$k}) {
                    push(@values, "$k => $v");
                }
            }
            if (my $back = $self->param('back')) {
                $self->redirect_to($back);
            } else {
                $self->render(text => join("\n", @values));
            }
        } else {
            $self->render(text => "riiight...");
        }
    } else {
        $self->render(text => "hmm...");
    }
}

sub user_config {
    my ($self) = @_;
    if (my $user = $self->active_user) {
        my $journal;
        my @params = @{ $self->req->params->names };
        foreach my $k (@params) {
            next if $k eq "back";
            next if $k eq "k";
            next if $k =~ /^_/ && $k ne "__clear__";
            $user->config($k, @{ $self->every_param($k) });
            $journal->{$k} = [ $user->config($k) ];
        }

        if (scalar(keys %$journal)) {
            if (my $back = $self->param('back')) {
                $self->redirect_to($back);
            } else {
                $self->render(text => $self->json_encode($journal));
            }
        } elsif (my @k = @{ $self->every_param('k') }) {
            foreach my $k (@k) {
                $journal->{$k} = [ $user->config($k) ];
            }
            $self->render(text => $self->json_encode($journal));
        } else {
            $self->render(text => $self->json_encode($user->config));
        }
    } else {
        $self->render(text => "hmm...");
    }
}

sub user_settings {
    my ($self) = @_;
    $self->stash(alt_title_link => { href => "/user_settings", title => "Settings" });
    $self->render('user_settings/default');
}

1;
