#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command;

use Mojo::Base -base;
use Mojolicious::Validator;

has [qw/hydrant hydrant_request_id expects subcommands/];

has validator => sub { Mojolicious::Validator->new };

# Match (F)ormat Helper Methods
has F_UUID              => sub { qr/^[A-F0-9-]{36}$/i };
has F_USERID            => sub { qr/^[\w\.\-]+$/ };
has F_TIMESTAMP         => sub { qr/^[\d\.]+$/ };
has F_INT               => sub { qr/^\d+$/ };
has F_WORD              => sub { qr/^\w+$/ };
has F_PHRASE            => sub { qr/^[\w ]+$/ };
has F_URI               => sub { qr/^(([^:\/?#]+):)?(\/\/([^\/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?/ };
has F_SEARCH_STRING     => sub { qr/^[\w\s\.\-\&\'\@]+$/ };
has F_MENTION           => sub { qr/^\@[\w\.\- ]+\=*\w*$/ };
has F_STREAM_EXPRESSION => sub { qr/^$/i };
has F_STREAM_NAME       => sub { qr/^[\w\s&]+$/ };

# matches +1 (313) 577-1091; 313-577-1091; (313)-577-1091; +52 55555 123456; 3135771091; 13135771091; 55555123456
has F_PHONE_NUMBER      => sub { qr/^\+*(1|\d{2}}|)(?:\-| )*(?:\(*(\d{3})\)*(?:\-| )*(\d{3})(?:\-| )*(\d{4})|(\d{5})(?:\-| )*(\d{6}))$/ };

# (C)anonicalize Format Helper Methods
sub C_PHONE_NUMBER {
    my ($self, $string) = @_;

    if ($string =~ $self->F_PHONE_NUMBER) {
        my $country_code = "+$1" if $1;

        if ($4 && (!$country_code || ($country_code + 1 == 2))) {
            $country_code //= "+1";
            my $area_code = "($2)";
            my $prefix = $3;
            my $postfix = $4;

            return "$country_code $area_code $prefix-$postfix";
        } elsif ($5 && $6) {
            my $prefix = $5;
            my $postfix = $6;
            unless ($country_code) {
                $country_code = "+52";
                warn "[hydrant_command/debug] canonicalize phone number, $prefix $postfix has no country code, assuming +52; Mexico\n" if $ENV{MERITCOMMONS_DEBUG};
            }

            return "$country_code $prefix $postfix";
        }
    } else {
        # dreams don't mean anything Dolores.
        warn "[hydrant_command/debug] phone number $string doesn't look like anything to me.\n" if $ENV{MERITCOMMONS_DEBUG};
    }

    return undef;
}

sub counts_as_user_activity {
    my ($self) = @_;
    if ($self->can('user_activity_flag') && $self->user_activity_flag) {
        return 1;
    }
    return undef;
}

sub new {
    my ($class, $id, $h) = @_;
    return bless({ hydrant_request_id => $id, hydrant => $h }, $class);
}

sub controller {
    my ($self) = @_;
    return $self->hydrant->controller;
}

sub command {
    my ($self) = @_;
    warn "[error] package " . ref($self) . " doesn't implement a command.\n";
}

sub validation {
    my ($self) = @_;
    if ($self->can('_validation')) {
        unless ($self->{validation}) {

            # a command-enhanced validation w/ custom checks
            $self->{validation} = $self->_validation($self->validator->validation);
        }
    } else {

        # a standard 'validation' without custom checks
        $self->{validation} = $self->validator->validation;
    }
    return $self->{validation};
}

sub send {
    my ($self, $body, $type, $render_as) = @_;

    if (ref $self->hydrant) {
        return $self->hydrant->send($self->hydrant_request_id, $body, $type, $render_as);
    }
}

sub validate {
    my ($self) = @_;
    return undef;
}

1;
