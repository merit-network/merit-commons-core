#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::shell;

use MeritCommons::Shell;
use MeritCommons::Shell::Command;
use Mojo::Base 'Mojolicious::Command';
use File::Find;
use Mojo::File;

has description => "An Interactive MeritCommons Shell\n";
has usage       => "Usage: $0 shell [SCRIPT]\n";

sub run {
    my ($self, @args) = @_;

    my @commands;
    if ($args[0] && -e $args[0]) {
        my $script = Mojo::File->new($args[0])->slurp;
        foreach my $command (split(/\n/, $script)) {
            if ($command && $command !~ /^#/) {
                push(@commands, $command);
            }
        }
    }

    # also gather commands piped in..
    if (!-t STDIN) {
        while (my $command = <STDIN>) {
            $command =~ s/[\r\n]+$//g;
            push(@commands, $command);
        }
    }

    # add a quit if we have script input..
    if (scalar(@commands)) {
        push(@commands, 'quit');
    }

    my $shell = MeritCommons::Shell->new(
        prompt => "meritcommons",
        app    => $self->app,
    );

    $shell->run(@commands);
}

1;

