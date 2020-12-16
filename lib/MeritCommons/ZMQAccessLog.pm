#
# Access Logging using ZMQ
#

package MeritCommons::ZMQAccessLog;

use Mojo::Base 'Mojolicious::Plugin';

use Carp qw(carp croak);
use POSIX qw(setlocale strftime LC_ALL);
use Scalar::Util qw(blessed reftype);
use Socket qw(inet_aton AF_INET);
use Time::HiRes qw(gettimeofday tv_interval);

# Lots of code borrowed from Mojolicious::Plugin::AccessLog

our $VERSION = '0.0061';

my $DEFAULT_FORMAT = 'common';
my %FORMATS        = (
    $DEFAULT_FORMAT => '%h %l %u %t "%r" %>s %b',
    combined        => '%h %l "%u" %t "%r" %>s %b "%{Referer}i" "%{User-Agent}i"',
    meritcommons       => '%i %h %l "%u" %t "%r" %>s %b "%{Referer}i" "%{User-Agent}i"',
);

my $TZOFFSET = strftime('%z', localtime) !~ /^[+-]\d{4}$/ && do {
    require Time::Local;
    my $t = time;
    my $d = (Time::Local::timegm(localtime($t)) - $t) / 60;
    sprintf '%+03d%02u', int($d / 60), $d % 60;
};

sub register {
    my ($self, $app, $conf) = @_;

    if ($conf->{uname_helper}) {
        carp 'uname_helper is DEPRECATED in favor of $c->req->env->{REMOTE_USER}';

        my $helper_name = $conf->{uname_helper};

        $helper_name = 'set_username' if $helper_name !~ /^[\_A-za-z]\w*$/;

        $app->helper($helper_name => sub { $_[0]->req->env->{REMOTE_USER} = $_[1] });
    }

    my @handler;
    my $strftime = sub {
        my ($fmt, @time) = @_;
        $fmt =~ s/%z/$TZOFFSET/g if $TZOFFSET;
        my $old_locale = setlocale(LC_ALL);
        setlocale(LC_ALL, 'C');
        my $out = strftime($fmt, @time);
        setlocale(LC_ALL, $old_locale);
        return $out;
    };

    my $format = $FORMATS{ $conf->{format} // $DEFAULT_FORMAT };
    my $safe_re;

    if ($format) {

        # Apache default log formats don't quote username, which might
        # have spaces.
        $safe_re = qr/([^[:print:]]|\s)/;
    } else {

        # For custom log format appropriate quoting is the user's reponsibility.
        $format = $conf->{format};
    }

    my $block_handler = sub {
        my ($block, $type) = @_;

        return sub { _safe($_[2]->headers->header($block) // '-') }
          if $type eq 'i';

        return sub { $_[3]->headers->header($block) // '-' }
          if $type eq 'o';

        return sub { '[' . $strftime->($block, localtime) . ']' }
          if $type eq 't';

        return sub { _safe($_[2]->cookie($block // '')) }
          if $type eq 'C';

        return sub { _safe($_[2]->env->{ $block // '' }) }
          if $type eq 'e';

        $app->log->error("{$block}$type not supported");

        return '-';
    };

    my $servername_cb = sub { $_[4]->base->host     || '-' };
    my $remoteaddr_cb = sub { $_[1]->remote_address || '-' };
    my %char_handler  = (
        '%' => '%',
        a   => $remoteaddr_cb,
        A   => sub { $_[1]->local_address // '-' },
        b   => sub { $_[3]->content->is_dynamic ? '-' : $_[3]->body_size || '-' },
        B => sub { $_[3]->content->is_dynamic ? '0' : $_[3]->body_size },
        D => sub { int($_[5] * 1000000) },
        h => $remoteaddr_cb,
        H => sub { 'HTTP/' . $_[2]->version },
        i => sub { $_[0]->instance_id },
        I => sub { $_[5] },
        l => '-',
        m => sub { $_[2]->method },
        O => sub { $_[6] },
        p => sub { $_[1]->local_port },
        P => sub { $$ },
        q => sub {
            my $s = $_[4]->query->to_string or return '';
            return '?' . $s;
        },
        r => sub {
            $_[2]->method . ' ' . _safe($_[4]->to_string) . ' HTTP/' . $_[2]->version;
        },
        s => sub {
            $_[3]->code;
        },
        t => sub {
            '[' . $strftime->('%d/%b/%Y:%H:%M:%S %z', localtime) . ']';
        },
        T => sub {
            int $_[5];
        },
        u => sub {
            my $env = $_[0]->req->env;
            my $user =
                exists($env->{REMOTE_USER})
              ? length($env->{REMOTE_USER} // '')
                  ? $env->{REMOTE_USER}
                  : '-'
              : '-';

            return _safe($user, $safe_re);
        },
        U => sub {
            $_[4]->path;
        },
        v => $servername_cb,
        V => $servername_cb,
    );

    if ($conf->{hostname_lookups}) {
        $char_handler{h} = sub {
            my $ip = $_[1]->remote_address or return '-';
            return gethostbyaddr(inet_aton($ip), AF_INET);
        };
    }

    my $time_stats;
    my $char_handler = sub {
        my $char = shift;
        my $cb   = $char_handler{$char};

        $time_stats = 1 if $char eq 'T' or $char eq 'D';

        return $char_handler{$char} if $char_handler{$char};

        $app->log->error("\%$char not supported.");

        return '-';
    };

    $format =~ s~
        (?:
        \%\{(.+?)\}([a-z]) |
        \%(?:[<>])?([a-zA-Z\%])
        )
    ~
        push @handler, $1 ? $block_handler->($1, $2) : $char_handler->($3);
        '%s';
    ~egx;

    chomp $format;

    #$format .= $conf->{lf} // $/ // "\n";

    $app->hook(
        around_dispatch => sub {
            my ($next, $c) = @_;
            my $t0;
            $t0 = [gettimeofday] if $time_stats;
            $c->tx->on(
                finish => sub {
                    my $tx = shift;
                    $c->pub_write("LOG ACCESS_LOG @{[$c->instance_id]} " .
                          _log($c, $format, \@handler, $t0 ? tv_interval($t0) : ()));
                }
            );
            $next->();
        }
    );
}

sub _log {
    my ($c, $format, $handler) = (shift, shift, shift);
    my $tx   = $c->tx;
    my $req  = $tx->req;
    my @args = ($c, $tx, $req, $tx->res, $req->url, @_);

    sprintf $format, map(ref() ? ($_->(@args))[0] // '' : $_, @$handler);
}

sub _safe {
    my $string = shift;
    my $re = shift // qr/([^[:print:]])/;

    $string =~ s/$re/'\x' . unpack('H*', $1)/eg
      if defined $string;

    return $string;
}

1;
