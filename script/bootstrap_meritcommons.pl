#!/usr/bin/env perl

#####################################
#                                   #
# MERITCOMMONS BOOTSTRAP SCRIPT        #
#                                   #
# MeritCommons                         #
# (c) 2015 Wayne State University   #
# Detroit, MI 48202                 #
#                                   #
#####################################

use EV;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use IO::Interface::Simple;
use POSIX qw(setuid setgid);
use BSD::Resource;

#####################################
# YOU MUST CONFIGURE THIS PER FLOCK #
#####################################

# Supernode connect information
my $flockvpn_supernode_ip = "192.168.143.101";
my $flockvpn_supernode_port = "1143";
my $flockvpn_edge_port = "1144";

# FlockVPN password (the longer the better)
my $flockvpn_password = "kBPrn0Cs2sqrx8140AdzueU3fmpr5DERtiJrMIBhlkag6qYs4QN4LU5YGPelHkDB";

#####################################
#     SAFE TO LEAVE THESE ALONE     #
#####################################

# FlockVPN subnet (must be preconfigured here for firewall rules + routing table)
my $flockvpn_subnet = "10.0.0.0/24";
my $flockvpn_subnet_mask = "255.255.255.0";

# FlockVPN network name (required to connect to the FlockVPN)
my $flockvpn_network_name = "meritcommons-flock";

# FlockVPN network interface name (required to connect to the FlockVPN)
my $flockvpn_iface_name = "aca0";

#####################################
#             END CONFIG            #
#####################################

# don't even try anything unless we're root.
unless ($< eq "0") {
    die "[fatal] bootstrap_meritcommons.pl must be run as part of system startup as root.";
}

# check for previous bootstrappings
if (-e '/usr/local/meritcommons/meritcommons/etc') {
    die "[fatal] this node already bootstrapped; remove directory /usr/local/meritcommons/meritcommons/etc and try again.\n";
}

bs_log("INIT - bootstrap starting");

my $run_as_uid = `id -u meritcommons`;
my $run_as_gid = `id -g meritcommons`;
chomp($run_as_uid, $run_as_gid);

# join FlockVPN
my $edge_command = "sudo /usr/sbin/edge -d $flockvpn_iface_name -r -a 'dhcp:0.0.0.0' -c $flockvpn_network_name " .
                   "-l $flockvpn_supernode_ip:$flockvpn_supernode_port -u $run_as_uid -g $run_as_gid " .
                   "-s $flockvpn_subnet_mask -p $flockvpn_edge_port -k $flockvpn_password -E";

bs_log("NET - starting edge with '$edge_command'");
system($edge_command);

# give edge a second to create the interface.
sleep 1;

# try and get an ip.
if (system("sudo /sbin/dhclient -1 $flockvpn_iface_name") == 0) {
    bs_log("NET - dhclient succeeded on $flockvpn_iface_name");
    # set up a route
    system("/sbin/route add -net 224.0.0.0 netmask 240.0.0.0 dev $flockvpn_iface_name");
    bs_log("NET - setup multicast routes");

    # we got an IP.  let's figure out what it is...
    my $iface = IO::Interface::Simple->new($flockvpn_iface_name);

    # Let's setup a publisher and subscriber.
    # set up publisher
    my $zmq_pctx = zmq_init();
    my $zmq_publisher = zmq_socket($zmq_pctx, ZMQ_PUB);

    # bind to the multicast ip + port, it's hard coded to 239.0.13.13:1313
    zmq_bind($zmq_publisher, "epgm://$flockvpn_iface_name;239.0.13.13:1313");

    # increase the send buffer size of the publisher
    zmq_setsockopt($zmq_publisher, ZMQ_SNDBUF, 65536);

    # now let's set up the subscriber.
    my $zmq_sctx = zmq_init();
    my $zmq_subscriber = zmq_socket($zmq_sctx, ZMQ_SUB);

    # connect to the multicast ip + port, it's hard coded to 239.0.13.13:1313
    zmq_connect($zmq_subscriber, "epgm://$flockvpn_iface_name;239.0.13.13:1313");

    # subscribe to SYSTEM messages
    zmq_setsockopt($zmq_subscriber, ZMQ_SUBSCRIBE, 'SYSTEM');

    bs_log("ZMQ - zmq setup successfully");

    my $aws_instance_id = `curl -s http://169.254.169.254/latest/meta-data/instance-id`;

    # generate a random 32 character string.
    my ($bootstrap_id) = uc(`cat /proc/sys/kernel/random/uuid`);
    chomp($bootstrap_id);

    bs_log("SYS - found that I'm instance $aws_instance_id and that my bootstrap uuid is $bootstrap_id");

    # set up a hashref for communicating between the subrefs below...
    my $status = {};

    my $timer = EV::timer 5, 30, sub {
        my ($w, $revents) = @_;
        if ($status->{bootstrap_started}) {
            # exit this watcher, our bootstrap has already started.
            $w->stop;
        } elsif ($status->{bootstrap_attempt} >= 5) {
            # we're just gonna die because this isn't working
            print "[fatal] bootstrap failed after 5 attempts; please check your config and make sure your coordinator process is running.\n";
            bs_log("QUIT - bootstrap_meritcommons giving up after 5 attempts");
            exit();
        } else {
            # try and send our message
            zmq_msg_send("SYSTEM", $zmq_publisher, ZMQ_SNDMORE);
            zmq_msg_send("NODE_BOOTSTRAP $bootstrap_id $aws_instance_id @{[$iface->address]}", $zmq_publisher);
            $status->{bootstrap_attempt}++;
            bs_log("ZMQ - sent SYSTEM message 'NODE_BOOTSTRAP $bootstrap_id $aws_instance_id @{[$iface->address]}' attempt #$status->{bootstrap_attempt}");
        }
    };

    # we need the filehandle to watch.
    open my $fd, '<&=', zmq_getsockopt($zmq_subscriber, ZMQ_FD);

    my $watcher = EV::io $fd, EV::READ, sub {
        my ($w, $revents) = @_;
        while (zmq_getsockopt($zmq_subscriber, ZMQ_EVENTS) == ZMQ_POLLIN) {
            # get the message
            my $msg = zmq_msg_init();
            zmq_msg_recv($msg, $zmq_subscriber); # This is always "SYSTEM", we don't subscribe to anything else
            $msg = zmq_msg_init();
            zmq_msg_recv($msg, $zmq_subscriber);

            my $payload = zmq_msg_data($msg);

            # $msg now contains what we got back.
            if ($payload eq "COORDINATOR_BOOTSTRAP $bootstrap_id $aws_instance_id @{[$iface->address]} STARTED") {
                $status->{bootstrap_started} = 1;
                bs_log("ZMQ - got COORDINATOR_BOOTSTRAP STARTED; we're being bootstrapped");
                print "[info] bootstrap started at " . scalar(localtime) . "\n";
            } elsif ($payload eq "COORDINATOR_BOOTSTRAP $bootstrap_id $aws_instance_id @{[$iface->address]} COMPLETED") {
                bs_log("ZMQ - got COORDINATOR_BOOTSTRAP COMPLETED; we should be bootstrapped");
                $status->{bootstrap_completed} = 1;
                print "[info] bootstrap finished at " . scalar(localtime) . "\n";
                $w->stop;
                EV::unloop;
            } elsif ($payload =~ /^COORDINATOR_PING ([A-Fa-f0-9-]{36}) $aws_instance_id$/) {
                bs_log("ZMQ - got COORDINATOR_PING; replying with NODE_PONG");
                zmq_msg_send("SYSTEM", $zmq_publisher, ZMQ_SNDMORE);
                zmq_msg_send("NODE_PONG $1 $aws_instance_id", $zmq_publisher);
            }
        }
    };

    # start up the loop.
    EV::run;

    bs_log("ZMQ - left the bootstrap event loop; bootstrap_completed: $status->{bootstrap_completed} in $status->{bootstrap_attempt} of 5 attempt(s)");

    # we don't need zmq anymore, we're all configured and ready to fly.
    zmq_setsockopt($zmq_subscriber, ZMQ_LINGER, 0);
    zmq_close($zmq_subscriber);
    zmq_setsockopt($zmq_publisher, ZMQ_LINGER, 0);
    zmq_close($zmq_publisher);
    zmq_ctx_destroy($zmq_sctx);
    zmq_ctx_destroy($zmq_pctx);
    bs_log("ZMQ - ZMQ torn down successfully");

    # shut down the FlockVPN, MeritCommons should start it again in a more official capacity in a second.
    my $edge_pid = `ps -ef | grep edge | grep -v grep | awk '{print \$2}'`;
    chomp($edge_pid);
    kill(2, $edge_pid);
    bs_log("NET - killed bootstrap edge instance PID $edge_pid");
 
    my $dhclient_pid = `ps -ef | grep dhclient | grep aca0 | grep -v grep | awk '{print \$2}'`;
    chomp($dhclient_pid);
    kill(2, $dhclient_pid);
    bs_log("NET - killed bootstrap dhclient on aca0 PID $dhclient_pid");

    # set rlimits
    setrlimit(RLIMIT_NOFILE, 999999, 999999);
    setrlimit(RLIMIT_NPROC, 65536, 65536);
    setrlimit(RLIMIT_STACK, 16777216, 16777216);

    # setuid + gid to meritcommons
    setgid($run_as_gid);
    setuid($run_as_uid);

    bs_log("SYS - set BSD system limits, setuid $run_as_uid and setgid $run_as_gid");

    # put us in our $HOME
    chdir('/usr/local/meritcommons');

    $ENV{PATH} = join(":", qw{
        /usr/local/meritcommons/meritcommons/script
        /usr/lib/postgresql/9.5/bin
        /bin
        /usr/bin
        /sbin
        /usr/sbin
        /usr/local/sbin
        /usr/local/bin
        /usr/local/meritcommons/bin
    });

    bs_log("INIT - set PATH to $ENV{PATH}");
    bs_log("INIT - starting hypnotoad-meritcommons");
    # hypnotoad will daemonize.
    system(qw{
        /usr/local/meritcommons/meritcommons/script/hypnotoad-meritcommons 
        /usr/local/meritcommons/meritcommons/script/meritcommons
    });
    
    # wait a minute
    sleep 60;

    bs_log("INIT - starting minion_mp");
    # start a daemonized minion_mp
    system(qw{/usr/local/meritcommons/meritcommons/script/meritcommons minion_mp --daemonize});
    bs_log("DONE - instance id $aws_instance_id bootstrapped; commencing handoff to primary MeritCommons services");
} else {
    die "[fatal] error obtaining IP address from Flock Coordinator.  The coordinator is running, right?";
}

sub bs_log {
    my ($msg) = @_;
    unless (-e "/var/tmp/meritcommons_bootstrap.log") {
        system("touch /var/tmp/meritcommons_bootstrap.log");
        system("chmod 666 /var/tmp/meritcommons_bootstrap.log");
    }
    open my $fh, '>>', '/var/tmp/meritcommons_bootstrap.log';
    print $fh "[@{[scalar localtime]}] $msg\n";
    close $fh;
}