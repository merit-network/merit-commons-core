#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::LocalAuth;

# stores passwords for local users

use base qw/DBIx::Class/;
use Carp qw(croak);

use Crypt::Sodium;
use Mojo::Util qw/b64_decode b64_encode secure_compare encode/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_localauth');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },
    meritcommons_user => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },
    password => {
        data_type => 'varchar',
        size      => 255,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(meritcommons_user => 'MeritCommons::Model::User');
__PACKAGE__->add_unique_constraint(credentials => [qw/meritcommons_user password/]);

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}

sub authenticate {
    my ($self, $try) = @_;
    if (_compare_salted_digest($try, $self->password)) {
        return 1;
    }
    return undef;
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;

    # _salted_digest(clear, salt_len, iterations)
    $self->password(_salted_digest($self->password, 20, 10240));
    $self->next::method(@args);
}

# do this extra stuff on update
sub update {
    my ($self, @args) = @_;

    # uncoverable branch false not really anything else to update
    if ($self->is_column_changed('password')) {
        $self->password(_salted_digest($self->password, 20, 10240));
    }
    $self->next::method(@args);
}

sub _compare_salted_digest {
    my ($cleartext, $digest) = @_;

    # make sure we're UTF-8 encoded
    $cleartext = encode('UTF-8', $cleartext);

    # parse the header
    my ($iterations, $algorithm, $encoded) = $digest =~ /^\{(\d+)x([^\}]+)\}(.+)$/;

    unless ($algorithm eq "SSHA512") {
        warn "[fatal]: unsupported algorithm $algorithm\n";
        return undef;
    }

    my ($hash, $salt) = map { b64_decode($_) } split(':', $encoded);

    my $compare = $cleartext;
    for (my $i = 0 ; $i < $iterations ; $i++) {
        $compare = crypto_hash("$compare$salt");
    }

    if (secure_compare($hash, $compare)) {
        return 1;
    }

    return undef;
}

sub _salted_digest {
    my ($cleartext, $salt_length, $iterations) = @_;

    # make sure we're UTF-8 encoded
    $cleartext = encode('UTF-8', $cleartext);

    my $salt = randombytes_buf($salt_length);

    my $hash = $cleartext;
    for (my $i = 0 ; $i < $iterations ; $i++) {
        $hash = crypto_hash("$hash$salt");
    }

    return "{${iterations}xSSHA512}" . b64_encode($hash, '') . ":" . b64_encode($salt, '');
}

1;
