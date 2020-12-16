#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::flockvpn;

use Mojo::Base 'Mojolicious::Command';
use MeritCommons::Infra::FlockVPN;
use File::Find;

has description => "MeritCommons FlockVPN client (this is a test command and doesn't do anything but start FlockVPN)\n";
has usage       => "Usage: $0 flockvpn [start|stop] [SUPERNODE_IP]:[SUPERNODE_PORT] [PASSWORD]\n";

sub run {
    my ($self, @args) = @_;

    if ($self->app->config('flock_coordinator')) {
        print
          "[info] your node is configured as a flock coordinator, please use 'meritcommons flock_coordinator' instead.\n";
    } else {
        my $fvpn = MeritCommons::Infra::FlockVPN->new($self->app);
        if ($args[0] eq "start") {
            my ($supernode_ip, $supernode_port) = split(/:/, $args[1]) if $args[1];
            my $password = $args[2];
            if ($self->app->config('flock_vpn')) {
                my $iface = $fvpn->start_edge($supernode_ip, $supernode_port, $password);
                if ($iface) {
                    system("sudo dhclient @{[$fvpn->iface]}");
                    $fvpn->setup_routes;
                    print "FlockVPN Interface $iface UP with address @{[$iface->address]}\n";
                }
            } else {
                print "[info] flock_coordinator currently only works with FlockVPN\n";
            }
        } elsif ($args[0] eq "stop") {
            if (my $pid = $fvpn->edge_pid) {
                kill(2, $pid);
            }
        } else {
            print $self->usage;
        }
    }
}

1;

