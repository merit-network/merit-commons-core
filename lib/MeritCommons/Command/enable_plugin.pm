#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::enable_plugin;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use Mojo::Loader qw/load_class/;

has description => "Enable an MeritCommons plugin\n";
has usage       => "Usage: $0 enable_plugin <plugin class>\n";

sub run {
    my ($self, $plugin_class) = @_;

    unless ($plugin_class) {
        die $self->usage;
    }

    my $e = load_class $plugin_class;

    if (ref $e) {
        die "[error] couldn't load $plugin_class: $e\n";
    }

    # get plugins config
    my $pc = $self->app->plugins_config;
    $pc = {} unless ref $pc;

    # initialize enabled array just in case
    $pc->{enabled} = [] unless ref $pc->{enabled} eq "ARRAY";

    foreach my $enabled (@{ $pc->{enabled} }) {
        if ($enabled eq $plugin_class) {
            die "[error] plugin $plugin_class already enabled.\n";
        }
    }

    no strict 'refs';
    my $plugin_version        = ${"${plugin_class}::VERSION"};
    my $plugin_schema_version = ${"${plugin_class}::SCHEMA_VERSION"};
    my @plugin_isa            = @{"${plugin_class}::ISA"};
    use strict 'refs';

    my $is_meritcommons_plugin;
    foreach my $isa (@plugin_isa) {
        if ($isa eq "MeritCommons::Plugin") {
            $is_meritcommons_plugin = 1;
        }
    }

    unless ($is_meritcommons_plugin) {
        die "[error] $plugin_class is not an MeritCommons Plugin (does not inherit from MeritCommons::Plugin class)\n";
    }

    if ($plugin_schema_version) {
        print " +++ enabling plugin $plugin_class alters schema, please run meritcommons prepare_schema_upgrade +++\n";
    }

    # actually enable the plugin
    push(@{ $pc->{enabled} }, $plugin_class);

    # initialize schemas_deployed if necessary
    $pc->{schemas_deployed} = [] unless ref $pc->{schemas_deployed};

    # since we may have gotten it from the app, and we may have not.. write it using save_hashref
    $self->app->save_plugins_config($pc);

    print "[done] enabled plugin $plugin_class v$plugin_version\n";
}

1;
