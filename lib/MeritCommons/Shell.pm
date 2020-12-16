package MeritCommons::Shell;

use Term::ANSIColor;
use Mojo::Loader qw/find_modules/;
use MeritCommons::Shell::Command;
use Term::ReadLine;
use base qw(Class::Accessor);

our @base_commands = (qw/version ls quit exit help cd cf focus/);
our @known_commands;

__PACKAGE__->mk_accessors(qw/app depth prompt term/);

sub new {
    my ($class, %args) = @_;
    $args{term} = Term::ReadLine->new(join('.', $args{prompt}, @{ $args{depth} }));

    my $self = bless \%args, $class;

    $self->refresh_known_commands;

    my $attr = $args{term}->Attribs;
    $attr->{basic_word_break_characters}     = ".\t\n";
    $attr->{completer_word_break_characters} = "\t\n";
    $attr->{completion_function}             = sub {
        my ($text, $line, $start) = @_;
        $self->refresh_known_commands($text);
        return grep(/^$text/, @known_commands);
    };

    print <<"EOF";
MeritCommons $MeritCommons::VERSION ($MeritCommons::CODENAME) Command Shell
try 'ls' for a list of commands.

EOF
    return $self;
}

sub refresh_known_commands {
    my ($self, $text) = @_;

    my @new_known_commands;

    if (!scalar(@{ $self->{depth} }) && $text =~ /^\w*$/) {

        # load the root level commands.
        @known_commands = (@base_commands);
        my $namespace = "MeritCommons::Command";
        foreach my $module (find_modules($namespace)) {
            $module =~ s/^${namespace}:://;
            next if $module eq "shell";
            next if $module eq "devdaemon";
            push(@known_commands, $module);
        }
    } else {
        if ($text =~ /^(focus|cd|cf)\s+$/) {
            my $cd = $1;
            foreach my $command (@known_commands) {
                unless ($command =~ /^$cd\s+/) {
                    push(@new_known_commands, "$cd $command");
                }
            }
            @known_commands = @new_known_commands if scalar(@new_known_commands);
        } else {

            # get a new command.
            my $command = MeritCommons::Shell::Command->new(
                text             => $text,
                depth            => [ @{ $self->{depth} } ],    # copy this, I think it might be clobbering.
                app              => $self->{app},
                for_autocomplete => 1,
            );

            if ($command) {
                if (my @subcommands = $command->subcommands) {

                    # only clobber the commands we have if there are subcommands.
                    foreach my $subcommand (@subcommands) {
                        push(@new_known_commands, $command->full_text . $subcommand);
                    }
                    @known_commands = @new_known_commands;
                }
            }
        }
    }
}

sub run {
    my ($self, @commands) = @_;

    my $text;
    while (defined($text = shift @commands || $self->term->readline($self->full_prompt))) {
        if (defined($text)) {
            next if $text eq '';
            $text =~ s/\s+$//g;

            my $OUT = $self->term->OUT || \*STDOUT;
            if ($text eq "help" || $text eq "?") {
                print $OUT "Try 'ls' for a list of commands\n";
            } elsif ($text eq "version") {
                print $OUT colored ["bold white"],
                  "MeritCommons Version $MeritCommons::VERSION ($MeritCommons::CODENAME) Command Shell\n";
            } elsif ($text =~ /^(?:focus|cd|cf) ([\w]+|\.\.)/) {
                my $target = $1;
                if ($target eq "..") {
                    pop(@{ $self->{depth} });
                } else {
                    push(@{ $self->{depth} }, $1);
                    $self->refresh_known_commands();
                }

                next;

            } elsif ($text eq "ls") {
                foreach my $command_name (sort { $a cmp $b } @known_commands) {
                    print $OUT "$command_name\n";
                }
            } elsif ($text eq "quit" || $text eq "exit") {
                last;
            } else {
                my $command = MeritCommons::Shell::Command->new(
                    text  => $text,
                    depth => [ @{ $self->{depth} } ],
                    app   => $self->{app},
                );

                if ($command) {
                    $command->execute($OUT);
                } else {
                    print $OUT colored ["bold red"], "$text: Bad command or file name\n";
                }
            }
            $self->term->addhistory($text) if $text =~ /\S/;
        } else {
            last;
        }
    }
}

sub full_prompt {
    my ($self) = @_;
    return join('.', $self->{prompt}, @{ $self->{depth} }) . "> ";
}

1;
