package MeritCommons::Shell::Command;

use base qw/Class::Accessor/;

__PACKAGE__->mk_accessors(qw/depth text cmd args name full_text/);

sub new {
    my ($class, %args) = @_;

    my $self = bless \%args, $class;

    my @split_text = split(/\s+/, $self->{text});

    # don't worry about the last argument if we're for autocomplete.
    if ($self->{for_autocomplete} && $self->{text} !~ /\s$/) {
        pop(@split_text);
    }

    my ($name_from_depth, $name_from_text);
    if ($name_from_depth = shift(@{ $self->{depth} })) {
        $self->{full_text} = join(' ', @split_text);
        if ($self->{full_text}) {
            $self->{full_text} .= " ";
        }
    } else {
        $self->{full_text} = join(' ', @split_text) . " ";
        $name_from_text = shift(@split_text);
    }

    my @cmd_args = (@{ $self->{depth} }, @split_text);

    # get the module name first.
    my $name = $name_from_depth || $name_from_text;

    foreach my $namespace (@{ $args{app}->commands->namespaces }) {
        my $module .= $namespace . "::" . $name;
        $self->{name} = $name;
        $self->{args} = [@cmd_args];

        eval "use $module;";
        if (!$@) {
            eval { $self->{cmd} = $module->new(app => $args{app}); };
            last;
        }
    }

    if ($self->{cmd}) {
        return $self;
    } else {
        return undef;
    }
}

sub subcommands {
    my ($self) = @_;

    # make sure we stay on the right level if we're in the middle of a command.
    my $level = scalar(@{ $self->{args} });

    #warn "Level is $level\n";

    # default to command level 0.
    if ($self->cmd->can('subcommands')) {
        return (@{ $self->cmd->subcommands->[$level] });
    } else {
        return ();
    }
}

sub execute {
    my ($self, $OUT) = @_;

    # save what was stdout until we're done.
    my $old_stdout;
    open($old_stdout, '>&', STDOUT);
    close(STDOUT);
    open(STDOUT, '>&', $OUT);

    # let's also hack together ARGV in case someone's using that or GetOptions instead...
    my @old_argv = @ARGV;
    @ARGV = ("meritcommons", $self->name);

    my $args = join(' ', @{ $self->args });
    while ($args =~ /([\-\w]+|\"([^"]+)\")/g) {
        if (defined($2)) {
            push(@ARGV, $2);
        } else {
            push(@ARGV, $1);
        }
    }

    # this command should write to STDOUT, which is now $OUT.
    $self->cmd->run(@ARGV[ 2 .. $#ARGV ]);

    # put ARGV back
    @ARGV = @old_argv;

    # yay we're done let's put it back.
    close(STDOUT);
    open(STDOUT, '>&', $old_stdout);
    close($old_stdout);
}

1;
