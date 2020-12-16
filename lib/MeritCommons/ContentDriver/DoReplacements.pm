#    This file is part of MeritCommons.
#
#    MeritCommons is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    MeritCommons is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with MeritCommons.  If not, see http://www.gnu.org/licenses/.
#
#    MeritCommons
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::ContentDriver::DoReplacements;

=head1 NAME

MeritCommons::ContentDriver::DoReplacements - A special ContentDriver
that "finishes up" after the rest.

=head1 SYNOPSIS

=head2 METHODS

=over 4

=item * should_handle

=item * priority

=item * inbound

=item * outbound

=back 

=head1 DESCRIPTION

MeritCommons::ContentDriver::DoReplacements is a special ContentDriver
that "finishes up" after the rest, actually making all the replacements
that the other ones may have set up.

Other content drivers will generally find their keywords and replace
them with a keyword (e.g. C<[link]http://google.com[/link]> might be
replaced with LINK1). Then, it stores the keyword and what to eventually
replace it with in a hash with elements "from" (containing the keyword)
and "to" (containing the text to eventually replace the keyword with).
This is pushed onto an array in the message in C<$content->{replacements}>.

MeritCommons::ContentDriver::DoReplacements then runs at the very end of
the Content Driver chain, and actually does all of these replacements in 
the resulting message body, looping over C<$content->{replacements}>
and simply seaching for whatever is in "from", and replacing it with
whatever is in "to". 

It sounds a little overly complex, but doing it this way rather than
having individual Content Drivers do the replacements immediately 
themselves helps prevent conflicts between them when one possible matching
bit of text is inside of another, provided their priority is set correctly.

=cut

=head1 FUNCTIONS

=cut

use Text::Markdown 'markdown';

use Mojo::Base 'MeritCommons::ContentDriver';
use MeritCommons::ContentDriver;

has priorities => sub {
    { all => LAST, };
};

has handles => sub {
    {
        inbound  => ['all'],
        outbound => ['all'],
    };
};

=head2 C<inbound>

  inbound($controller, $content, $actor);

This is where the actual replacements happen, simply looping over
C<$content-E<gt>{replacements}> and replacing any occurances of "to"
with the text in "from".

=cut

sub inbound {
    my ($self, $controller, $content, $actor) = @_;
    my $body = $content->body;

    foreach my $r (@{ $content->{replacements} }) {
        my $from = $r->{'from'};
        my $to   = $r->{'to'};
        $body =~ s/$from/$to/;
    }

    $content->body($body);
    return $content;
}

=head2 C<outbound>

  outbound($controller, $content, $actor);

This is just the usual standard outbound.

=cut

sub outbound {
    my ($self, $controller, $content, $actor) = @_;
    return $content;
}

1;
