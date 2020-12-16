#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::critic;

use Mojo::Base 'Mojolicious::Command';

has description => "Criticize MeritCommons's Perl Codebase Mercilessly\n";
has usage       => "Usage: $0 critic [PERL FILE] [PERL FILE..N]\n";

use File::Finder;
use Perl::Critic;
use Term::ANSIColor;

sub run {
    my ($self, @files) = @_;

    # set the perl critic config environment variable to configure perl critic
    $ENV{PERLCRITIC} = $ENV{MERITCOMMONS_HOME} . "/etc/perlcritic.conf";

    unless (@files) {
        @files = File::Finder->name("*.pm")->in($ENV{MERITCOMMONS_HOME} . "/lib");
    }

    my $critic = Perl::Critic->new();
    foreach my $file (@files) {
        print "[", color('cyan'), "checking $file", color('reset'), "]\n";
        foreach my $violation ($critic->critique($file)) {
            if ($violation->severity == 5) {
                print color 'bright_red';
            } elsif ($violation->severity == 4) {
                print color 'bright_yellow';
            } else {
                print color 'white';
            }
            print $violation;
            print color 'reset';
        }
        print "[", color('cyan'), "done checking $file", color('reset'), "]\n\n";
    }
}

1;
