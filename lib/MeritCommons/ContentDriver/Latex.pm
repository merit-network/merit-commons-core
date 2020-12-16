#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::Latex;

=head1 NAME

    MeritCommons::ContentDriver::Latex - A ContentDriver for handling LaTeX.

=head1 DESCRIPTION

    An MeritCommons ContentDriver for handling LaTeX markup in messages,
    especially for math (though other uses aren't filtered out).

=head1 FUNCTIONS

=cut

# <ColonelPanic001> I don't make bugs, I write butterflies

use Mojo::Util qw(sha1_sum html_unescape);
use File::Path qw(remove_tree);

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

# define the stage of execution this content driver is invoked in for various
# message types
has priorities => sub {
    {
        generic => FIRST,
        latex   => FIRST,
    };
};

# define the action => [typelist] that this content driver handles
has handles => sub {
    {
        inbound      => [qw/generic latex/],
        outbound     => [qw/latex/],
        notification => [qw/latex/],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

This content driver is a little more complicated than some others. We only really
use LaTeX for math and chemical diagram rendering, so it looks for any text surrounded
by [math][/math] or [chem][/chem] tags. Whatever is inside gets run through the 
latex binary, the output of which is stored in a .png file with the name being
a sha1 hash of the text used to render it (duplicate text will just use the existing
image then, rather than bothering to render it again).

The image to appear in the message also has associated with it a modal <div> that can show
up to show the source text and other things, and that's included as well.

The whole thing is then registered as a replacement to then be handled by
C<MeritCommons::ContentDriver::DoReplacements>

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    my $body   = $content->body;
    my $config = $controller->app->config;
    $self->check_config($config) or return $content;

    # For now, just use double $, for easier and more reliable detection.
    # Maybe we can improve this later.
    my $count        = 0;
    my $body_orig    = $body;
    my @replacements = ref($content->{replacements}) eq "ARRAY" ? @{ $content->{replacements} } : ();

    while ($body =~ /\[(math|chem)\s?(right|left|block)?\](.+?)\[\/\1\]/gmi) {
        unless ($content->{render_as} eq "latex") {
            $content->{render_as} = "latex";
            return $controller->cd_inbound($content, $actor);
        }

        my $ltype       = $1;
        my $styles      = $2;
        my $latex       = $3;
        my $full_latex  = $&;
        my $checksum    = sha1_sum $latex;
        my $tmpdir      = $config->{latex}->{tmpdir} . "/" . $checksum . "/";
        my $imgurlpath  = $config->{latex}->{imgurlpath} . "/" . $checksum . ".png";
        my $imgout      = $config->{latex}->{imgoutdir} . "/" . $checksum . ".png";
        my $invalid_png = $config->{latex}->{imgoutdir} . "/invalidlatex.png";

        # If the image doesn't exist, create it. If it does, just use it
        my $gen_resp = undef;
        if (!-e $imgout) {
            if (!$self->generate_image($latex, $ltype, $tmpdir, $checksum, $imgout, $invalid_png)) {
                $imgurlpath = $controller->asset_url('mathimg/invalidlatex.png');
            }
        }

        # handle styles, if they're there. Very crude at the moment,
        # but it offers a little control. Probably worth refinding later.
        my $imgstyles = '';
        $imgstyles = 'style="float: left; margin: 1em"'                if ($styles =~ m/left/);
        $imgstyles = 'style="float: right; margin: 1em"'               if ($styles =~ m/right/);
        $imgstyles = 'style="margin: 1em; clear: both; display:block"' if ($styles =~ m/block/);

        # this needs to have quotes escaped.
        my $alt_latex = $full_latex;
        $alt_latex =~ s/"/&quot;/g;

        my $embed_string =
          qq|<a href="#latex-$checksum" data-toggle="modal" data-keyboard="true" $imgstyles><img src="$imgurlpath" alt="$alt_latex" title="$alt_latex\n\n(click for source)" class="rendered-math" /></a>
              <div class="modal fade" id="latex-$checksum">
                <div class="modal-dialog">
                  <div class="modal-content">
                    <div class="modal-header">
                      <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
                      <a class="close" style="text-decoration: none; margin-right: 0.5em" target="_blank" href="https://en.wikibooks.org/wiki/LaTeX/Mathematics">?</a>
                      <h4 class="modal-title"><img src="|
          . $controller->asset_url('img/latex_logo.png') . qq|" alt="LaTeX" /> Source</h4>
                    </div>
                    <div class="modal-body">
                      <center><img src="$imgurlpath" alt="$alt_latex" title="$alt_latex" class="rendered-latex" /></center>
                        <br />
                        <pre style="overflow: auto; height: 5em;">$full_latex</pre>
                    </div>
                    <div class="modal-footer">
                      <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                    </div>
                  </div><!-- /.modal-content -->
                </div><!-- /.modal-dialog -->
              </div><!-- /.modal -->|;
        my $placeholder = 'REPLACEMENT' . $content->{'replacement_count'}++;
        push @replacements, { 'from' => $placeholder, 'to' => $embed_string };
        $body_orig =~ s/\Q$full_latex/$placeholder/;
    }

    $content->{replacements} = \@replacements;
    $content->body($body_orig);
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This is just the usual standard outbound.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;

    my $config = $controller->app->config;
    $self->check_config($config) or return $content;

    if ($content->{render_as} eq "latex") {

        # set the basic attributes...
        $content = $controller->add_outbound_attributes($content, $actor);

        # this isn't done until here in case you needed the object of the submitter for something
        $content->{submitter} = $content->submitter->unique_id;
    }

    return $content;
}

=head2 C<generate_image>

  generate_image($latex, $ltype, $tmpdir, $checksum, $imgout);

This is used by C<inbound> to handle actually creating the image of
the LaTeX output.

=cut

sub generate_image {
    my ($self, $latex, $ltype, $tmpdir, $checksum, $imgout, $invalid_png) = @_;

    $latex = html_unescape($latex);

    # If it's math, put it in a math environment.
    if ($ltype eq 'math') {
        $latex = '$' . $latex . '$';
    }

    # Get list of packages
    my @pkgs        = $self->get_packages($ltype);
    my $packagelist = '';
    foreach my $p (@pkgs) {
        $packagelist .= '\usepackage{' . $p . "}\n";
    }

    my $doc = '\documentclass[12pt]{article}
        \pagestyle{empty}
        \usepackage[utf8]{inputenc}
        ' . $packagelist . '
        \begin{document}
        \begin{samepage}
        \Large
        ' . $latex . '
        \end{samepage}
        \end{document}
        ';

    mkdir($tmpdir);
    open FILE, ">", $tmpdir . "/" . $checksum . '.tex' or die $!;
    print FILE $doc;
    close FILE;

    my $timeout = `which timeout` || `which gtimeout`;
    chomp($timeout);

    # we're not gonna let this thing run wild, no timeout on this system == invalid LaTeX.
    if ($timeout) {

        # if you build it, they will... math? (you have 3 seconds to comply)
        system(
            "$timeout -s 9 3 pdflatex -halt-on-error -no-shell-escape -output-directory=\"$tmpdir\" \"$tmpdir/$checksum.tex\" >/dev/null"
        );
    }

    if (-e $tmpdir . "/" . $checksum . ".pdf") {
        system("convert -trim $tmpdir/$checksum.pdf $imgout >/dev/null");
    } else {

        # make this permanent
        system("ln -s $invalid_png $imgout");
        remove_tree($tmpdir);
        return undef;
    }

    # we're done, remove all the files used during building
    #remove_tree($tmpdir);
    return 1;
}

=head2 C<get_packages>

  get_packages($ltype);

For a given type of rendering to be done (math or chem), return a list
of packages to include in the LaTeX doc. No need to load chemfig if they're
doing the quadratic formula, for example.

=cut

sub get_packages {
    my ($self, $ltype) = @_;

    my $pkg = {
        'math' => ('lmodern', 'amssymb', 'mathtools'),
        'chem' => ('chemfig'),
    };
    return $pkg->{$ltype};
}

=head2 C<check_config>

  check_config($config);

Check to make sure the required configuration items have some value. The
required settings are :

=over 4

=item * C<$config->{latex}->{tmpdir}>

=item * C<$config->{latex}->{imgoutdir}>

=item * C<$config->{latex}->{imgurlpath}>

=back 

Returns 1 if all required settings are present, undef if not.

=cut

sub check_config {
    my ($self, $config) = @_;

    my $missing = 0;
    if (!$config->{latex}->{tmpdir}) {
        warn "[warn] latex->tmpdir value not set in meritcommons.conf (see meritcommons.conf.sample)";
        $missing++;
    }
    if (!$config->{latex}->{imgoutdir}) {
        warn "[warn] latex->imgoutdir value not set in meritcommons.conf (see meritcommons.conf.sample)";
        $missing++;
    }
    if (!$config->{latex}->{imgurlpath}) {
        warn "[warn] latex->imgurlpath value not set in meritcommons.conf (see meritcommons.conf.sample)";
        $missing++;
    }

    return undef if ($missing > 0);
    return 1;
}

=head2 C<notification>

  notification($controller, $content, $actor, $notifier);

Sets notification text customized to be specific to LaTeX posts.

=cut

sub notification {
    my ($self, $controller, $content, $actor, $notifier) = @_;

    if ($content->about->render_as eq "latex") {

        # if this is a thread...
        if ($notifier->thread) {
            if ($notifier->is_originator($content->recipient)) {

                # NOTIFICATION WHERE RECIPIENT IS THE ORIGINATOR OF THE THREAD
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " replied to your LaTeX expression '" .
                  $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
                  "' with '" . $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

            } else {

                # NOTIFICATION WHERE RECIPIENT IS A PARTICIPANT IN THE THREAD
                $content->{body} =
                  $notifier->activity_participant_summary($content, $content->actor) .
                  " also commented on " . $notifier->user_as_href($content->thread->submitter) .
                  "'s LaTeX expression '" . $controller->truncate_htmlstrip($content->thread->original_body, 32, 1) .
                  "' saying '" . $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";
            }
        } else {
            if ($content->subtype eq "comment") {

                # NOTIFICATION WHERE RECIPIENT IS MENTIONED IN THE TRIGGERING MESSAGE
                $content->{body} =
                  $notifier->user_as_href($content->actor) . " mentioned you in a LaTeX expression '" .
                  $controller->truncate_htmlstrip($content->about->original_body, 80, 1) . "'";
            } elsif ($content->subtype eq "like" || $content->subtype eq "dislike") {
                my $whose_message =
                  $content->recipient->unique_id eq $content->about->submitter->unique_id
                  ? "your"
                  : $notifier->user_as_href($content->about->submitter) . "'s";
                if (scalar($content->about->like_participants) xor scalar($content->about->dislike_participants)) {

                    # NOTIFICATION IS ABOUT A LIKE-DISLIKE ACTION ON A MESSAGE WHICH HAS NO OPPOSITE ACTIONS
                    $content->{body} =
                      $notifier->activity_participant_summary($content) .
                      " " . $content->subtype . "d $whose_message LaTeX expression '" .
                      $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";
                } else {

                    # NOTIFICATION IS ABOUT A LIKE-DISLIKE ACTION ON A MESSAGE WHICH DOES HAVE OPPOSITE ACTIONS
                    my $action_icon =
                      $content->subtype eq "like"
                      ? "<i class='icon-thumbs-up'></i>"
                      : "<i class='icon-thumbs-down'></i>";
                    $content->{body} =
                      $notifier->activity_participant_summary($content, $content->actor) .
                      " " . $content->subtype . "d $action_icon and ";

                    # toggle these and get the opposite.
                    $content->{subtype} = $content->{subtype} eq "like" ? "dislike" : "like";
                    $action_icon =
                      $content->subtype eq "like"
                      ? "<i class='icon-thumbs-up'></i>"
                      : "<i class='icon-thumbs-down'></i>";

                    $content->{body} .=
                      $notifier->activity_participant_summary($content) .
                      " " . $content->subtype . "d $action_icon $whose_message LaTeX expression '" .
                      $controller->truncate_htmlstrip($content->about->original_body, 32, 1) . "'";

                    # toggle it back.
                    $content->{subtype} = $content->{subtype} eq "like" ? "dislike" : "like";
                }
            }
        }
    }

    return $content;
}

1;
