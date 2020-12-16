#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::downgrade_schema;

use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Migration;
use List::Util qw/min/;

has description => "Downgrade the schema in the database to the current schema version.\n";
has usage       => "Usage: $0 downgrade_schema\n";

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

    # we might have to switch migrations if we're going back to core (core won't know how to downgrade)...
    if ($deployed_version % 1000) {
        $self->{schema_dir} = $plugins_schema_dir;
        $migration = DBIx::Class::Migration->new(
            schema     => $self->{schema},
            target_dir => $self->{schema_dir},
        );
    }

    if ($is_installed) {
        if ($schema_version < $deployed_version) {
            print "[info]: performing schema downgrade for $deployed_version -> $schema_version\n";
            my $dh = $migration->dbic_dh;
            my @sets = $self->_find_shortest_downgrade_path($deployed_version, $schema_version);

            if (scalar(@sets)) {
                foreach my $vs (@sets) {
                    print " .:step $vs->[0] => $vs->[1]\n";
                    my ($ddl, $sql) = $dh->downgrade_single_step({ version_set => $vs });
                    $dh->delete_database_version(
                        {
                            version => $vs->[0],
                        }
                    );
                }

                print "[done]: database now at version $schema_version\n";
            } else {
                print "[fatal]: system was unable to find migration path from $deployed_version to $schema_version\n";
                exit();
            }
        } elsif ($schema_version > $deployed_version) {
            print
              "[advice]: your schema version ($schema_version) is greater than your deployed version ($deployed_version), try meritcommons upgrade_schema\n";
        } else {
            print
              "[hmm...]: nothing to downgrade.  Schema Version: $schema_version, Installed Version: $deployed_version\n";
        }
    } else {
        print "[info]: database schema is not currently installed, exiting.\n";
    }
}

# this does not find dead ends.  make sure your schemas have all upgrades
sub _find_shortest_downgrade_path {
    my ($self, $from, $to) = @_;

    my @path;
    my $type = $self->{schema}->storage->sqlt_type;
    my $p2u = join('/', $self->{schema_dir}, 'migrations', $type, 'downgrade');

    unless ($self->{migration_map}) {
        $self->{migration_map} = _migration_dir_to_map($p2u);
    }

    my $min_to = min @{ $self->{migration_map}->{$from} };

    if ($min_to == $to) {
        return [ $from, $min_to ];
    } else {
        if ($min_to) {
            push(@path, [ $from, $min_to ], $self->_find_shortest_downgrade_path($min_to, $to));
        } else {
            print "[fatal]: dead end at schema version $from on way to version $to\n";
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
