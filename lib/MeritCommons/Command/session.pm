#    MeritCommons Portal
#    Copyright 2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::session;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use File::Find;
use POSIX qw(strftime);
use Mojolicious::Controller;
use Mojo::Transaction::HTTP;

has description => "List and manipulate MeritCommons Sessions\n";
has subcommands => sub {
    [ [qw/list kill retrieve count/], ];
};

sub run {
    my ($self, @args) = @_;

    # extract sub command
    my ($sc) = shift @args;

    if ($sc) {
        if ($self->can("c_$sc")) {
            my $method = "c_$sc";
            return $self->$method(@args);
        }
        print "[error] unknown command '$sc'\n";
    } else {
        print $self->usage;
    }
}

sub c_count {
    my ($self, @args) = @_;

    print "Active Sessions:   ",
      $self->app->m->resultset('Session')->search({ expire_time => { '>=', time } })->count, "\n",
      "Unique Users:      ",
      $self->app->m->resultset('Session')->search({}, { columns => [qw/meritcommons_user/], distinct => 1 })->count, "\n",
      "Expired Sessions:  ",
      $self->app->m->resultset('Session')->search({ expire_time => { '<=', time } })->count, "\n",
      "Total Sessions:    ",
      $self->app->m->resultset('Session')->count, "\n";
}

sub c_kill {
    my ($self, @args) = @_;

    if (!$args[0]) {
        print $self->usage('kill');
        return;
    }

    my $user;
    unless ($user = $self->app->user($args[0])) {
        print "[error] couldn't find user for $args[0]\n";
        return;
    }

    if ($user->sessions->count >= 1) {
        foreach my $session ($user->sessions) {
            $session->delete;
            $self->app->emit('session_destroyed',
                Mojolicious::Controller->new(app => $self->app, tx => Mojo::Transaction::HTTP->new), $session);
            print "[info] killed session @{[$session->session_id]}\n";
        }
    } else {
        print "@{[$user->userid]} has no active sessions.\n";
    }
}

sub c_list {
    my ($self, @args) = @_;

    GetOptionsFromArray(
        \@args,
        "v|verbose" => \my $verbose,
        "u|user=s"  => \my $user,
    );

    my $m = $self->app->m;

    unless ($verbose) {
        printf("%-12s %-26s %-17s %-17s %-12s\n", "UserID", "Common Name", "Created", "Expires", "Time Left");
        printf("%-12s %-26s %-17s %-17s %-12s\n", "-" x 12, "-" x 26,      "-" x 17,  "-" x 17,  "-" x 12);
    }

    # search parameters...
    my $params = {};
    if ($user) {
        if (my $user_obj = $self->app->user($user)) {
            $params->{meritcommons_user} = $user_obj->id,;
        }
    }

    my $data = {};
    foreach my $session ($m->resultset('Session')->search($params, { order_by => { -desc => ['expire_time'] } })) {
        $data->{ $session->meritcommons_user->userid }++;
        $data->{_total}++;
        if ($verbose) {
            print "[" . $session->meritcommons_user->userid . "]\n";
            printf("%-40s: %40s\n", "SessionID",             $session->session_id);
            printf("%-40s: %40s\n", "Created From Action",   $session->created_from);
            printf("%-40s: %40s\n", "Heartbeat From Action", $session->heartbeat_from);
            printf("%-40s: %40s\n", "Create Time",           scalar(localtime($session->create_time)));
            printf("%-40s: %40s\n", "Heartbeat Time",        scalar(localtime($session->heartbeat_time)));
            printf("%-40s: %40s\n", "Expire Time",           scalar(localtime($session->expire_time)));
            foreach my $attribute ($session->attributes) {
                my @vals      = $attribute->vals;
                my $first_val = pop(@vals)->v;

                # going to consider it a UNIX timestamp.
                if ($first_val =~ /^\d{10}$/) {
                    $first_val = scalar(localtime($first_val));
                } elsif ($first_val eq 1) {
                    $first_val = "Yes";
                } elsif ($first_val eq 0) {
                    $first_val = "No";
                }

                printf(" ++ %-36s: %40s\n", $attribute->k, $first_val);
                foreach my $val (@vals) {
                    my $v = $val->v;

                    # going to consider it a UNIX timestamp.. 10 digit number
                    if ($v =~ /^\d{10}$/) {
                        $v = localtime($v);
                    } elsif ($first_val eq 1) {
                        $v = "Yes";
                    } elsif ($first_val eq 0) {
                        $first_val = "No";
                    }

                    printf(" ++ %-36s: %40s\n", undef, $v);
                }
            }
            print "[/" . $session->meritcommons_user->userid . "]\n";
        } else {
            my $expire_ago = $self->app->abbr_ago(time - ($session->expire_time - time));

            # UserID, Common Name, Session Created, Session Expires, Time Remaining
            if ($expire_ago eq "Just now") {
                $expire_ago = "Expired";
            }

            printf(
                "%-12s %-26s %-17s %-17s %-12s\n",
                $session->meritcommons_user->userid,
                substr($session->meritcommons_user->common_name, 0, 26),
                strftime("%R %m/%d/%Y", localtime($session->create_time)),
                strftime("%R %m/%d/%Y", localtime($session->expire_time)),

                # we want to know how long until this session expires SO
                $expire_ago,
            );
        }
    }

    my $user_count = (scalar(keys %$data) - 1);
    $user_count = 0 if $user_count < 0;

    my $session_count = $data->{_total} // 0;

    my $user_word = "users";
    if ($user_count == 1) {
        $user_word = "user";
    }

    my $session_word = "sessions";
    if ($session_count == 1) {
        $session_word = "session";
    }

    print "$session_count active MeritCommons $session_word found for $user_count unique $user_word.\n";

}

sub usage {
    my ($self, @args) = @_;

    my $subcommand;
    unless ($subcommand = $args[0]) {
        $subcommand = $ARGV[1];
    }

    # empty string avoids 'undefined' errors
    $subcommand = '' unless $subcommand;

    if ($subcommand eq "count") {
        return <<"EOF";
Usage: meritcommons session count

EOF
    } elsif ($subcommand eq "list") {
        return <<"EOF";
Usage: meritcommons session list [OPTIONS]

These options are available for 'session list':
    -v, --verbose           Print extra information about each session, including session
                            variables. 
    -u, --user              Only show sessions for this user
    -h, --help              Show this page

EOF
    } elsif ($subcommand eq "kill") {
        return <<"EOF";
Usage: meritcommons session kill [USERID]

EOF

    } else {
        return <<"EOF";
Usage: meritcommons session [COMMAND] [OPTIONS]

The following commands are available for 'meritcommons session':
        list                List sessions and session information
        kill                Terminate sessions for a user
        count               Show session counts

EOF
    }
}

1;

