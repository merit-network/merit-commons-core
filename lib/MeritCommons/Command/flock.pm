#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::flock;

use IO::Socket::UNIX;
use Mojo::Base 'Mojolicious::Command';

has description => "Flock Controller Command\n";
has usage       => "Usage: $0 flock (stop|start|update|status) [SCALE FLOOR (optional; defaults to 0)]\n";

sub run {
    my ($self, $command, @args) = @_;

    unless ($self->app->config->{flock_coordinator}) {
        die "[fatal]: this node is not configured to be a flock_coordinator\n";
    }

    # ensure coordinator is running
    my @fc_pids = `ps -ef | grep 'flock_coordinator ' | grep -v grep | awk {'print \$2'}`;
    unless (scalar(@fc_pids) == 1) {
        die
          "[fatal]: a flock_coordinator process must be running to use this tool; please run 'meritcommons (aws_)flock_coordinator' first\n";
    }

    # let's get our socket connection
    my $sock_path = $self->app->config->{flock_coordinator_socket_path};
    my $sock      = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $sock_path,
    ) or die "Can't connect to $sock_path: $!\n";

    # default the first value to 0 (for scale_floor)
    $args[0] = 0 unless scalar(@args);

    # all the complexity is in the coordinator, so just issue the command, and then read
    # until the coordinator closes our socket.
    unless ($command) {
        die $self->usage;
    }

    print $sock join(" ", $command, @args);

    while (my $line = <$sock>) {
        print $line;
    }
}

1;
