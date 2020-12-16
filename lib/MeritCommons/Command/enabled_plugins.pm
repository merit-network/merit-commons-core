#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::enabled_plugins;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use Mojo::Loader qw/load_class/;

has description => "Print out a list of enabled plugins\n";
has usage       => "Usage: $0 enabled_plugins\n";

sub run {
    my ($self) = @_;

    # get plugins config
    my $pc = $self->app->plugins_config;
    $pc = {} unless ref $pc;

    # initialize enabled array just in case
    $pc->{enabled} = [] unless ref $pc->{enabled} eq "ARRAY";

    if (scalar(@{ $pc->{enabled} })) {
        print "\n";
        printf("%-40s %-6s %-12s %-12s\n", "Plugin Class", "Vers.", "Ch. Schema", "Schema Ver.");
        printf("%-40s %-6s %-12s %-12s\n", "-" x 40,       "-" x 6, "-" x 12,     "-" x 12);
        foreach my $plugin_class (sort { $a cmp $b } @{ $pc->{enabled} }) {
            my $e = load_class $plugin_class;

            if (ref $e) {
                warn "[error] couldn't load $plugin_class: $e\n";
                next;
            }

            no strict 'refs';
            my $plugin_version        = ${"${plugin_class}::VERSION"} || "Unknown";
            my $plugin_schema_version = ${"${plugin_class}::SCHEMA_VERSION"};
            my @plugin_isa            = @{"${plugin_class}::ISA"};
            use strict 'refs';

            my $is_meritcommons_plugin;
            foreach my $isa (@plugin_isa) {
                if ($isa eq "MeritCommons::Plugin") {
                    $is_meritcommons_plugin = 1;
                }
            }

            printf(
                "%-40s %-6s %-12s %-12s\n",
                $plugin_class, $plugin_version,
                $plugin_schema_version ? "Yes" : "No",
                $plugin_schema_version ? $plugin_schema_version : "N/A"
            );
        }
    } else {
        print "[info] no plugins currently enabled.\n";
    }

    print "\n";
}

1;
