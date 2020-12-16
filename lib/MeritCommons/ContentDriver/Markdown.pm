#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::Markdown;

=head1 NAME

    MeritCommons::ContentDriver::Markdown - A ContentDriver for handling Markdown

=head1 DESCRIPTION

    A ContentDriver for handling Markdown. Some basic syntax docs can be find here: L<http://daringfireball.net/projects/markdown/syntax>.

=head1 FUNCTIONS

=cut

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

# define the stage of execution this content driver is invoked in for various
# message types
has priorities => sub {
    {
        generic => LATER,
        youtube => LATER,
        vimeo   => LATER,
        latex   => LATER,
    };
};

# define the action => [typelist] that this content driver handles
has handles => sub {
    {
        inbound  => ['all'],
        outbound => ['all'],
    };
};

use Text::Markdown 'markdown';

=head2 C<inbound>

  inbound($controller, $content, $actor);

This just runs the content body through the C<Text::Markdown> module.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;

    # Find markdown, and replace them so the
    # link stuff doesn't interfere with them
    my $body = my $newbody = $content->body;
    while ($body =~ /(?:\[.*?\]\(([^\)]+)\)|\[\d+\]\: ([^\s]+))/g) {
        my $url = Mojo::URL->new($1 || $2);

        if ($url->host && $url->scheme ne "https") {
            my $purl = $controller->proxy_href($url);
            $newbody =~ s/$url/$purl/g;
            last;
        }
    }

    my $markdown = markdown($newbody);

    if (my $error = $@) {
        $controller->app->log->error("markdown processing error $@");
    }

    $content->body($markdown) if $markdown;
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This does nothing special and just returns C<$content> unchanged.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;
    return $content;
}

1;
