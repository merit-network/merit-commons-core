#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::RecipientSearch;

use Mojo::Base qw(MeritCommons::Hydrant::Command);
use Mojo::JSON qw/encode_json decode_json/;

has expects             => 'json';
has user_activity_flag  => 1;

sub command {
    my ($self, $search) = @_;

    my %s = %$search;

    $s{requestor} = $self->controller->active_user->unique_id;

    $self->controller->run_async_task(
        recipient_search => sub {
            my ($cmd, $doc) = @_;

            # return the search results
            $cmd->send(encode_json($doc->{payload}), "recipient_search:results");
        },
        {
            command  => $self,
            priority => 5,
            args     => [ \%s ],
        }
    );
}

# a hook to add custom checks..
sub _validation {
    my ($self, $validation) = @_;

    # add this check if we're the first...
    unless (exists $validation->validator->checks->{search_contexts}) {
        $validation->validator->add_check(
            search_contexts => sub {
                my ($validation, $name, $value, @contexts) = @_;
                my $checks_failed;
                foreach my $ctx (@contexts) {
                    if (ref $value eq "HASH") {
                        if (scalar(keys %$value) == 1) {
                            my $k = (keys %$value)[0];
                            if ($k eq $ctx) {
                                if (ref $value->{$k} eq "HASH") {
                                    if ($ctx eq "streams") {
                                        my $check_for = {};
                                        foreach my $arg (
                                            qw/minimum_subscribers include_private include_single_subscriber include_personal_outboxes my_authorships_only/
                                          ) {
                                            if (exists($value->{$k}->{$arg})) {
                                                unless ($value->{$k}->{$arg} =~ $self->F_INT) {
                                                    ++$checks_failed;
                                                }
                                            }
                                            $check_for->{$arg} = 1;
                                        }

                                        if (exists($value->{$k}->{type})) {
                                            unless ($value->{$k}->{type} =~ $self->F_WORD) {
                                                ++$checks_failed;
                                            }
                                            $check_for->{type} = 1;
                                        }

                                        if (exists($value->{$k}->{subtype})) {
                                            unless ($value->{$k}->{subtype} =~ $self->F_WORD) {
                                                ++$checks_failed;
                                            }
                                            $check_for->{subtype} = 1;
                                        }

                                        if (exists($value->{$k}->{type_when_empty})) {
                                            unless ($value->{$k}->{type_when_empty} =~ $self->F_WORD) {
                                                ++$checks_failed;
                                            }
                                            $check_for->{type_when_empty} = 1;
                                        }

                                        if (exists($value->{$k}->{subtype_when_empty})) {
                                            unless ($value->{$k}->{subtype_when_empty} =~ $self->F_WORD) {
                                                ++$checks_failed;
                                            }
                                            $check_for->{subtype_when_empty} = 1;
                                        }

                                        # clean out anything "extra"
                                        foreach my $key (keys %{ $value->{$k} }) {
                                            delete $value->{$k}->{$key} unless exists $check_for->{$key};
                                        }
                                    }
                                } elsif (ref($value->{$k}) eq "ARRAY") {

                                    # a list of uuids..
                                    foreach my $v (@{ $value->{$k} }) {
                                        ++$checks_failed unless $v =~ $self->F_UUID;
                                    }
                                } else {

                                    # a single uuid..
                                    unless ($value->{$k} =~ $self->F_UUID) {
                                        ++$checks_failed;
                                    }
                                }
                            }
                        }
                    }
                }

                if ($checks_failed) {
                    return 1;
                } else {
                    return undef;
                }
            }
        );
    }

    return $validation;
}

sub validate {
    my ($self, $arg) = @_;

    if (my $v = $self->validation) {
        $v = $v->input($arg);
        $v->optional('search_string')->like($self->F_SEARCH_STRING)->size(0, 255);
        $v->required('search_contexts')->check(
            search_contexts => qw/
              my_followers followers_of im_following followed_by thread subscribed_to subscribed_with_me
              my_aliases global ldap streams
              /
        );

        return $v;
    }

    return undef;
}

sub __labels {
    return {
        im_following  => "People I'm Following",
        my_followers  => "People Following Me",
        followers_of  => 'People Following <%= $user->common_name %>',
        followed_by   => 'People Followed By <%= $user->common_name %>',
        thread        => "Thread Participants",
        subscribed_to => 'Subscribed To <%= $stream->common_name %>',
        my_aliases    => "People I've Nicknamed",
        global        => "Global List",
        ldap          => "LDAP Search",
        streams       => "Stream Search",
    };
}

1;
