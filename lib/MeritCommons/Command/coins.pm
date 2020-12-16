#    MeritCommons Portal
#    Copyright 2016 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::coins;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);

has description => "Coin management.\n";

sub run {
    my ($self, @args) = @_;

    my $sc = shift @args;

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

sub c_list_requests {
    my ($self, @args) = @_;

    my $requests = $self->app->m->resultset('User::MeritCommonscoinRequest')->search(
        {
            approved => 0,
        },
        {
            order_by => {
                "-desc" => ["me.create_time"]
            },
        }
    );

    if ($requests->count) {
        printf '%-3s | %-10s | %-15s | %-10s | %-50s | %-10s ', "ID", "Date", "Requested By", "Amount", "Reason",
          "Status";
        print "\n";
        print "-" x 110;
        print "\n";
        while (my $request = $requests->next) {
            my @time = localtime($request->create_time);

            printf '%-3s | %-10s | %-15s | %-10d | %-50.50s | %-10s ', $request->id,
              ($time[4] + 1) . "/" . $time[3] . "/" . ($time[5] + 1900), $request->requested_by->userid,
              $request->amount_requested, $request->reason,
              ($request->approved ? ($request->approved > 0 ? "Approved" : "Denied") : "Pending");
            print "\n";
        }
    } else {
        print "[warning] There are no open requests.\n";
    }
}

sub c_show_request {
    my ($self, @args) = @_;

    my $request_id = $args[0];

    if ($request_id) {
        my $request = $self->app->m->resultset('User::MeritCommonscoinRequest')->find(
            {
                id => $request_id,
            },
            {
                order_by => {
                    "-desc" => ["me.create_time"]
                },
            }
        );

        if ($request) {
            my @time = localtime($request->create_time);

            print "Coin Request";
            print "\n";
            print "-" x 21;
            print "\n";
            printf "%-20s: %-d", "ID", $request->id;
            print "\n";
            printf "%-20s: %-s", "Date", ($time[4] + 1) . "/" . $time[3] . "/" . ($time[5] + 1900);
            print "\n";
            printf "%-20s: %-s", "Requested By", $request->requested_by->userid;
            print "\n";
            printf "%-20s: %-s", "Amount Requested", $request->amount_requested;
            print "\n";
            printf "%-20s: %-s", "Status",
              ($request->approved ? ($request->approved > 0 ? "Approved" : "Denied") : "Pending");
            print "\n";
            printf "%-20s: %-s", "Reason", $request->reason;
            print "\n";
        } else {
            print "[error] A request with ID $request_id could not be found.\n";
        }
    } else {
        print $self->usage;
    }
}

sub c_list_transactions {
    my ($self, @args) = @_;

    if ($args[0]) {
        my $user = $self->app->user($args[0]);

        if ($user) {
            my $transactions = $self->app->m->resultset('User::MeritCommonscoinTransaction')->search(
                {
                    meritcommons_user => $user->id
                },
                {
                    order_by => {
                        "-desc" => ["me.create_time"]
                    },
                }
            );

            if ($transactions->count) {
                printf '%-3s | %-10s | %-10s | %-10s | %-20s | %-20s | %-15s ', "ID", "Date", "Type", "Role",
                  "Previous Balance", "Resulting Balance", "Second Party";
                print "\n";
                print "-" x 110;
                print "\n";
                while (my $transaction = $transactions->next) {
                    my @time = localtime($transaction->create_time);

                    printf '%-3s | %-10s | %-10s | %-10s | %-20d | %-20d | %-15s ', $transaction->id,
                      ($time[4] + 1) . "/" . $time[3] . "/" . ($time[5] + 1900), $transaction->transaction_type,
                      $transaction->role, int($transaction->previous_balance), int($transaction->resulting_balance),
                      ($transaction->second_party ? $transaction->second_party->userid : "-");
                    print "\n";
                }
            } else {
                print "[warning] User " . $args[0] . " has no transactions.\n";
            }
        } else {
            print "[error] User " . $args[0] . " does not exist.\n";
        }
    } else {
        print $self->usage;
    }
}

sub c_approve_request {
    my ($self, @args) = @_;

    my $request_id = $args[0];

    if ($request_id) {
        my $request = $self->app->respond_to_coin_request($self->app->user(1), $request_id, 1);
        if ($request->{error}) {
            print "[error] " . $request->{error} . "\n";
        } else {
            print $request->{success} . "\n";
        }
    } else {
        print $self->usage;
    }
}

sub c_deny_request {
    my ($self, @args) = @_;

    my $request_id = $args[0];

    if ($request_id) {
        my $request = $self->app->respond_to_coin_request($self->app->user(1), $request_id, 0);
        if ($request->{error}) {
            print "[error] " . $request->{error} . "\n";
        } else {
            print $request->{success} . "\n";
        }
    } else {
        print $self->usage;
    }
}

sub c_give {
    my ($self, @args) = @_;

    if ($args[0] && $args[1]) {
        my $user   = $self->app->user($args[0]);
        my $amount = $args[1];

        if ($user) {
            my $credit = $self->app->credit_coins($self->app->user(1), $amount, $user->unique_id);
            if ($credit->{error}) {
                print "[error] " . $credit->{error} . "\n";
            } else {
                print $credit->{success} . "\n";
            }
        } else {
            print "[error] User " . $args[0] . " does not exist.";
        }
    } else {
        print $self->usage;
    }
}

sub usage {
    my ($self, @args) = @_;

    my $subcommand;
    unless ($subcommand = $args[0]) {
        $subcommand = $ARGV[1];
    }

    $subcommand = '' unless $subcommand;

    if ($subcommand eq "show_request") {
        return << "EOF";
Usage: meritcommons coins show_request [REQUEST]
EOF
    } elsif ($subcommand eq "list_transactions") {
        return << "EOF";
Usage: meritcommons coins list_transactions [USER]
EOF
    } elsif ($subcommand eq "accept_request") {
        return << "EOF";
    Usage: meritcommons coins accept_request [REQUEST]
EOF
    } elsif ($subcommand eq "deny_request") {
        return << "EOF";
    Usage: meritcommons coins deny_request [REQUEST]
EOF
    } elsif ($subcommand eq "give") {
        return << "EOF";
    Usage: meritcommons coins give [USER] [AMOUNT]
EOF
    } else {
        return <<"EOF";
Usage: meritcommons coins [COMMAND] [OPTIONS]

The following commands are available for 'meritcommons coins':
  list_requests     View a list of coin requests.
  show_request      View a specific request.
  accept_request    Accept a coin request.
  deny_request      Deny a coin request.
  list_transactions View a list of tansactions for a specific user.
  give              Give coins to a specific user.
EOF
    }
}

1;
