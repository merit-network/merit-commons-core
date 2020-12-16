package MeritCommons::Server::Development;

require MeritCommons;
use Mojo::Base 'Mojo::Server::Morbo';

# we assume we're always going to load in the MeritCommons Docker container or on an MeritCommons AMI
# in other words: Linux.  Where Inotify is a thing.
$ENV{MOJO_MORBO_BACKEND} = "Inotify";

sub run {
    my ($self, $app) = @_;

    # Clean manager environment
    local $SIG{INT} = local $SIG{TERM} = sub {
        $self->{finished} = 1;
        kill 'TERM', $self->{worker} if $self->{worker};
        print "\n[debug] Shutdown time reached at @{[scalar localtime]}\n" if $ENV{MERITCOMMONS_DEBUG};
        for my $check_for (qw/pub-watchdog notifier system-agent/) {
            foreach my $ps_line (`ps -ef | grep meritcommons-$check_for | grep -v grep`) {
                my ($uid, $pid, $ppid, $rest) = $ps_line =~ /^\s*(\w+\+*)\s*(\d+)\s*(\d+)\s*(.+)$/;
                kill 'QUIT', $pid;
            }
        }
        system("meritcommons minion_mp --stop --quiet");
    };
    unshift @{$self->backend->watch}, $0 = $app;
    $self->{modified} = 1;

    $self->_manage until $self->{finished} && !$self->{worker};
    exit 0;
}

sub _spawn {
    my $self = shift;

    # Manager
    my $manager = $$;
    die "Can't fork: $!" unless defined(my $pid = $self->{worker} = fork);
    if ($pid) {
        return;
    }

    # Worker
    my $daemon = $self->daemon;
    my $app = $daemon->load_app($self->backend->watch->[0]);
    $app->emit('devspawn', $app, $daemon);
    sleep 1;
    $MeritCommons::is_manager_process = 1;
    $daemon->ioloop->recurring(1 => sub { shift->stop unless kill 0, $manager });
    $daemon->ioloop->timer(3 => sub { ensure_minion_mp(); });
    
    print "[debug] started meritcommons-development worker $$ at @{[scalar localtime]}\n" if $ENV{MERITCOMMONS_DEBUG};
    
    $daemon->run;
    exit 0;
}

sub ensure_minion_mp {
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

1;