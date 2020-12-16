package MeritCommons::SystemAgent;

use Class::Accessor;
use Mojo::EventEmitter;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use Storable qw(freeze thaw dclone);
use Unix::Uptime;
use Scalar::Util qw/weaken/;
use List::Util qw/sum/;
use Mojo::File;
use Mojo::Util 'b64_decode';
use Mojo::JSON 'decode_json';
use File::Basename 'dirname';
use File::Path 'make_path';

BEGIN {
    require IO::Socket;
    require IO::Socket::INET;
    require IO::Interface;
    require IO::Interface::Simple;
    require Mojo::Util;

    Mojo::Util::monkey_patch(
        'IO::Interface::Simple',
        sock => sub {
            my ($self) = @_;
            my $socket = IO::Socket::INET->new(Proto => 'udp') or warn "[iface] can't create socket: $!\n";
            return $socket;
        },
    );
}

our @ISA;
push(@ISA, 'Mojo::EventEmitter');
push(@ISA, 'Class::Accessor');

__PACKAGE__->mk_accessors(
    qw/
      socket app ioloop subfh flockvpn iface ws_client_stats
      /
);

sub new {
    my ($class, %options) = @_;
    my $self = bless \%options, $class;
    $self->register;
    $self->send_node_hello;
    return $self;
}

sub handle {
    my ($self, $message) = @_;
    my ($message_type, $message_id, $payload) = $message =~ /^([A-Z_]+) ([A-Fa-f0-9-]{36})\s*(.*)$/;
    $self->emit($message_type => { id => $message_id, payload => $payload }) if $message_type;
}

sub register {
    my ($self) = @_;

    # initialize our ws client stats
    $self->{ws_client_stats} = {
        active   => 0,
        errored  => 0,
        hwm      => 0,
        finished => 0,
    };

    # check that async_master is running...
    $self->ioloop->recurring(60, \&_watch_async_master);

    # announce our load to the world.
    $self->ioloop->recurring(
        30 => sub {
            $self->send_stats_message(
                "NODE_LOAD", $self->app->new_uuid,
                $self->app->instance_id,
                $self->app->config('hostname'),
                Unix::Uptime->load
            );
        }
    );

    # say hi every hour
    $self->ioloop->recurring(
        3600 => sub {
            $self->send_node_hello;
        }
    );

    $self->ioloop->recurring(
        45 => sub {
            $self->send_websocket_client_stats;
        }
    );

    $self->ioloop->recurring(
        45 => sub {
            $self->send_established_http_sockets;
        }
    );

    if (my $mountpoint = $self->app->global_config->{external_asset_path}) {
        if (my $mount_command = $self->app->global_config->{external_asset_mount_command}) {
            # make sure the external resource stays mounted.
            $self->ioloop->recurring(5 => sub {
                my ($ioloop) = @_;
                unless(__external_mounted($mountpoint)) {
                    __remount_external($mountpoint, $mount_command);
                    if (__external_mounted($mountpoint)) {
                        $self->app->log->warn("external asset path '$mountpoint' was remounted on @{[$self->app->config('hostname')]} (@{[$self->app->instance_id]})");
                    } else {
                        $self->app->log->error("external asset path '$mountpoint' is unmounted on @{[$self->app->config('hostname')]} (@{[$self->app->instance_id]}) and remount failed!");
                    }
                }    
            });
        }
    }

    if (-e '/proc/stat') {

        # we appear to be on linux!  let's monitor CPU
        my $cpu_stats1m = __parse_linux_cpu_stats();
        my $cpu_stats5m = __parse_linux_cpu_stats();
        my $i           = 0;
        $self->ioloop->recurring(
            60 => sub {
                $i++;
                my ($data1m, $data5m);
                ($data1m, $cpu_stats1m) = __get_linux_cpu_stats($cpu_stats1m);

                # get the 5M CPU time
                if ($i == 5) {
                    $i = 0;

                    # replace previous stats
                    ($data5m, $cpu_stats5m) = __get_linux_cpu_stats($cpu_stats5m);
                } else {

                    # don't replace previous stats, still good.
                    $data5m = __get_linux_cpu_stats($cpu_stats5m);
                }

                $self->send_cpu_stats_message($data1m, $data5m);
            }
        );
    }

    # handlers for events received from the app or from
    $self->on(COORDINATOR_HELLO         => \&_COORDINATOR_HELLO);
    $self->on(COORDINATOR_NODE_SHUTDOWN => \&_COORDINATOR_NODE_SHUTDOWN);
    $self->on(SHUTTING_DOWN             => \&_SHUTTING_DOWN);
    $self->on(WEBSOCKET_CLIENT_CONNECT  => \&_WEBSOCKET_CLIENT_CONNECT);
    $self->on(WEBSOCKET_CLIENT_FINISH   => \&_WEBSOCKET_CLIENT_FINISH);
    $self->on(WEBSOCKET_CLIENT_ERROR    => \&_WEBSOCKET_CLIENT_ERROR);
    $self->on(COORDINATOR_WATCH_FILE    => \&_COORDINATOR_WATCH_FILE);
    $self->on(COORDINATOR_PUSH_FILE     => \&_COORDINATOR_PUSH_FILE);
}

sub _WEBSOCKET_CLIENT_ERROR {
    my ($self, $args) = @_;
    $self->{ws_client_stats}->{errored}++;
}

sub _WEBSOCKET_CLIENT_CONNECT {
    my ($self, $args) = @_;
    $self->{ws_client_stats}->{active}++;
    if ($self->{ws_client_stats}->{active} > $self->{ws_client_stats}->{hwm}) {
        $self->{ws_client_stats}->{hwm} = $self->{ws_client_stats}->{active};
    }
}

sub _WEBSOCKET_CLIENT_FINISH {
    my ($self, $args) = @_;
    $self->{ws_client_stats}->{active}--;
    $self->{ws_client_stats}->{finished}++;
}

sub _watch_async_master {
    my $minion_mp_running_as;

    # detect if another instance of ourself is running.
    my @other_pids = `ps -ef | grep 'async_master' | grep -v grep | awk {'print \$2'}`;
    if (scalar(@other_pids) >= 1) {
        foreach my $op (@other_pids) {
            chomp($op);
            $minion_mp_running_as = $op if $op != $$;
        }
    }
    
    unless ($minion_mp_running_as) {
        system("meritcommons minion_mp --daemonize");
    }
}

sub send_established_http_sockets {
    my ($self) = @_;

    # grab # of listening web connections
    my $established = `netstat -tn | grep ESTABLISHED | grep 8443 | wc -l`;
    chomp $established;

    $self->send_stats_message(
        "NODE_ESTABLISHED_HTTP_SOCKETS",
        $self->app->new_uuid,
        $self->app->instance_id,
        $self->app->config('hostname'), $established,
    );
}

sub send_websocket_client_stats {
    my ($self) = @_;
    $self->send_stats_message(
        "NODE_WEBSOCKET_CLIENTS", $self->app->new_uuid,
        $self->app->instance_id,
        $self->app->config('hostname'),
        map { "$_:$self->{ws_client_stats}->{$_}" } sort keys %{ $self->ws_client_stats }
    );
}

sub send_cpu_stats_message {
    my ($self, $stats1m, $stats5m) = @_;

    # craft and send the cpu message
    $self->send_stats_message(
        "NODE_CPU",
        $self->app->new_uuid,              # identifier for this message
        $self->app->instance_id,           # the instance emitting this message
        $self->app->config('hostname'),    # the hostname this instance thinks it has
        int(100 - $stats1m->{idle}),       # 1m CPU %
        int(100 - $stats5m->{idle}),       # 5m CPU %
    );
}

# for gathering % CPU usage
sub __parse_linux_cpu_stats {
    open my $fh, '<', '/proc/stat';
    my $cpu = {};
    while (my $line = <$fh>) {
        if ($line =~ /^cpu\s+(.*)$/) {
            (@{$cpu}{qw(user nice system idle iowait irq softirq steal)}) = split /\s+/, $1;
        }
    }

    close($fh);
    return $cpu;
}

# for processing % CPU usage
sub __get_linux_cpu_stats {
    my ($pstats) = @_;

    my $stats = __parse_linux_cpu_stats();

    # get the total uptime.
    my $uptime  = sum(values %$stats);
    my $puptime = sum(values %$pstats);

    my $pct = {};
    foreach my $key (keys %$stats) {
        $pct->{$key} = sprintf('%.2f', (($stats->{$key} - $pstats->{$key}) / ($uptime - $puptime)) * 100);
    }

    return wantarray ? ($pct, $stats) : $pct;
}

# sent right before the flock coordinator is going to stop our app server instance
sub _COORDINATOR_NODE_SHUTDOWN {
    my ($self, $args) = @_;
    my $instance_id = $args->{payload};
    if ($instance_id eq $self->app->instance_id) {
        open my $pf, '<', $self->app->config->{hypnotoad}->{pid_file};
        my $pid = <$pf>;
        close $pf;

        # immediate shutdown, TERM (kill the websockets)!
        kill('TERM', $pid);
        $self->send_system_message("NODE_SHUTDOWN", $self->app->new_uuid, $self->app->instance_id);
        $self->socket->close;
    }
}

sub _COORDINATOR_PUSH_FILE {
    my ($self, $args) = @_;
    my $cache_key = $args->{payload};
    my $file_payload;
    eval {
        if ($file_payload = $self->app->cache->get($cache_key)) {
            $file_payload = b64_decode($file_payload);
        }
    };
    
    if (my $error = $@) {
        $self->send_system_message("NODE_PUSH_FILE", $self->app->new_uuid, $self->app->instsance_id, "ERROR '$error'");
        return;
    } elsif (!$file_payload) {
        $self->send_system_message("NODE_PUSH_FILE", $self->app->new_uuid, $self->app->instsance_id, "ERROR 'No file payload found for: $cache_key'");
        return;
    }
    
    my $abs_path = $file_payload->{abs_path};
    my $sha256_sum = $file_payload->{sha256_sum};
    if (-f $abs_path) {
        my $local_sum = (split(/\s+/, `sha256sum $abs_path`))[0];
        if ($local_sum && ($local_sum eq $sha256_sum)) {
            $self->send_system_message("NODE_PUSH_FILE", $self->app->new_uuid, $self->app->instsance_id, "ERROR 'SHA256 sums match for both files, push not required'");
            return;
        }
    }

    my $dir = dirname($abs_path);
    unless (-d $dir) {
        eval {
            make_path($dir);
        };
        if (my $error = $@) {
            $self->send_system_message("NODE_PUSH_FILE", $self->app->new_uuid, $self->app->instsance_id, "ERROR 'Couldn't make required parent directory: $error'");
            return;
        }
    }
    
    eval {
        Mojo::File->new($abs_path)->spurt(b64_decode($file_payload->{encoded_contents}));
    };
    
    if (my $error = $@) {
        $self->send_system_message("NODE_PUSH_FILE", $self->app->new_uuid, $self->app->instsance_id, "ERROR '$error'");
        return;
    } else {
        $self->send_system_message("NODE_PUSH_FILE", $self->app->new_uuid, $self->app->instsance_id, "SUCCESS");  
    }
}

sub _COORDINATOR_WATCH_FILE {
    my ($self, $args) = @_;
    my ($file, $zmq_address, @instances) = split(/:/, $args->{payload});

    $zmq_address = 'WATCHFILE' unless $zmq_address;

    unless (-e $file) {

        # allow the specification of paths relative to MERITCOMMONS_HOME
        if (-e "$ENV{MERITCOMMONS_HOME}/$file") {
            $file = "$ENV{MERITCOMMONS_HOME}/$file";
        }
    }

    my $im_listed = scalar(@instances) ? 0 : 1;

    foreach my $instance (@instances) {
        if ($self->app->instance_id eq $instance) {
            $im_listed = 1;
            last;
        }
    }

    if ($im_listed && -e $file) {
        open my $fh, '<', $file
          or $self->send_system_message('NODE_WATCH_FILE', $args->{id}, $self->app->instance_id, $!);

        # don't continue unless we have something
        return unless $fh;

        my $stream = Mojo::IOLoop::Stream->new($fh);

        # set up an event watcher...
        $self->ioloop->recurring(
            0.5 => sub {
                my ($ioloop) = @_;

                # read until new EOF...
                while (my $line = <$fh>) {
                    chomp $line;

                    # spit out logs to ZMQ
                    $self->app->pub_write(
                        join(' ', $zmq_address, $self->app->instance_id, $self->app->config('hostname'), $line));
                }
            }
        );

        $self->send_system_message(
            'NODE_WATCH_FILE', $args->{id},
            $self->app->instance_id,
            "Successfully installed watcher for file $file"
        );
    } else {
        $self->send_system_message(
            'NODE_WATCH_FILE', $args->{id},
            $self->app->instance_id,
            "No such file or directory: $file"
        );
    }
}

sub _COORDINATOR_HELLO {
    my ($self, $payload) = @_;
    $self->send_node_hello($payload->{id});
}

sub send_node_hello {
    my ($self, $id) = @_;
    my @data = (($id ? $id : $self->app->new_uuid), $self->app->instance_id, $self->app->config('hostname'));

    if (my $primary_iface = $self->find_primary_iface) {
        push(@data, $primary_iface->address) if $primary_iface->address;
    }

    if (my $iface = $self->iface) {
        push(@data, $iface->address) if $iface->address;
    }

    my $if = $self->iface;

    $self->send_system_message(NODE_HELLO => @data);
}

sub send_system_message {
    my ($self, @data) = @_;
    $self->app->pub_write("SYSTEM " . join(' ', @data));
}

sub send_stats_message {
    my ($self, @data) = @_;
    $self->app->pub_write("STATS " . join(' ', @data));
}

sub find_primary_iface {
    my ($self) = @_;
    my @tests = qw/
      eth0 eth1 eth2 en0 en1 en2 ens0 ens1 ens2 ens3
      /;
    foreach my $test (@tests) {
        if (my $iface = IO::Interface::Simple->new($test)) {
            return $iface;
        }
    }
    return undef;
}

sub __remount_external {
    my ($mountpoint, $command) = @_;
    system("sudo /bin/umount $mountpoint");
    system($command);    
}

sub __external_mounted {
    my ($mountpoint) = @_;
    return scalar grep { /\Q$mountpoint\E$/ } `df`;
}

1;
