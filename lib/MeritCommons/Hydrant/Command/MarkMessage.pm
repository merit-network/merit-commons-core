#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::MarkMessage;

use Mojo::Base qw(MeritCommons::Hydrant::Command);

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $to_mark) = @_;
    my $user = $self->controller->active_user;
    my $count;

    foreach my $message_id (keys %{ $to_mark->{mark_payload} }) {
        if ($message_id =~ /^[0-9a-zA-Z\-]+$/ && $to_mark->{mark_payload}->{$message_id} =~ /^\w+$/) {
            my $msg = $self->controller->message($message_id);
            $msg->mark($to_mark->{mark_payload}->{$message_id}, $user);
            $count++;

            # clear the cache for this message.
            $self->controller->cache->delete($message_id);

            # let everyone know this message has changed.
            foreach my $stream ($msg->streams) {
                $self->controller->pub_write(join(" ", $stream->unique_id, $msg->unique_id));
            }
        }
    }
}

# a hook to add custom checks..
sub _validation {
    my ($self, $validation) = @_;

    # add this check if we're the first...
    unless (exists $validation->validator->checks->{mark_payload}) {
        $validation->validator->add_check(
            mark_payload => sub {
                my ($validation, $name, $value) = @_;
                my $failed = 0;

                # data structure is {UUID => '_flag'}
                if (ref $value eq "HASH") {
                    foreach my $key (keys %$value) {
                        if ($key =~ $self->F_UUID) {
                            unless ($value->{$key} =~ /^_\w+$/) {
                                $failed = 1;
                                last;
                            }
                        } else {
                            $failed = 1;
                            last;
                        }
                    }
                } else {
                    $failed = 1;
                }

                return $failed;
            }
        );
    }

    return $validation;
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {

        # make sure stream ids look like UUIDs
        $v = $v->input($arg);
        $v->required('mark_payload')->check('mark_payload');

        return $v;
    }

    return undef;
}

1;
