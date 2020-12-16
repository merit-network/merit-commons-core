#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::ExternalLinks;

=head1 NAME

    MeritCommons::ContentDriver::ExternalLinks - A ContentDriver for handling
    external links in messages

=head1 DESCRIPTION

    A ContentDriver for handling external links in messages by turning them
    into anchor tags so they can be clicked.

=head1 FUNCTIONS

=cut

use URI::Find;
use URI::Find::Schemeless;

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

has priorities => sub {
    {
        generic => LATE,
        youtube => LATE,
        vimeo   => LATE,
        twitter => LATE,
        latex   => LATE,
    };
};

has handles => sub {
    {
        inbound  => ['all'],
        outbound => ['all'],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

Calls C<_replace_urls> on the content body, which actually does the work
in this content driver.

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;

    $content->body(_replace_urls($controller, $content->body, $actor, $content));
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

Just returns $content unchanged.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;
    return $content;
}

=head2 C<_replace_urls>

  _replace_urls($body, $actor, $content);

Does the actual work normally done in C<inbound>. Find URLs, and replace them with
links to that URL (using C<MeritCommons::ContentDriver::DoReplacements>)

=cut

sub _replace_urls {
    my ($self, $body, $actor, $content) = @_;

    my $new_body = $body;
    my @urls;
    my @mkdwn;
    my $mkdwncount = 0;

    my @replacements = ref($content->{replacements}) eq "ARRAY" ? @{ $content->{replacements} } : ();

    # Find markdown, and replace them so the
    # link stuff doesn't interfere with them
    while ($body =~ /!?(\[.*?\]\([^\)]+\)|\[[^\]]+\]\: *\<*[^\s\>]+\>*|\[[^\]]+\]\[[^\]]+\])/g) {
        my $found_mkdwn = $&;
        push(@mkdwn, $found_mkdwn);
        $new_body =~ s|\Q$found_mkdwn\E|\{\{REPLACEMARKDOWN$mkdwncount\}\}|;
        $body =~ s|\Q$found_mkdwn\E|\{\{REPLACEMARKDOWN$mkdwncount\}\}|;
        $mkdwncount++;
    }

    my $uri_finder = URI::Find->new(
        sub {
            my ($uri, $orig_uri) = @_;

            $uri =~ s/\)\?$//g;
            $orig_uri =~ s/\)\?$//g;

            my $link = $self->app->link($uri);

            my $sub_uri = $orig_uri;
            if (length($orig_uri) >= 30) {
                $sub_uri = substr($orig_uri, 0, 30) . "...";
            }

            # add a link unless we found it already!
            unless ($link) {
                $link = $self->app->add_link($actor, $uri, $sub_uri, undef, undef, 'user');
            }

            my $short_href = $self->app->short_url($self, $link);
            my $link_title = "A link to " . $orig_uri;

            if ($body !~ /\s+"$orig_uri/) {

                # deferred replacement
                my $placeholder = 'REPLACEMENT' . $content->{'replacement_count'}++;
                push(
                    @replacements,
                    {
                        from => $placeholder,
                        to   => qq|<a href="$short_href" target="_blank" title="$link_title">$sub_uri</a>|
                    }
                );
                $new_body =~ s|\Q$orig_uri\E|$placeholder|;
            }
        }
    );

    $uri_finder->find(\$body);
    undef $uri_finder;

    # now do this for schemeless.
    $uri_finder = URI::Find::Schemeless->new(
        sub {
            my ($uri, $orig_uri) = @_;

            $uri =~ s/\)\?$//g;
            $orig_uri =~ s/\)\?$//g;

            # don't get ones we got on the first pass!
            if ($uri_finder->is_schemed($orig_uri)) {
                return;
            }

            # .js isn't a domain...
            if ($uri =~ /\.js\/$/) {
                return;
            }

            my $link = $self->app->link($uri);

            my $sub_uri = $orig_uri;
            if (length($orig_uri) >= 30) {
                $sub_uri = substr($orig_uri, 0, 30) . "...";
            }

            # add a link unless we found it already!
            unless ($link) {
                $link = $self->app->add_link($actor, $uri, $sub_uri, undef, undef, 'user');
            }
            my $short_href = $self->app->short_url($self, $link);
            my $link_title = "A link to " . $orig_uri;

            my $placeholder = 'REPLACEMENT' . $content->{'replacement_count'}++;
            push(
                @replacements,
                {
                    from => $placeholder,
                    to   => qq|<a href="$short_href" target="_blank" title="$link_title">$sub_uri</a>|
                }
            );
            $new_body =~ s|\Q$orig_uri\E|$placeholder|;
        }
    );

    $uri_finder->find(\$body);
    undef $uri_finder;

    # put the markdown back where we found it.
    $mkdwncount = 0;
    foreach my $mkdwn (@mkdwn) {
        $new_body =~ s/\{\{REPLACEMARKDOWN$mkdwncount\}\}/$mkdwn/g;
        $mkdwncount++;
    }

    # don't forget to put the replacements back for DoReplacements
    $content->{replacements} = \@replacements;

    return $new_body;
}

1;
