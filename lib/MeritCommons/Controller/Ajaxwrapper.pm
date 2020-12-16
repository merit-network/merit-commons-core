#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Ajaxwrapper;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';

# we're also an MeritCommons::Controller
use base qw/MeritCommons::Controller/;

use Carp qw/croak/;

sub flickr_photostream {
    my ($self) = @_;

    my $url =
      "https://secure.flickr.com/services/feeds/photos_public.gne?id=" .
      $self->stash('fid') . "&lang=en-us&format=json&nojsoncallback=1";

    my $ua = Mojo::UserAgent->new;
    my $resp = $ua->get($url => { DNT => 1 })->res->body;

    # I don't know wtf these parts are in there, they make the JSON invalid.
    $resp =~ s|"description".+?,\n||g;

    $self->render(data => $resp);
}

sub wikipedia_userinfo {
    my ($self) = @_;

    my $url =
      "https://en.wikipedia.org/w/api.php?action=query&list=users&ususers=" .
      $self->stash('uid') . "&usprop=editcount|registration&format=json";
    my $ua = Mojo::UserAgent->new;
    my $resp = $ua->get($url => { DNT => 1 })->res->body;

    $self->render(data => $resp);
}

sub github_userinfo {
    my ($self) = @_;

    my $url  = "https://api.github.com/users/" . $self->stash('uid');
    my $ua   = Mojo::UserAgent->new;
    my $resp = $ua->get($url => { DNT => 1 })->res->body;

    $self->render(data => $resp);
}

sub reddit_userinfo {
    my ($self) = @_;

    my $url = "http://www.reddit.com/user/" . $self->stash('uid') . "/about.json";

    my $ua = Mojo::UserAgent->new;
    my $resp = $ua->get($url => { DNT => 1 })->res->body;

    $self->render(data => $resp);
}

1;
