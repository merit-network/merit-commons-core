#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::pg_upgrade;

use Mojo::Base 'Mojolicious::Command';
use YAML qw(LoadFile);

has description => "Upgrade database from a previous PostgreSQL version\n";
has usage       => "Usage: $0 pg_upgrade\n";

our $eyes = "O.o";

sub run {
    my ($self) = @_;

    my @process = `ps aux | grep postgres | grep -v grep`;
    if (scalar(@process)) {
        foreach my $process (@process) {
            my ($pid) = (split(/\s+/, $process))[1];
            kill('TERM', $pid);
        }
        print "Sent SIGTERM to " . scalar(@process) . " postgres pids.\n";
    }

    opendir my $dir, '/usr/local/meritcommons';
    my $installed_sys = {};
    while (my $file = readdir($dir)) {
        if (-d "/usr/local/meritcommons/$file" && $file =~ /meritcommons_sys-([\d\.]+)/) {
            $installed_sys->{$1} = "/usr/local/meritcommons/$file";
            print " $eyes Found MeritCommons System $1\n";
            $eyes = _toggle_eyes($eyes);
        }
    }

    my $current_sys = {};
    if (-l "/usr/local/meritcommons/sys") {
        my $current_version;
        eval { $current_version = readlink('/usr/local/meritcommons/sys'); };

        if ($current_version =~ /meritcommons_sys-([\d\.]+)\/*$/) {
            if ($current_version =~ /^\//) {
                $current_sys->{$1} = $current_version;
            } else {
                $current_sys->{$1} = "/usr/local/meritcommons/$current_version";
            }
        }
    } else {
        if (-e "/usr/local/meritcommons/sys/.meritcommons_sys") {
            my $yaml = LoadFile('/usr/local/meritcommons/sys/.meritcommons_sys');
            $current_sys->{ $yaml->{version} } = "/usr/local/meritcommons/sys";
        }
    }

    my ($k, $v) = each %$current_sys;
    print " O.O Found Selected MeritCommons System $k\n";

    my @majors;
    foreach my $ver ($k, keys %$installed_sys) {
        my ($maj, $min) = split(/\./, $ver);
        my $has_major;
        foreach my $major (@majors) {
            if ($maj == $major) {
                $has_major = 1;
                last;
            }
        }
        push(@majors, $maj) unless $has_major;
    }

    if (scalar(@majors) == 1) {
        print " o.o Upgrade Not Required, all found MeritCommons System installs are $majors[0].x releases\n";
        exit();
    }

    print "\n";

    my @versions = sort { $a <=> $b } keys %$installed_sys;
    my ($selected_version) = keys %$current_sys;

    local $| = 1;

    my ($valid_selection, $from_answer, $from_directory, $to_answer, $to_directory);
    until ($valid_selection) {
        print "What version of MeritCommons System are you migrating from? [" . $versions[ $#versions - 1 ] . "]: ";
        my $answer = <STDIN>;
        chomp($answer);

        if (!$answer) {
            $from_answer     = $versions[ $#versions - 1 ];
            $from_directory  = $installed_sys->{$from_answer};
            $valid_selection = 1;
        } elsif ($answer && exists($installed_sys->{$answer})) {
            $from_answer     = $answer;
            $from_directory  = $installed_sys->{$answer};
            $valid_selection = 1;
        } elsif ($answer && exists($current_sys->{$answer})) {
            $from_answer     = $answer;
            $from_directory  = $current_sys->{$answer};
            $valid_selection = 1;
        } else {
            print "Invalid selection, please choose one of " . join(', ', @versions, $selected_version) . "\n";
        }
    }

    $valid_selection = undef;
    until ($valid_selection) {
        print "What version of MeritCommons System are you migrating to? [" . $selected_version . "]: ";
        my $answer = <STDIN>;
        chomp($answer);

        if (!$answer) {
            $to_answer       = $selected_version;
            $to_directory    = $current_sys->{$selected_version};
            $valid_selection = 1;
        } elsif ($answer && exists($installed_sys->{$answer})) {
            $to_answer       = $answer;
            $to_directory    = $installed_sys->{$answer};
            $valid_selection = 1;
        } else {
            print "Invalid selection, please choose one of " . join(', ', @versions, $selected_version) . "\n";
        }
    }

    $valid_selection = undef;

    my ($from_pg_version) = `$from_directory/pgsql/bin/pg_config --version` =~ /([\d\.]+)/;
    my ($to_pg_version)   = `$to_directory/pgsql/bin/pg_config --version` =~ /([\d\.]+)/;

    if ($from_pg_version eq $to_pg_version) {
        warn("[error]: MeritCommons System $from_answer's PostgreSQL version ($from_pg_version) is the same as\n");
        die("         MeritCommons System $to_answer's PostgreSQL version ($to_pg_version).  No upgrade required.\n");
    }

    print
      "\nUpgrade database from pgsql $from_pg_version to pgsql $to_pg_version (MeritCommons System $to_answer)? (y/n) [n]: ";
    my $answer = <STDIN>;
    unless ($answer =~ /^y/i) {
        die "User aborted!\n";
    }

    my $timestamp = time;

    # move the old data.
    system("mv /usr/local/meritcommons/var/pgsql/data /usr/local/meritcommons/var/pgsql/data.$timestamp");

    # init the new db
    system("$to_directory/pgsql/bin/initdb /usr/local/meritcommons/var/pgsql/data");

    # migrate the old data to the new db.
    system(
        "$to_directory/pgsql/bin/pg_upgrade -b $from_directory/pgsql/bin -B $to_directory/pgsql/bin -D /usr/local/meritcommons/var/pgsql/data -d /usr/local/meritcommons/var/pgsql/data.$timestamp"
    );

    print "Please start your new database with: 'pg_ctl -D /usr/local/meritcommons/var/pgsql/data -l logfile start'\n";
    print "And run: 'meritcommons db_optimize' to generate statistics and optimize your tables.\n";
}

sub _toggle_eyes {
    return shift eq "O.o" ? "o.O" : "O.o";
}

1;
