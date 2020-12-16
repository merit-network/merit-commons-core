# MeritCommons Portal
# Copyright 2015-2017 Wayne State University
# All RIghts Reserved

package MeritCommons::Command::email_digest;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);

has description => "Send email digests to users\n.";

sub run {
    my ($self, @args) = @_;

    my $sc = shift @args;

    if ($sc && scalar @args) {
        if ($self->can("c_$sc")) {
            my $method = "c_$sc";
            return $self->$method(@args);
        }
        print "[error] unknown command '$sc'\n";
    } else {
        print $self->usage;
    }
}

sub c_send {
    my ($self, @args) = @_;

    GetOptionsFromArray(
        \@args,
        "d|daily"  => \my $daily,
        "w|weekly" => \my $weekly,
    );

    if ($daily) {
        print "Sending daily email digests to users. This may take some time. Please see log for more details.\n";

        $self->app->send_digest_daily;
    }

    if ($weekly) {
        print
          "Sending weekly daily email digests to users. This may take some time. Please see log for more details.\n";

        $self->app->send_digest_weekly;
    }
}

sub usage {
    my ($self, @args) = @_;

    my $subcommand;
    unless ($subcommand = $args[0]) {
        $subcommand = $ARGV[1];
    }

    $subcommand = '' unless $subcommand;

    if ($subcommand eq "send") {
        return <<"EOF";
Usage: meritcommons email_digest send [OPTIONS]

These options are available for 'email_digest send':
  -d, -daily        Send an email digest to everyone who has a daily digest interval configured.
  -w, -weekly       Send an email digest to everyone who has a weekly digest interval configured.
EOF
    } else {
        return <<"EOF";
Usage: meritcommons email_digest [COMMAND] [OPTIONS]

The following commands are available for 'meritcommons email_digest':
  send        Send email digest to specified users.

EOF
    }
}

1;
