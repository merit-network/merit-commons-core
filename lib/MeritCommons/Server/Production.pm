package MeritCommons::Server::Production;

use Config;
use Mojo::Base 'Mojo::Server::Hypnotoad';
use Mojo::File 'path';
use Mojo::Util 'steady_time';
use Scalar::Util 'weaken';
use File::Basename 'dirname';
use POSIX qw(setsid);

sub run {
    my ($self, $app) = @_;

    # No fork emulation support
    _exit('MeritCommons::Server::Production does not support fork emulation.') if $Config{d_pseudofork};

    # Remember executable and application for later
    $ENV{HYPNOTOAD_EXE} ||= $0;
    $0 = $ENV{HYPNOTOAD_APP} ||= path($app)->to_abs->to_string;

    # This is a production server
    $ENV{MOJO_MODE} ||= 'production';

    # Clean start (to make sure everything works)
    die "Can't exec: $!"
    if !$ENV{HYPNOTOAD_REV}++ && !exec $^X, $ENV{HYPNOTOAD_EXE};

    # Preload application and configure server
    my $prefork = $self->prefork->cleanup(0);
    $prefork->load_app($app)->config->{meritcommons_production}{pid_file}
      //= path($ENV{HYPNOTOAD_APP})->sibling('meritcommons_production.pid')->to_string;
    $self->configure('meritcommons_production');
    weaken $self;
    
    $prefork->on(wait   => sub { $self->_manage });
    $prefork->on(reap   => sub { $self->_cleanup(pop) });
    $prefork->on(finish => sub { $self->_finish });

    # Testing
    _exit('Everything looks good!') if $ENV{HYPNOTOAD_TEST};

    # Stop running server
    $self->_stop if $ENV{HYPNOTOAD_STOP};

    # Initiate hot deployment
    $self->_hot_deploy unless $ENV{HYPNOTOAD_PID};

    # Daemonize as early as possible (but not for restarts)
    if (!$ENV{HYPNOTOAD_FOREGROUND} && $ENV{HYPNOTOAD_REV} < 3) {
        # Fork and kill parent
        die "Can't fork: $!" unless defined(my $pid = fork);
        exit 0 if $pid;
        setsid or die "Can't start a new process table session: $!";

        # Close filehandles
        open STDIN,  '</dev/null';
        open STDOUT, '>/dev/null';
        open STDERR, '>&STDOUT';
    }

    $0 = "meritcommons-prod-master";

    # make sure no children are marked as the manager
    $prefork->on(spawn => sub {
        my ($pid) = @_;
        $MeritCommons::is_manager_process = 0;
        $0 = 'meritcommons-prod-worker';
    });

    # start after daemonize!
    $prefork->start;

    # this one *is* the manager
    $MeritCommons::is_manager_process = 1;
    
    # Start accepting connections
    local $SIG{USR2} = sub { $self->{upgrade} ||= steady_time };
    $prefork->cleanup(1)->run;
}

sub _exit { say shift and exit 0 }

1;