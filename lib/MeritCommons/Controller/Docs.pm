#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Docs;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Mojo::File;
use Text::Markdown qw/markdown/;

#
# MeritCommons's Markdown-based Documentation System
#
sub default {
    my ($self) = @_;
    my $path   = $self->stash("path");

    # redirect to trailing slash url.
    if ($path !~ /\/$/) {
        $self->redirect_to($self->req->url->to_abs . "/");
        return;
    }

    if ($ENV{MERITCOMMONS_DEBUG}) {
        print "Markdown Library:\n";
        print $self->dumper($self->markdown_files);
    }

    if ($path =~ /^\/*$/) {
        $path = "/default/";
    } 

    # concat it all together.  2 ways it works, 2 ways we concat.
    my $md_file = $self->markdown_files->{$path} if exists $self->markdown_files->{$path};

    if ($md_file && -e $md_file) {
        $self->stash('document', markdown(Mojo::File->new($md_file)->slurp));
        $self->render('general/document');
    } else {
        $self->reply->not_found;
    }
}

1;
