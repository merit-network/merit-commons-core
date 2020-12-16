#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::db_optimize;

use Mojo::Base 'Mojolicious::Command';

has description => "Execute DB optimization tasks\n";
has usage       => "Usage: $0 db_optimize\n";

sub run {
    my ($self) = @_;

    if ($self->app->m->storage->dbh->{Driver}->{Name} eq "Pg") {
        my @tables = $self->app->m->storage->dbh->tables();

        foreach my $table (@tables) {
            if ($table =~ /^public.meritcommons_\w+$/) {
                print "[info] Running vacuum on $table\n";
                $self->app->m->storage->dbh->do("vacuum $table");

                print "[info] Running analyze on $table\n";
                $self->app->m->storage->dbh->do("analyze $table");
            }
        }
    }
}

1;
