#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::decrypt_cookie_payload;

use Mojo::Base 'Mojolicious::Command';

has description => "Decrypts and prints the cookie payload on the command line.\n";
has usage       => "Usage: $0 decrypt_cookie_payload [WAYNEAUTH_COOKIE]\n";

sub run {
    my ($self, $session_id) = @_;
    my $session = $self->app->meritcommons_session($session_id);
    if ($session) {
        print $self->app->decrypt_cookie_payload($session_id) . "\n";
    } else {
        print "Invalid login\n";
    }
}

1;
