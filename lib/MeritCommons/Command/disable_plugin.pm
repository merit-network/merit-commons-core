#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::disable_plugin;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use Mojo::Loader qw/load_class/;

has description => "Disable a previously enabled MeritCommons plugin\n";
has usage       => "Usage: $0 disable_plugin <plugin class>\n";

sub run {
    my ($self, $plugin_class) = @_;

    unless ($plugin_class) {
        die $self->usage;
    }

    my $e = load_class $plugin_class;

    if (ref $e) {
        warn "[error] couldn't load $plugin_class: $e\n";
    }

    # get plugins config
    my $pc = $self->app->plugins_config;
    $pc = {} unless ref $pc;

    # initialize enabled array just in case
    $pc->{enabled} = [] unless ref $pc->{enabled} eq "ARRAY";

    my ($plugin_enabled, $new_enabled) = (0, []);
    foreach my $enabled (@{ $pc->{enabled} }) {
        if ($enabled eq $plugin_class) {
            $plugin_enabled = 1;
        } else {
            push(@$new_enabled, $enabled);
        }
    }

    unless ($plugin_enabled) {
        die "[error] cannot disable plugin; $plugin_class was not enabled.\n";
    }

    my $plugin_version = "UNKNOWN";
    my $plugin_schema_version;

    eval {
        no strict 'refs';
        $plugin_version        = ${"${plugin_class}::VERSION"};
        $plugin_schema_version = ${"${plugin_class}::SCHEMA_VERSION"};
        my @plugin_isa = @{"${plugin_class}::ISA"};
        use strict 'refs';

        my $is_meritcommons_plugin;
        foreach my $isa (@plugin_isa) {
            if ($isa eq "MeritCommons::Plugin") {
                $is_meritcommons_plugin = 1;
            }
        }

        unless ($is_meritcommons_plugin) {
            warn "[error] $plugin_class is not an MeritCommons Plugin (does not inherit from MeritCommons::Plugin class)\n";
        }

        if ($plugin_schema_version) {
            print
              " +++ disabling plugin $plugin_class alters schema, please run meritcommons prepare_schema_upgrade +++\n";
        }
    };

    $pc->{enabled} = $new_enabled;
    $self->app->save_plugins_config($pc);

    print "[done] disabled plugin $plugin_class v$plugin_version\n";
}

1;
