#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::generate_messages;

use Mojo::Base 'Mojolicious::Command';
use POSIX;
use Time::HiRes qw( gettimeofday );

has description => "Generate messages for testing purposes\n";
has usage       => "Usage: $0 generate_messages [MESSAGE_COUNT]\n";

sub run {
    my ($self, $message_count) = @_;

    print "Generating $message_count messages...\n";

    # Variables used for message generation
    my @consonants   = qw(b c d f g h j k l m n p q r s t v w x y z);
    my @vowels       = qw(a e i o u);
    my $is_consonant = 0;

    # Identify the pool of users to select from
    my @users = $self->app->m->resultset('User')->search()->all;

    my $start = gettimeofday();
    for (my $messages_created = 0 ; $messages_created < $message_count ; $messages_created++) {

        # Select a user at random
        my $user = $users[ rand @users ];

        # Get authorships
        my @authorships = $user->authorships;

        # This randomly and roughly approximates the number of streams targeted by a typical message.  The majority of posts
        # only target one stream with exponential unliklihood that more streams are targetted (up to 7 streams total).
        my $total_streams = floor(1.0005**rand(64)**2);

        my @target_streams;

        # Identify target streams, limited by the lesser of the calculated number target streams and the number of subscriptions available
        while ((@authorships > 0) && (@target_streams < $total_streams)) {
            push(@target_streams, splice(@authorships, rand(@authorships), 1)->stream);
        }

        # Generate random gibberish for a message
        my $message_text;
        for (my $w = 0 ; $w <= rand(150) ; $w++) {
            for (my $l = 0 ; $l <= rand(7) ; $l++) {
                if ($is_consonant == 0) {
                    $message_text .= @vowels[ rand @vowels ];
                    $is_consonant = 1;
                } else {
                    $message_text .= @consonants[ rand @consonants ];
                    $is_consonant = 0;
                }
            }

            $message_text .= " ";
        }

        my $content = MeritCommons::Content->new(
            {
                render_as          => "generic",
                serialized         => 0,
                body               => $message_text,
                original_body      => $message_text,
                attempted_streams  => \@target_streams,
                streams            => [],
                public             => 1,
                in_reply_to        => undef,
                serialized_payload => undef,
                thread_id          => undef,
            }
        );

        # add to tha database
        $self->app->add_inbound_message($user, $content);

        print "Added message: " . $user->common_name .
          " posting to " . @target_streams . " stream" . ((@target_streams > 1) ? "s" : "") . " (" .
          join(",", (map { $_->id } @target_streams)) . ")\n";
    }

    my $elapsed             = gettimeofday() - $start;
    my $messages_per_second = $message_count / $elapsed;
    printf("Generated %s messages in %.2f seconds (%.2f messages per second)\n",
        $message_count, $elapsed, $messages_per_second);
}

1;
