#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

=head1 NAME

    MeritCommons::Helper::MiscUtil - A helper to do some miscellaneous stuff

=head1 DESCRIPTION

    MeritCommons::Helper::MiscUtil is a helper to do some miscellaneous stuff

=head1 FUNCTIONS

=cut

package MeritCommons::Helper::MiscUtil;
use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/croak/;
use UUID::Tiny;
use Time::Piece;
use JSON::XS;
use POSIX qw/strftime/;

# i guess we're a bit unorthodox up in heah.
no strict "subs";
no warnings;

our $json = JSON::XS->new;
$json->relaxed(1);

=head2 C<register>

  register($app);

A basic helper register method, which registers the helper with the app.

=cut

sub register {
    my ($self, $app) = @_;

    # install local subroutine as a helper.
    $app->helper(get_app_mode            => \&_get_app_mode);
    $app->helper(generate_wordy_password => \&_generate_wordy_password);
    $app->helper(new_uuid                => \&_new_uuid);
    $app->helper(json_decode             => \&_json_decode);
    $app->helper(json_encode             => \&_json_encode);
    $app->helper(fatal_error             => \&_fatal_error);

    # time helpers
    $app->helper(time_mmddyy         => \&_time_mmddyy);
    $app->helper(day_hhmmss          => \&_day_hhmmss);
    $app->helper(time_mmddyy_hhmmss  => \&_time_mmddyy_hhmmss);
    $app->helper(time_week_month_day => \&_time_week_month_day);
    $app->helper(abbr_ago            => \&_abbr_ago);
    $app->helper(wordy_abbr_ago      => \&_wordy_abbr_ago);

    # event handlers

}

=head2 C<_get_app_mode>

  _get_app_mode();

Returns the app's mode (e.g. production, development, ...)

=cut

sub _get_app_mode {
    my ($self) = @_;
    return $self->app->mode;
}

=head2 C<_json_encode>

  _json_encode($ref);

Returns the given string encoded as a JSON object.

=cut

sub _json_encode {
    my ($self, $ref) = @_;
    return $json->encode($ref);
}

=head2 C<_json_decode>

  _json_decode($json_string);

Decodes the given JSON string and returns the resulting Perl object

=cut

sub _json_decode {
    my ($self, $json_string) = @_;
    return $json->decode($json_string);
}

=head2 C<_time_mmddyy>

  _time_mmddyy($timestamp);

Returns a string containing the supplied timestamp in the form MM/DD/YY.

=cut

sub _time_mmddyy {
    my ($controller, $timestamp) = @_;
    my $t = localtime($timestamp);
    return sprintf("%02d/%02d/%d", $t->mon, $t->mday, $t->year);
}

=head2 C<_day_hhmmss>

  _day_hhmmss($timestamp);

Returns a string contaning a more friendly representation of the supplied
timestamp, of the form "<the day> at HH:MM AMPM". <the day> is 
"Month name, day of month" (e.g. "March 31"), or if appropriate, "Today" or
"Yesterday".

Despite the name of this method, it does not include the seconds in the time.

=cut

sub _day_hhmmss {
    my ($controller, $timestamp) = @_;
    my $t         = localtime($timestamp);
    my $today     = localtime(time);
    my $yesterday = localtime(time - 86400);
    if ($t->mday eq $today->mday && $t->month eq $today->month && $t->year eq $today->year) {
        if ($t->hour >= 12) {
            if ($t->hour == 12) {
                return sprintf("Today at %d:%02dPM", $t->hour, $t->min);
            } else {
                return sprintf("Today at %d:%02dPM", $t->hour - 12, $t->min);
            }
        } else {
            if ($t->hour == 0) {
                return sprintf("Today at %d:%02dAM", 12, $t->min);
            } else {
                return sprintf("Today at %d:%02dAM", $t->hour, $t->min);
            }
        }
    } elsif ($t->mday eq $yesterday->mday && $t->month eq $yesterday->month && $t->year eq $yesterday->year) {
        if ($t->hour >= 12) {
            if ($t->hour == 12) {
                return sprintf("Yesterday at %d:%02dPM", $t->hour, $t->min);
            } else {
                return sprintf("Yesterday at %d:%02dPM", $t->hour - 12, $t->min);
            }
        } else {
            if ($t->hour == 0) {
                return sprintf("Yesterday at %d:%02dAM", 12, $t->min);
            } else {
                return sprintf("Yesterday at %d:%02dAM", $t->hour, $t->min);
            }
        }
    } else {
        if ($t->hour >= 12) {
            if ($t->hour == 12) {
                return sprintf("%s %d at %d:%02dPM", $t->monname, $t->mday, $t->hour, $t->min);
            } else {
                return sprintf("%s %d at %d:%02dPM", $t->monname, $t->mday, $t->hour - 12, $t->min);
            }
        } else {
            if ($t->hour == 0) {
                return sprintf("%s %d at %d:%02dAM", $t->monname, $t->mday, 12, $t->min);
            } else {
                return sprintf("%s %d at %d:%02dAM", $t->monname, $t->mday, $t->hour, $t->min);
            }
        }
    }
}

=head2 C<_time_mmddyy_hhmmss>

  _time_mmddyy_hhmmss($timestamp);

Returns a string of the supplied timestamp of the form "DD/MM/YYYY HH:MM:SS"

=cut

sub _time_mmddyy_hhmmss {
    my ($controller, $timestamp) = @_;
    my $t = localtime($timestamp);
    return sprintf("%02d/%02d/%d %02d:%02d:%02d", $t->mon, $t->mday, $t->year, $t->hour, $t->min, $t->sec);
}

=head2 C<_time_week_month_day>

  _time_week_month_day($timestamp);

Returns a string of the supplied timestamp like "Tuesday, March 23"

=cut

sub _time_week_month_day {
    my ($controller, $timestamp) = @_;
    my $t = localtime($timestamp);
    return sprintf("%s, %s %d", $t->fullday, $t->fullmonth, $t->mday);
}

=head2 C<_wordy_abbr_ago>

  _wordy_abbr_ago($timestamp);

Returns the amount of time since the supplied timestamp, in a neat 
human-friendly way, like "just now" for less than a second, or 
"5 hours ago", or "45 minutes ago".

=cut

sub _wordy_abbr_ago {
    my ($controller, $timestamp) = @_;

    my $secs = time - $timestamp;

    if ($secs <= 0) {
        return "Just now";
    } elsif ($secs !~ /^[\d\.]+$/) {
        return undef;
    }

    my ($sec, $min, $hrs, $day, $yrs) = (0, 0, 0, 0, 0);
    my ($minword, $secword, $hrsword, $dayword);

    $min = int($secs / 60);
    $sec = int($secs % 60);
    if ($min >= 60) {
        $hrs = int($min / 60);
        $min = $min % 60;
        if ($hrs >= 24) {
            $day = $hrs / 24;
            $hrs = int($hrs % 24);
            if ($day >= 365) {
                $yrs = int($day / 365);
                $day = $day % 365;
            }
        }
    }

    # make sure i got my jawb strait.
    $minword = $min == 1 ? "minute" : "minutes";
    $secword = $sec == 1 ? "second" : "seconds";
    $hrsword = $hrs == 1 ? "hour"   : "hours";
    $dayword = $day == 1 ? "day"    : "days";

    if ($yrs >= 1) {
        return strftime("%B %d, %Y", localtime($timestamp));
    } elsif ($day >= 1) {
        return strftime("%B %d, %Y", localtime($timestamp));
    } elsif ($hrs >= 1) {
        return sprintf("%d $hrsword ago", $hrs);
    } elsif ($min >= 1) {
        return sprintf("%d $minword ago", $min);
    } else {
        if ($sec <= 0) {
            return "Just now";
        } else {
            return sprintf("%d $secword ago", $sec);
        }
    }
}

=head2 C<_abbr_ago>

  _abbr_ago($timestamp);

Returns the amount of time since the supplied timestamp, in a neat 
human-friendly way, but shorter than C<_wordy_abbr_ago>.

Examples are  "Just now" for less than a second, "5h", 45m", or "22s"

=cut

sub _abbr_ago {
    my ($controller, $timestamp) = @_;

    my $secs = time - $timestamp;

    if ($secs <= 0) {
        return "Just now";
    } elsif ($secs !~ /^[\d\.]+$/) {
        return undef;
    }

    my ($sec, $min, $hrs, $day, $yrs) = (0, 0, 0, 0, 0);
    my ($minword, $secword);

    $min = $secs / 60;
    $sec = $secs % 60;
    if ($min >= 60) {
        $hrs = int($min / 60);
        $min = $min % 60;
        if ($hrs >= 24) {
            $day = $hrs / 24;
            $hrs = int($hrs % 24);
            if ($day >= 365) {
                $yrs = int($day / 365);
                $day = $day % 365;
            }
        }
    }

    # make sure i got my jawb strait.
    $minword = $min == 1 ? "minute" : "minutes";
    $secword = $sec == 1 ? "second" : "seconds";

    if ($yrs >= 1) {
        return strftime("%b %d %Y", localtime($timestamp));
    } elsif ($day >= 1) {
        return strftime("%b %d", localtime($timestamp));
    } elsif ($hrs >= 1) {
        return sprintf("%dh", $hrs);
    } elsif ($min >= 1) {
        return sprintf("%dm", $min);
    } else {
        if ($sec <= 0) {
            return "Just now";
        } else {
            return sprintf("%ds", $sec);
        }
    }
}

=head2 C<_new_uuid>

  _new_uuid();

Generates a UUID returns it as an all-caps string.

=cut

sub _new_uuid {
    my ($controller) = @_;
    return uc(create_UUID_as_string(UUID_V4));
}

=head2 C<_generate_wordy_password>

  _generate_wordy_password($words, $numbers, $word_maxlen, $delim);

Generates a password using a word list. The caller can control how many
words and how many numbers are used in the password with $words and $numbers,
and the maximum length of the words with $word_maxlen arguments. The
character(s) supplied in the $delim argument will be used as a delimiter
between the words and numbers.

=cut

sub _generate_wordy_password {
    my ($controller, $words, $numbers, $word_maxlen, $delim) = @_;

    my $config     = $controller->app->config;
    my $words_file = $config->{words_file};

    # initialize dat password
    my $password;

    # yeah.  set these to zar0.
    my ($words_added, $numbers_added) = (0, 0);

    until ($words_added == $words && $numbers_added == $numbers) {
        if ($words_added == $words) {

            # we have to add a number.
            if ($password) {
                $password .= $delim . int(rand(9 x $word_maxlen));
            } else {
                $password .= int(rand(9 x $word_maxlen));
            }
            ++$numbers_added;

        } elsif ($numbers_added == $numbers) {

            # we have to add a word.
            if ($password) {
                $password .= $delim . __get_random_word($word_maxlen, $words_file);
            } else {
                $password .= __get_random_word($word_maxlen, $words_file);
            }
            ++$words_added;
        } else {

            # we have to add a number or a word.  let's flip a coin.
            if (int(rand(1) + 0.5)) {

                # we add a word.
                if ($password) {
                    $password .= $delim . __get_random_word($word_maxlen, $words_file);
                } else {
                    $password .= __get_random_word($word_maxlen, $words_file);
                }
                ++$words_added;
            } else {

                # we add a number.
                if ($password) {
                    $password .= $delim . int(rand(9 x $word_maxlen));
                } else {
                    $password .= int(rand(9 x $word_maxlen));
                }
                ++$numbers_added;
            }
        }
    }

    return $password;
}

=head2 C<__get_random_word>

  __get_random_word($word_maxlen, $words_file);

Used only by C<_generate_wordy_password>, this function selects a random word
and returns it. The returned word will be of equal or lesser word length
than the $word_maxlen argument, and the $words_file argument specifies the file
to use as a source of words.

=cut

sub __get_random_word {
    my ($word_maxlen, $words_file) = @_;

    return join('', map { ucfirst __single_grw(($word_maxlen - $_), $words_file) } 0 .. 2);
}

sub __single_grw {
    my ($word_maxlen, $words_file) = @_;

    # get the size of the words file.
    my $size = (stat($words_file))[7];

    # open and seek to a random position.
    open(WORDS, '<', $words_file) or die "Can't open $words_file: $!\n";
    seek(WORDS, int(rand($size - 20000)), 0);

    # discard first fragment.
    <WORDS>;

    my $candidate;
    until ($candidate && $candidate =~ /^[a-z]+$/ && (length($candidate) <= $word_maxlen)) {
        chomp($candidate = <WORDS>);

        # exit this loop eventually.
        last unless $candidate;
    }

    return $candidate;
}

sub _fatal_error {
    my ($self, $public_error_message, $detailed_error_message) = @_;
    my $error_id = $self->new_uuid;

    $self->app->log->error("Error ID $error_id - $public_error_message - $detailed_error_message");
    if ($self->tx->remote_address && $self->app->mode eq 'production') {
        die "<h3>$public_error_message</h3><p>Error ID: $error_id</p>\n";
    } else {
        die "$public_error_message: $detailed_error_message\n\nError ID: $error_id\n";
    }
}

1;
