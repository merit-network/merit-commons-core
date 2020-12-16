#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::schema_info;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use Mojo::Loader qw/load_class/;
use Cwd qw/abs_path/;

has description => "Get information about the currently installed schema.\n";
has usage       => "Usage: $0 schema_info\n";

sub run {
    my ($self) = @_;

    # this is wayyy to spammy.
    unless ($ENV{MERITCOMMONS_DEBUG}) {
        open(STDERR, '>>/dev/null');
    }

    my $core_schema_dir    = $ENV{MERITCOMMONS_HOME} . "/var/sql";
    my $plugins_schema_dir = $ENV{MERITCOMMONS_HOME} . "/../var/plugins/sql";

    $self->{schema} = $self->app->m;

    # if we have schema changing plugins enabled, this should always return true.
    if ($self->{schema}->schema_version % 1000) {
        $self->{schema_dir} = $plugins_schema_dir;
    } else {

        # we're just dealing with vanilla schemas
        $self->{schema_dir} = $core_schema_dir;
    }

    my $abs_schema_dir = abs_path($self->{schema_dir});
    unless ($abs_schema_dir) {
        if ($self->{schema_dir} eq $plugins_schema_dir) {
            print "[warning]: plugins schema directory does not exist ($plugins_schema_dir)!!\n";
        } elsif ($self->{schema_dir} eq $core_schema_dir) {
            print "[warning]: core schema directory does not exist ($core_schema_dir)!!\n";
        } else {
            $self->{schema_dir} = $abs_schema_dir;
        }
    }

    my $migration = DBIx::Class::Migration->new(
        schema     => $self->{schema},
        target_dir => $self->{schema_dir},
    );

    my $is_installed     = $migration->dbic_dh->version_storage_is_installed;
    my $schema_version   = $migration->dbic_dh->schema_version;
    my $deployed_version = $migration->dbic_dh->database_version;
    my $plugins_schema   = $schema_version % 1000;

    print "MeritCommons Schema Information\n";
    print "-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
    print "Configured Database Backend: " . $self->{schema}->{storage}->sqlt_type . "\n";
    print "Installed Schema Version: $deployed_version " .
      ($schema_version == $deployed_version && "(Up to date)") . "\n";
    print "DBIx Schema Version: $schema_version\n";
    print "Core Schema Version: " . ($schema_version - $schema_version % 1000) . "\n";
    print "Loaded From: @{[ abs_path($self->{schema_dir}) ]}\n";
    print "Plugins Schema Present: " . ($schema_version % 1000 ? "Yes" : "No") . "\n";

    my $enabled_plugins;
    if (ref $self->app->plugins_config->{enabled}) {
        foreach my $plugin (@{ $self->app->plugins_config->{enabled} }) {
            load_class $plugin;
            no strict 'refs';
            my $plugin_version        = ${"${plugin}::VERSION"};
            my $plugin_schema_version = ${"${plugin}::SCHEMA_VERSION"};
            use strict 'refs';

            $enabled_plugins->{$plugin} = {
                schema_version => $plugin_schema_version,
                plugin_version => $plugin_version,
            };
        }
    }

    my $last_deployment;
    if (ref($self->app->plugins_config->{schemas_deployed}) eq "ARRAY" &&
        scalar(@{ $self->app->plugins_config->{schemas_deployed} })) {
        $last_deployment =
          $self->app->plugins_config->{schemas_deployed}->[ $#{ $self->app->plugins_config->{schemas_deployed} } ];
    }

    if (scalar(keys %$enabled_plugins)) {
        print "Enabled Plugins:\n";
        foreach my $plugin (sort { $a cmp $b } keys %$enabled_plugins) {
            my ($pv, $sv) =
              ($enabled_plugins->{$plugin}->{plugin_version}, $enabled_plugins->{$plugin}->{schema_version});
            print "   + $plugin v$pv; " . ($sv ? "Schema Version: $sv" : "No schema") . "\n";
        }
    }
    if ($last_deployment && scalar(keys %{ $last_deployment->{plugins} })) {
        print "Last Migration Build:\n";
        foreach my $plugin (sort { $a cmp $b } keys %{ $last_deployment->{plugins} }) {
            my ($pv, $sv) = (
                $last_deployment->{plugins}->{$plugin}->{plugin_version},
                $last_deployment->{plugins}->{$plugin}->{schema_version}
            );
            print "   + $plugin v$pv; " . ($sv ? "Schema Version: $sv" : "No schema") . "\n";
        }
    }

    print "\n";
    if ($schema_version == $deployed_version) {
        print "MeritCommons database is up to date with current schema\n";
    }
}

1;
