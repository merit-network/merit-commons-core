#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::InternalLinks;

=head1 NAME

    MeritCommons::ContentDriver::InternalLinks - A ContentDriver to handle internal links
    to MeritCommons resources such as streams and hashtags.

=head1 DESCRIPTION

    A ContentDriver to handle internal links to MeritCommons resources such as streams and hashtags.

=head1 FUNCTIONS

=cut

use Text::Markdown 'markdown';
use Mojo::Util 'url_unescape';
use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

# define the stage of execution this content driver is invoked in for various
# message types
has priorities => sub {
    {
        generic => WHENEVER,
        youtube => WHENEVER,
        vimeo   => WHENEVER,
        latex   => WHENEVER,
    };
};

# define the action => [typelist] that this content driver handles
has handles => sub {
    {
        inbound  => ['all'],
        outbound => ['all'],
    };
};

sub setup {
    my ($self) = @_;
    if (exists $self->{app} && $self->{app}) {
        print "[debug]: registering " . __PACKAGE__ . " as a renderer source for templates!\n" if $ENV{MERITCOMMONS_DEBUG};
        push(@{$self->{app}->renderer->classes}, __PACKAGE__);
    }
}

=head2 C<inbound>

  inbound($controller, $content, $actor);

Finds text that appears to be the URL path to a stream or looks like a hashtag
(a # with at least chars after, proceeded by a space), and replaces it in place
(i.e. this I<does not> use MeritCommons::ContentDriver::DoReplacements )

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    
    my $body = $content->body;

    my $original_body = $body;
    # references to internal meritcommons resources
    
    ###########
    # Streams #
    ###########
    while ($original_body =~ m{(^|\W|sub:)/s/([A-Za-z0-9\-\_\%]+)/*}go) {
        my $entire_match = $&;
        my $pfx = $1;
        my $name = url_unescape($2);
        
        # find the stream....
        my $s = $controller->stream($name);
        if ($s) {
            # we'll do a stream replace...
            $controller->stash(stream => $s);

            if ($pfx eq "sub:") {
                my $replacement = $controller->render_to_string(template => 'embed_subscribe_to_stream', format => 'html');
                $body =~ s/$entire_match/$replacement/;
            } else {
                my $replacement = $controller->render_to_string(template => 'embed_stream_link', format => 'html');
                $body =~ s/$entire_match/$replacement/;
            }
        } else {
            $controller->app->log->warn("someone referenced a stream '$name' in a message, but we can't seem to look it up.");            
        }
    } 
    
    ##########
    # People #
    ##########
    while ($original_body =~ m{(^|\W|follow:)/u/([A-Za-z0-9\-\_\%]+)/*}go) {
        my $entire_match = $&;
        my $pfx = $1;
        my $name = url_unescape($2);
        
        # find the stream....
        my $user = $controller->user($name);
        if ($user) {
            # we'll do a user stream replace...
            $controller->stash(user => $user);

            if ($pfx eq "follow:") {
                my $replacement = $controller->render_to_string(template => 'embed_follow_user', format => 'html');
                $body =~ s/$entire_match/$replacement/;
            } else {
                my $replacement = $controller->render_to_string(template => 'embed_user_link', format => 'html');
                warn "Replacement text for $entire_match is $replacement .. $@\n";
                $body =~ s/$entire_match/$replacement/;
            }
        } else {
            $controller->app->log->warn("someone referenced a user '$name' in a message, but we can't seem to look it up.");            
        }
    }

    # Provide hashtag links for the twitter addicts (hashtags must be at least 2 characters in length and be preceeded by a space.)
    $body =~ s/(^|\W)\#([A-Za-z0-9-_]{3,})/$1 \#<a href="\/search\?query=\%23$2">$2<\/a>/go;

    $content->body($body);
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This C<outbound> does no work, and returns C<$content> unchanged.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;
    return $content;
}

1;

__DATA__

@@ embed_subscribe_to_stream.html.ep
<button class="btn btn-xs primary subscribe-embed" data-stream-id="<%= $stream->unique_id %>">
    <i class="fa fa-streams"></i> Subscribe to <% $stream->common_name %>
</button>

@@ embed_stream_link.html.ep
<a class="btn btn-xs primary" href="/s/<%= $stream->url_name %>/">
    <i class="fa fa-streams"></i> <% $stream->common_name %>
</a>

@@ embed_follow_user.html.ep
<button class="btn btn-xs primary subscribe-embed" data-user-id="<%= $user->unique_id %>">
    <i class="fa fa-user"></i> Follow <% $user->common_name %>
</button>

@@ embed_user_link.html.ep
<a class="btn btn-xs primary" href="/u/<%= $user->userid %>/">
    <i class="fa fa-user"></i> <% $user->common_name %>'s personal stream
</a>

@@ embed_simple_link.html.ep
<a href="<%= $path %>"><%= $title %></a>
