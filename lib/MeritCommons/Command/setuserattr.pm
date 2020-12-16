#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::setuserattr;

use Mojo::Base 'Mojolicious::Command';

has description => "Set a user's attribute\n";
has usage       => "Usage: $0 setuserattr [USER] [ATTR] [VALUE..]\n";

sub run {
    my ($self, $username, $attr, @values) = @_;
    unless ($username && $attr && $values[0]) {
        print $self->usage;
        return;
    }

    my $user = $self->app->user($username);

    unless ($user) {
        print "Can't find user $username!\n";
        return;
    }

    if ($attr eq "password") {
        if ($self->app->config->{authentication_provider} eq "MeritCommons::Helper::LocalAuth") {
            my $pw = $values[0];
            if ($pw eq "__random__") {
                $pw = $self->app->random_b64u(12);
            }
            $self->app->change_local_user_password($user, $pw);
            print "Set @{[$user->userid]}'s password to $pw\n";
            exit;
        } else {
            die "[fatal]: can't set 'password' field unless using LocalAuth authentication_provider\n";       
        }
    }

    my @set = $user->$attr(@values);
    $user->update;

    if (!scalar(@set)) {
        print "$attr empty.\n";
    } else {
        print "Set $attr to " . join(', ', @set) . "\n";
    }
}

1;
