package MeritCommons::Infra::FlockVPN;

use IO::Interface::Simple;
use Net::Netmask;
use base qw/Class::Accessor/;

__PACKAGE__->mk_accessors(
    qw/
      edge    supernode   app     coordinator
      iface   subnet      password network_name
      port    supernode_port  supernode_ip  dhcpd
      /
);

sub new {
    my ($class, $app) = @_;

    my ($edge, $supernode, $dhcpd);
    if (my $sys_version = $ENV{MERITCOMMONS_SYSTEM_VERSION}) {
        my ($major, $minor) = split(/\./, $sys_version);
        if ($major >= 2 && $minor >= 3) {
            chomp($edge      = `which edge`);
            chomp($supernode = `which supernode`);
            chomp($dhcpd     = `which dhcpd`);
        } else {
            chomp($edge      = `which edge`);
            chomp($supernode = `which supernode`);
            chomp($dhcpd     = `which dhcpd`);

            if ($edge && $supernode && $dhcpd) {
                warn
                  "[warning]: You don't have MeritCommons System version 2.3 or higher, but you do have dhcpd, edge and supernode in your \$PATH.  I'll allow it.\n";
            } else {
                die
                  "[fatal]: MeritCommons::Infra::FlockVPN Requires MeritCommons System version 2.3 or higher (or at least n2n tools installed in your \$PATH).\n";
            }
        }
    } else {
        chomp($edge      = `which edge`);
        chomp($supernode = `which supernode`);
        chomp($dhcpd     = `which dhcpd`);

        unless ($edge && $supernode && $dhcpd) {
            die
              "[fatal]: MeritCommons::Infra::FlockVPN Requires MeritCommons System version 2.3 or higher (or at least n2n tools + dhcpd installed in your \$PATH).\n";
        }
    }

    # are we or aren't we the flock coordinator?
    my $coordinator = $app->config->{flock_coordinator};

    # what's our network interface?
    my $iface = $app->config->{flock_netif_name} // "aca0";

    # what's our FlockVPN subnet?
    my $subnet =
      $app->config->{flock_subnet} ? Net::Netmask->new($app->config->{flock_subnet}) : Net::Netmask->new('10.0.0.0/24');

    # don't ever dump this object.
    my $password = $app->config->{flock_password};

    # get the network name
    my $network_name = $app->config->{flock_network_name} // "meritcommons-flock";

    # get the IP address of the supernode, defaults to the address of ens3, eth0 or en0 if the device exists, or localhost if it doesn't.
    my $supernode_ip =
        $app->config->{flock_supernode_ip} ? $app->config->{flock_supernode_ip}
      : IO::Interface::Simple->new('ens3') ? IO::Interface::Simple->new('ens3')->address
      : IO::Interface::Simple->new('eth0') ? IO::Interface::Simple->new('eth0')->address
      : IO::Interface::Simple->new('en0')  ? IO::Interface::Simple->new('en0')->address
      :                                      '127.0.0.1';

    # ports
    my $supernode_port = $app->config->{flock_port} // 1143;
    my $port = $supernode_port + 1;

    return bless {
        edge           => $edge,
        supernode      => $supernode,
        dhcpd          => $dhcpd,
        app            => $app,
        coordinator    => $coordinator,
        iface          => $iface,
        subnet         => $subnet,
        password       => $password,
        port           => $port,
        supernode_port => $supernode_port,
        supernode_ip   => $supernode_ip,
        network_name   => $network_name,
    }, $class;
}

sub start_edge {
    my ($self, $supernode_ip, $supernode_port, $password) = @_;

    # we run the edge as whatever we're running as now, so we can kill it later.
    my $run_as_uid = $<;
    my $run_as_gid = $( + 0;

    if ($self->edge_pid) {
        return IO::Interface::Simple->new($self->iface);
    } else {
        my $iface;
        if ($self->coordinator) {
            my $ip      = $self->subnet->nth(1);
            my $netmask = $self->subnet->mask;

            my $edge_command =
              "sudo @{[$self->edge]} -d @{[$self->iface]} -r -a 'static:$ip' -c @{[$self->network_name]} " .
              "-l @{[$supernode_ip // $self->supernode_ip]}:@{[$supernode_port // $self->supernode_port]} -u $run_as_uid -g $run_as_gid "
              . "-s @{[$self->subnet->mask]} -m @{[$self->mac_address(1)]} -E -k @{[$password // $self->password]} -p @{[$self->port]}";

            # start 'er up.
            system($edge_command);
        } else {

            my $edge_command =
              "sudo @{[$self->edge]} -d @{[$self->iface]} -r -a 'dhcp:0.0.0.0' -c @{[$self->network_name]} " .
              "-l @{[$supernode_ip // $self->supernode_ip]}:@{[$supernode_port // $self->supernode_port]} -u $run_as_uid -g $run_as_gid "
              . "-s @{[$self->subnet->mask]} -m @{[$self->mac_address]} -E -k @{[$password // $self->password]} -p @{[$self->port]}";

            # start 'er up.
            system($edge_command);
        }

        # wait for the box to create the interface.
        sleep 1;

        return IO::Interface::Simple->new($self->iface);
    }
}

sub iface_obj {
    my ($self) = @_;
    return IO::Interface::Simple->new($self->iface);
}

sub stop_edge {
    my ($self) = @_;
    if (my $pid = $self->edge_pid) {
        kill(2, $pid);
    }
}

sub edge_pid {
    my ($self) = @_;
    my $pid = `ps aux | grep edge | grep meritcommons | grep -v grep | awk '{print \$2}'`;
    chomp($pid);
    return $pid;
}

sub start_dhcpd {
    my ($self) = @_;
    if ($self->coordinator) {
        if (my $pid = $self->dhcpd_pid) {
            warn "[error]: dhcpd is already running as pid $pid, skipping start.\n" if $ENV{MERITCOMMONS_DEBUG};
        } else {
            my $config = $self->generate_dhcpd_config();
            open my $fh, '>', "/tmp/dhcpd.$$.conf" or die "Can't write to /tmp/dhcpd.$$.conf: $!\n";
            print $fh $config;
            close($fh);
            unless (-e "/tmp/meritcommons-dhcp-leases") {
                system("touch /tmp/meritcommons-dhcp-leases");
            }
            system("sudo @{[$self->dhcpd]} -q -cf /tmp/dhcpd.$$.conf -lf /tmp/meritcommons-dhcp-leases " . $self->iface);
            unlink("/tmp/dhcpd.$$.conf");    # clean up once we start.
        }
    } else {
        warn "[error]: cannot call start_dhcpd() if you are not a Flock Coordinator.\n" if $ENV{MERITCOMMONS_DEBUG};
    }
}

sub stop_dhcpd {
    my ($self) = @_;
    if ($self->coordinator) {
        if (my $pid = $self->dhcpd_pid) {
            system("sudo /bin/kill $pid");
        } else {
            warn "[info]: dhcpd not running!\n";
        }
    } else {
        warn "[error]: cannot call stop_dhcpd() if you are not a Flock Coordinator.\n";
    }
}

sub dhcpd_pid {
    my ($self) = @_;
    if ($self->coordinator) {

        # make sure we look just for out dhcp process
        my $pid = `ps aux | grep dhcpd | grep meritcommons | grep -v grep | awk '{print \$2}'`;
        chomp($pid);
        return $pid;
    }
    return undef;
}

sub start_supernode {
    my ($self) = @_;
    if ($self->coordinator) {
        if (my $pid = $self->supernode_pid) {
            warn "[error]: supernode is already running as pid $pid, skipping start.\n" if $ENV{MERITCOMMONS_DEBUG};
        } else {
            system($self->supernode . " -l " . $self->supernode_port);
        }
    } else {
        warn "[error]: cannot call start_supernode() if you are not a Flock Coordinator.\n";
    }
}

sub stop_supernode {
    my ($self) = @_;
    if ($self->coordinator) {
        if (my $pid = $self->supernode_pid) {
            kill(2, $pid);
        } else {
            warn "[info]: stop_supernode() supernode not running!\n" if $ENV{MERITCOMMONS_DEBUG};
        }
    } else {
        warn "[error]: cannot call stop_supernode() if you are not a Flock Coordinator.\n";
    }
}

sub supernode_pid {
    my ($self) = @_;
    if ($self->coordinator) {
        my $pid = `ps aux | grep supernode | grep -v grep | awk '{print \$2}'`;
        chomp($pid);
        return $pid;
    }
    return undef;
}

sub setup_routes {
    my ($self) = @_;

    # let's check if our route's already installed...
    my $multicast_route_installed = 0;

    # scan the routing table.
    open my $routing_table, '-|', '/sbin/route -n';
    while (my $entry = <$routing_table>) {
        chomp($entry);
        my ($dest, $gw, $mask, $flags, $metric, $ref, $use, $iface) = split(/\s+/, $entry);
        if ($dest eq "224.0.0.0" && $iface eq "aca0") {
            $multicast_route_installed = 1;
        }
    }
    close $routing_table;

    unless ($multicast_route_installed) {
        system("sudo /sbin/route add -net 224.0.0.0 netmask 240.0.0.0 dev @{[$self->iface]}");
    }
}

sub generate_dhcpd_config {
    my ($self) = @_;
    my $config = "subnet " . $self->subnet->base . " netmask " . $self->subnet->mask . " {\n";
    $config .= "  max-lease-time 86400;\n";    # 1 day
    $config .= "  range " . join(" ", $self->subnet->nth(2), $self->subnet->nth($self->subnet->size - 2)) . ";\n";
    $config .= "  option subnet-mask " . $self->subnet->mask . ";\n";
    $config .= "  option broadcast-address " . $self->subnet->broadcast . ";\n";
    $config .= "}\n";
    return $config;
}

sub mac_address {
    my ($self, $permanent) = @_;
    if ($permanent) {
        my $mac_address;
        if (-e "$ENV{MERITCOMMONS_HOME}/../var/state/flock_mac_address") {
            open my $fh, '<', "$ENV{MERITCOMMONS_HOME}/../var/state/flock_mac_address";
            $mac_address = <$fh>;
            close $fh;
        } else {
            $mac_address = gen_mac();
            open my $fh, '>', "$ENV{MERITCOMMONS_HOME}/../var/state/flock_mac_address";
            print $fh $mac_address;
            close $fh;
        }
        if ($mac_address =~ /^[0-9A-Fa-f:]+$/) {
            return $mac_address;
        } else {
            die "[fatal]: something's wrong with $ENV{MERITCOMMONS_HOME}/../var/state/flock_mac_address";
        }
    } else {

        # return a fresh one so that DHCP packets route correctly when nodes come back.
        return gen_mac();
    }
}

sub gen_mac {
    my @address = (0x00, 0x16, 0x3e, int(rand(0x7f)), int(rand(0xff)), int(rand(0xff)));
    return join(':', map { sprintf("%02X", $_) } @address);
}

1;
