#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::tidy;

use Mojo::Base 'Mojolicious::Command';

has description => "Tidy Up MeritCommons's Perl Codebase\n";
has usage       => "Usage: $0 tidy [PERL FILE] [PERL FILE..N]\n";

use File::Finder;
use Perl::Tidy;
use Term::ANSIColor;

sub run {
    my ($self, @files) = @_;

    # clear ARGV so as to not confuse perltidy
    @ARGV = ();

    unless (@files) {
        @files = File::Finder->name("*.pm")->in($ENV{MERITCOMMONS_HOME} . "/lib");
    }

    foreach my $file (@files) {
        print "[", color('cyan'), "tidying $file", color('reset'), "]\n";
        Perl::Tidy::perltidy(
            source      => $file,
            destination => $file . ".tdy",
            perltidyrc  => $ENV{MERITCOMMONS_HOME} . "/etc/perltidy.conf",
        );
        system("mv $file.tdy $file");
    }
}

1;
