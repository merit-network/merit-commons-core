#    MeritCommons Portal
#    Copyright 2018 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::plugin_info;

use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use Mojo::Loader qw/load_class/;
use Mojo::Util qw/decamelize camelize dumper/;
use MeritCommons::Plugin;
use Term::ANSIColor;

has description => "Print out information about a plugin\n";
has usage       => "Usage: $0 [OPTIONS] [plugin_name]\n";

my $yes = "@{[color('bold green')]}Yes@{[color('reset')]}";
my $no = "@{[color('bold red')]}No@{[color('reset')]}";

sub run {
    my ($self, @args) = @_;
    
    unless (scalar(@args)) {
        print $self->help();
        exit;
    }
    
    my $input = pop(@args) if $args[$#args] !~ /^\s*\-/;
        
    GetOptionsFromArray(
        \@args,
        'v|verbose' => \my $verbose,
        'h|help' => \my $help,
    );
    
    unless ($input) {
        print $self->help();
        exit;
    }
    
    my $app = $self->app;

    my ($plugin_name, $plugin_class_name);
    if ($input =~ /::/) {
        $plugin_class_name = $input;
        # this is a fully qualified namespace... let's get a proper "plugin name" for it.
        $plugin_name = MeritCommons::Plugin::plugin_name(bless({}, $input));
    } else {
        $plugin_name = $input;
    }

    print "$plugin_name\n";

    my ($plugin, $enabled);
    eval {
        eval "\$plugin = \$app->$plugin_name->plugin";
        if ($plugin) {
            $enabled = $plugin_class_name = ref $plugin;
        }
    };
    
    unless ($plugin) {
        unless ($plugin_class_name) {
            # guess...
            $plugin_class_name = "MeritCommons::Plugin::" . camelize($input);
        }
        eval {
            $plugin = load_class $plugin_class_name;
        };
    }

    if ($plugin) {
        no strict 'refs';
        my $plugin_version        = ${"${plugin_class_name}::VERSION"} || "Unknown";
        my $plugin_schema_version = ${"${plugin_class_name}::SCHEMA_VERSION"};
        my @plugin_isa            = @{"${plugin_class_name}::ISA"};
        use strict 'refs';
        print "@{[color('bold white')]}Plugin Information For $plugin_class_name@{[color('reset')]}\n";
        print "@{[color('bold white')]}---------------------------------------------------------@{[color('reset')]}\n";
        printf("@{[color('bold white')]}%-32s: %s@{[color('reset')]}\n", "Version", $plugin_version);
        printf("@{[color('bold white')]}%-32s: %s@{[color('reset')]}\n", "Schema Version", $plugin_schema_version) if $plugin_schema_version;
        unless (scalar(grep {'MeritCommons::Plugin'} @plugin_isa)) {
            say "@{[color('bold red')]}WARNING: $plugin_class_name is not a subclass of " . 
                "@{[color('bold white')]}MeritCommons::Plugin@{[color('bold red')]} and should be used " . 
                "with caution!!@{[color('reset')]}";
        }
        
        print "\n";
        if ($plugin->can('description')) {
            say "@{[color('bold white')]}Description:@{[color('reset')]}";
            say $plugin->description;
        }
        print "\n";
        
        say "@{[color('bold white')]}Plugin Properties and Attributes@{[color('reset')]}";
        say "@{[color('bold white')]}--------------------------------@{[color('reset')]}";
        if ($plugin_schema_version) {
            printf("%-32s: %s\n", "Augments MeritCommons Schema", $yes);
        } else {
            printf("%-32s: %s\n", "Augments MeritCommons Schema", $no);
        }
        printf("%-32s: %s\n", "Currently Enabled", $enabled ? $yes : $no);
        printf("%-32s: %s\n", "Has Configuration File", scalar(keys %{$plugin->plugin_config}) ? $yes : $no);
        if ($verbose) {
            my $output = dumper($plugin->plugin_config);
            while (my $line = $output =~ /(^[^\r\n]+)$/g) {
                verbose_output($line);
            }
        }
        printf("%-32s: %s\n", "Has Custom Command(s)", 
            my $has_commands = scalar(grep {$plugin_class_name} @{$app->commands->namespaces}) ? $yes : $no);
        printf("%-32s: %s\n", "Has Helper Class(es)",
            my $has_helpers = scalar(grep {$plugin_class_name} @{$app->plugins->namespaces}) ? $yes : $no);
        printf("%-32s: %s\n", "Has Hydrant Command(s)",
            my $has_hydrant = scalar(grep {$plugin_class_name} @{$app->hydrant_namespaces}) ? $yes : $no);
        printf("%-32s: %s\n", "Has Content Driver(s)",
            my $has_cds = scalar(grep {$plugin_class_name} @{$app->contentdriver_namespaces}) ? $yes : $no);
        printf("%-32s: %s\n", "Has Custom Template(s)",
            my $has_templates = scalar(grep {$plugin_class_name} @{$app->renderer->paths}) ? $yes : $no);
        printf("%-32s: %s\n", "Has Custom Static Asset(s)",
            my $has_static = scalar(grep {$plugin_class_name} @{$app->static->paths}) ? $yes : $no);
        printf("%-32s: %s\n", "Has Tests", my $has_tests = scalar(@{$plugin->tests}) ? $yes : $no);
        
        my $pcp = $plugin_class_name;
        $pcp =~ s/:+/\//g;
        
        printf("%-32s: %s\n", "Has Markdown Documentation",
            my $has_markdown = scalar(grep {/\Q$pcp\E/} values %$MeritCommons::markdown_files) ? $yes : $no);        
    }

    print "\n";
}

sub help {
    my ($command, $ret_flag) = @_;
    
    my $help = <<"EOF";
Usage: meritcommons plugin_info [OPTIONS] [PLUGIN]

These options are available for 'plugin_info':
    -v, --verbose                   Show extra information about this plugin, including lists of all
                                    included assets, tests, and more.
    -h, --help                      Show this information

EOF
    
    if ($ret_flag) {
        return $help;
    } else {
        print $help;
    }
}

sub verbose_output {
    say "[verbose] $_" for @_;
}

1;
