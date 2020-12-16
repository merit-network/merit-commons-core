#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::upgrade_schema;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use List::Util qw/max/;

has description => "Upgrade the schema in the database to the current schema version.\n";
has usage       => "Usage: $0 upgrade_schema\n";

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

    my $migration = DBIx::Class::Migration->new(
        schema     => $self->{schema},
        target_dir => $self->{schema_dir},
    );

    my $is_installed     = $migration->dbic_dh->version_storage_is_installed;
    my $schema_version   = $migration->dbic_dh->schema_version;
    my $deployed_version = $migration->dbic_dh->database_version;

    if ($is_installed) {
        if ($schema_version > $deployed_version) {

            if ($deployed_version % 1000 && !($schema_version % 1000)) {
                print "WARNING WARNING WARNING WARNING WARNING\n";
                print "It looks like you are attempting to upgrade from a plugin modified schema to a vanilla\n";
                print "'core' schema.  This may WIPE OUT DATA ASSOCIATED WITH YOUR PLUGINS.  The right thing to\n";
                print "do is to run meritcommons prepare_schema_upgrade, and then try upgrade_schema.  However, if\n";
                print "you are sure you want to do this, please type 'I Understand' and press return.\n";
                print "(Caps and Spaces matter): ";
                my $input = <STDIN>;
                chomp $input;

                unless ($input eq "I Understand") {
                    print "User aborted.\n";
                    exit();
                }
            }

            print "[info]: performing schema upgrade for $deployed_version -> $schema_version\n";
            my $dh = $migration->dbic_dh;
            my @sets = $self->_find_shortest_upgrade_path($deployed_version, $schema_version);

            foreach my $vs (@sets) {
                print " .:step $vs->[0] => $vs->[1]\n";
                my ($ddl, $sql) = $dh->upgrade_single_step({ version_set => $vs });
                $dh->add_database_version(
                    {
                        version     => $vs->[1],
                        ddl         => $ddl,
                        upgrade_sql => $sql,
                    }
                );
            }

            # give plugins a chance to do their thing with their tables.
            eval { $self->app->emit(schema_upgraded => $dh); };

            if (my $error = $@) {
                print "[error]: found error after firing off schema_upgraded event: $error\n";
            }

            print "[done]: database now at version $schema_version\n";
        } elsif ($schema_version < $deployed_version) {
            print
              "[advice]: your schema version ($schema_version) is lower than your deployed version ($deployed_version), try meritcommons downgrade_schema\n";
        } else {
            print
              "[hmm...]: nothing to upgrade.  Schema Version: $schema_version, Installed Version: $deployed_version\n";
        }
    } else {
        print "[info]: database schema is not currently installed, exiting.\n";
    }
}

# this does not find dead ends.  make sure your schemas have all upgrades
sub _find_shortest_upgrade_path {
    my ($self, $from, $to) = @_;

    my @path;
    my $type = $self->{schema}->storage->sqlt_type;
    my $p2u = join('/', $self->{schema_dir}, 'migrations', $type, 'upgrade');

    unless ($self->{migration_map}) {
        $self->{migration_map} = _migration_dir_to_map($p2u);
    }

    my $max_to = max @{ $self->{migration_map}->{$from} };

    if ($max_to == $to) {
        return [ $from, $max_to ];
    } else {
        if ($max_to) {
            push(@path, [ $from, $max_to ], $self->_find_shortest_upgrade_path($max_to, $to));
        } else {
            print
              "[fatal]: dead end at schema version $from on way to version $to, did you remember to run 'meritcommons prepare_schema_upgrade'?\n";
            exit();
        }
    }

    return @path;
}

sub _migration_dir_to_map {
    my ($dir) = @_;

    my $map = {};
    opendir my ($dfh), $dir;
    while (my $migdir = readdir($dfh)) {
        next if $migdir =~ /^\./;
        my ($f, $t) = split(/-/, $migdir);
        push(@{ $map->{$f} }, $t);
    }

    return $map;
}

1;
