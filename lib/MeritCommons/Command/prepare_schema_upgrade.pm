#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::prepare_schema_upgrade;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use DBIx::Class::Migration;
use Mojo::Loader qw/load_class/;
use File::Copy;

has description => "Prepare migration(s) for database schema upgrade\n";
has usage       => "Usage: $0 prepare_schema_upgrade [force_overwrite]\n";

sub run {
    my ($self, @args) = @_;

    GetOptionsFromArray(
        \@args,
        'force-overwrite'  => \my $force_overwrite,
        'f|from-version=s' => \my $from_version,
        't|to-version=s'   => \my $to_version,
        'd'                => \my $debug,
    );

    if ($debug) {

        # debug toggled on from option
        $ENV{MERITCOMMONS_DEBUG} = 1;
    }

    # this is wayyy to spammy.
    unless ($ENV{MERITCOMMONS_DEBUG}) {
        open(STDERR, '>>/dev/null');
    }

    my $dbix_schema = $self->app->m;

    my $core_schema_dir    = $ENV{MERITCOMMONS_HOME} . "/var/sql";
    my $plugins_schema_dir = $ENV{MERITCOMMONS_HOME} . "/../var/plugins/sql";

    my $schema_dir;

    # if we have schema changing plugins enabled, this should always return true.
    if ($dbix_schema->schema_version % 1000 && !$ENV{MERITCOMMONS_NO_PLUGINS}) {
        system("mkdir -p $plugins_schema_dir") unless -d $plugins_schema_dir;
        system("rsync -apr $core_schema_dir/ $plugins_schema_dir/");

        $schema_dir = $plugins_schema_dir;
    } else {

        # we're just dealing with vanilla schemas
        $schema_dir = $core_schema_dir;
    }

    my $migration;
    if ($force_overwrite) {
        $migration = DBIx::Class::Migration->new(
            schema       => $self->app->m,
            target_dir   => $schema_dir,
            dbic_dh_args => {
                force_overwrite => 1,
            },
        );
    } else {
        $migration = DBIx::Class::Migration->new(
            schema     => $self->app->m,
            target_dir => $schema_dir,
        );
    }

    my $is_installed     = $migration->dbic_dh->version_storage_is_installed;
    my $schema_version   = $migration->dbic_dh->schema_version;
    my $deployed_version = $from_version // $migration->dbic_dh->database_version;
    my $core_version     = _get_core_version($schema_version);

    if ($ENV{MERITCOMMONS_NO_PLUGINS}) {
        $deployed_version = _get_core_version($deployed_version);
    }

    if ($deployed_version % 1000 && $schema_dir ne $plugins_schema_dir) {

        # downgrade should have been prepared with the upgrade, but in case we need these, let's make sure
        # we're pointing at the plugins schema
        $schema_dir = $plugins_schema_dir;
        if ($force_overwrite) {
            $migration = DBIx::Class::Migration->new(
                schema       => $self->app->m,
                target_dir   => $schema_dir,
                dbic_dh_args => {
                    force_overwrite => 1,
                },
            );
        } else {
            $migration = DBIx::Class::Migration->new(
                schema     => $self->app->m,
                target_dir => $schema_dir,
            );
        }
    }

    if ($schema_version == $core_version) {

        # "core" mode
        if ($is_installed) {
            if ($schema_version > $deployed_version) {
                print "[info]: preparing CORE schema upgrade for $deployed_version -> $schema_version\n";
                my $dh = $migration->dbic_dh;

                eval { $dh->prepare_version_storage_install; };

                $dh->prepare_deploy;
                $dh->prepare_upgrade(
                    {
                        from_version => $deployed_version,
                        to_version   => $schema_version,
                        version_set  => [ $deployed_version, $schema_version ],
                    }
                );
                $dh->prepare_downgrade(
                    {
                        from_version => $schema_version,
                        to_version   => $deployed_version,
                        version_set  => [ $schema_version, $deployed_version ],
                    }
                );
                print
                  "[done]: please review the upgrade .sql file in $ENV{MERITCOMMONS_HOME}/var/sql, and run upgrade_schema\n";
            } else {
                print
                  "[hmm...]: nothing to upgrade.  Schema Version: $schema_version, Installed Version: $deployed_version\n";
            }
        } else {
            print "[info]: database schema is not currently installed, exiting.\n";
        }
    } else {

        # plugins "advanced" mode..

        if ($schema_version < $deployed_version) {
            print "[info]: no upgrade to prepare, run meritcommons downgrade_schema\n";
            exit();
        }

        my $this_deployment = {
            version      => $schema_version,
            core_version => $core_version,
        };

        foreach my $plugin (@{ $self->app->plugins_config->{enabled} }) {
            load_class $plugin;
            no strict 'refs';
            my $plugin_version        = ${"${plugin}::VERSION"};
            my $plugin_schema_version = ${"${plugin}::SCHEMA_VERSION"};
            use strict 'refs';

            $this_deployment->{plugins}->{$plugin} = {
                schema_version => $plugin_schema_version,
                plugin_version => $plugin_version,
            };
        }

        my $last_deployment;
        if (ref($self->app->plugins_config->{schemas_deployed}) eq "ARRAY" &&
            scalar(@{ $self->app->plugins_config->{schemas_deployed} })) {
            $last_deployment =
              $self->app->plugins_config->{schemas_deployed}->[ $#{ $self->app->plugins_config->{schemas_deployed} } ];
        } else {
            $self->app->plugins_config->{schemas_deployed} = [];
        }

        if ($last_deployment) {
            unless ($last_deployment->{version} == $deployed_version) {
                warn
                  "[warning]: records say your last deployment was $last_deployment->{version}, yet $deployed_version is installed.\n";
                warn "           did you ever run 'meritcommons upgrade_schema'?\n";
            }
        } else {

            # this must be their first deployment, let's do some sanity checking
            unless ($schema_version - 1 == $core_version) {
                die
                  "[fatal]: first plugins deployment sanity check failed, @{[$schema_version - 1]} != $core_version\n";
            }
        }

        my $dh = $migration->dbic_dh;

        if ($core_version > $deployed_version) {

            # core schema updated!
            print "[info]: preparing upgrade/downgrade from $core_version to $schema_version...\n";
            eval { $dh->prepare_version_storage_install; };
            $dh->prepare_deploy;
            $dh->prepare_upgrade(
                {
                    from_version => $core_version,
                    to_version   => $schema_version,
                    version_set  => [ $core_version, $schema_version ],
                }
            );
            $dh->prepare_downgrade(
                {
                    from_version => $schema_version,
                    to_version   => $core_version,
                    version_set  => [ $schema_version, $core_version ],
                }
            );

            print "[info]: preparing upgrade/downgrade from $deployed_version to $schema_version...\n";
            $dh->prepare_upgrade(
                {
                    from_version => $deployed_version,
                    to_version   => $schema_version,
                    version_set  => [ $deployed_version, $schema_version ],
                }
            );
            $dh->prepare_downgrade(
                {
                    from_version => $schema_version,
                    to_version   => $deployed_version,
                    version_set  => [ $schema_version, $deployed_version ],
                }
            );

            if ($last_deployment && $last_deployment->{version} && ($last_deployment->{version} != $deployed_version)) {
                print
                  "[info]: and to be on the safe side, preparing upgrade/downgrade from $last_deployment->{version} to $schema_version...\n";
                $dh->prepare_upgrade(
                    {
                        from_version => $last_deployment->{version},
                        to_version   => $schema_version,
                        version_set  => [ $last_deployment->{version}, $schema_version ],
                    }
                );
                $dh->prepare_downgrade(
                    {
                        from_version => $schema_version,
                        to_version   => $last_deployment->{version},
                        version_set  => [ $schema_version, $last_deployment->{version} ],
                    }
                );
            }

            # we may need to massage the generated schemas here based on what's in the core migration.
            my $old_core_version = _get_core_version($deployed_version);

            until ($old_core_version + 1000 > $core_version) {

                # we'll always rename our preflight/postflight ###-preflight.sql or ###-postflight.sql
                my $migration_dir =
                  "$schema_dir/migrations/PostgreSQL/upgrade/$old_core_version-@{[$old_core_version + 1000]}";
                my @preflight  = glob("$migration_dir/*-preflight.sql");
                my @postflight = glob("$migration_dir/*-postflight.sql");
                my ($preflight_file, $postflight_file) = ($preflight[0], $postflight[0]);

                if ($preflight_file || $postflight_file) {

                    # ok now scan what we just created...
                    $migration_dir = "$schema_dir/migrations/PostgreSQL/upgrade/$deployed_version-$schema_version";
                    my %cmn;    # current migration numbers
                    my $mdir;
                    opendir $mdir, $migration_dir;
                    while (my $file = readdir($mdir)) {
                        next if $file =~ /^\./;
                        if ($file =~ /^(\d+)(-\w+.sql)$/) {
                            $cmn{$1} = $2;
                        }
                    }
                    closedir $mdir;

                    my $next_num;
                    if (-e $preflight_file) {
                        foreach my $key (sort { $b <=> $a } keys %cmn) {

                            # move all the others up one...
                            move(
                                sprintf("$migration_dir/%03d%s", $key,     $cmn{$key}),
                                sprintf("$migration_dir/%03d%s", $key + 1, $cmn{$key})
                            );
                            $next_num = $key + 1;
                        }
                        copy($preflight_file, $migration_dir);
                        print
                          "[info]: copied migration preflight from core schema migration ($old_core_version-@{[$old_core_version + 1000]})...\n";
                    }

                    if (-e $postflight_file) {
                        copy($postflight_file, sprintf("$migration_dir/%03d%s", $next_num + 1, "-postflight.sql"));
                        print
                          "[info]: copied migration postflight from core schema migration ($old_core_version-@{[$old_core_version + 1000]})...\n";
                    }
                }
                $old_core_version += 1000;
            }
        } elsif ($schema_version > $deployed_version) {

            # plugin schema updated
            print "[info]: preparing upgrade/downgrade $deployed_version to $schema_version...\n";
            eval { $dh->prepare_version_storage_install; };
            $dh->prepare_deploy;
            $dh->prepare_upgrade(
                {
                    from_version => $deployed_version,
                    to_version   => $schema_version,
                    version_set  => [ $deployed_version, $schema_version ],
                }
            );
            $dh->prepare_downgrade(
                {
                    from_version => $schema_version,
                    to_version   => $deployed_version,
                    version_set  => [ $schema_version, $deployed_version ],
                }
            );
        }

        print "[done]: please check out generated migrations in $schema_dir\n";
        push(@{ $self->app->plugins_config->{schemas_deployed} }, $this_deployment);
        $self->app->save_plugins_config;
    }
}

sub _get_core_version {
    my ($version) = @_;
    return $version - ($version % 1000);
}

1;
