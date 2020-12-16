package MeritCommons::Model::KeyRegistry;

use base qw/DBIx::Class/;
use Mojo::Util qw/b64_decode b64_encode secure_compare encode/;
use Crypt::X509;
use Crypt::PK::DSA;
use Crypt::PK::RSA;
use Crypt::PK::ECC;
use Crypt::Sodium;
use Mojo::File;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_keyregistry');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
    },

    # the base64url encoded der of the client's x509 certificate
    certificate => {
        data_type => 'text',
    },

    # a sha256_hex of the public key of the above
    thumbprint => {
        data_type => 'varchar',
        size      => 255,
    },
    purpose => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/system unspecified/],
        },
    },
    type => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/rsa dsa ecdsa/],
        },
    },
    status => {
        data_type => 'enum',
        is_enum   => 1,
        extra     => {
            list => [qw/active revoked expired/],
        },
    },

    # the full path to the private key
    key_file => {
        data_type => 'text',
    },
    key_length => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    expire_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(thumbprint => ['thumbprint']);

# convenience methods...

sub sk_der {
    return b64_decode(__unpem(Mojo::File->new(shift->key_file)->slurp));
}

sub sk_b64 {
    return __unpem(Mojo::File->new(shift->key_file)->slurp);
}

sub sk_pem {
    return Mojo::File->new(shift->key_file)->slurp;
}

sub sk_object {
    my ($self) = @_;

    return
        $self->type eq "rsa"   ? Crypt::PK::RSA->new(\$self->sk_pem)
      : $self->type eq "dsa"   ? Crypt::PK::DSA->new(\$self->sk_pem)
      : $self->type eq "ecdsa" ? Crypt::PK::ECC->new(\$self->sk_pem)
      :                          undef;
}

sub cert_object {
    return Crypt::X509->new(cert => shift->cert_der);
}

sub pk_object {
    my ($self) = @_;

    return
        $self->type eq "rsa"   ? Crypt::PK::RSA->new(\$self->cert_object->pubkey)
      : $self->type eq "dsa"   ? Crypt::PK::DSA->new(\$self->cert_object->pubkey)
      : $self->type eq "ecdsa" ? Crypt::PK::ECC->new(\$self->cert_object->pubkey)
      :                          undef;
}

sub pk_der {
    return shift->cert_object->pubkey;
}

sub pk_b64 {
    return b64_encode(shift->cert_object->pubkey, '');
}

sub pk_pem {
    my ($self) = @_;
    return __pemify($self->pk_b64,
          $self->type eq "rsa"   ? 'RSA PUBLIC KEY'
        : $self->type eq "dsa"   ? 'DSA PUBLIC KEY'
        : $self->type eq "ecdsa" ? 'EC PUBLIC KEY'
        :                          'PUBLIC KEY');
}

sub cert_pem {
    __pemify(shift->certificate, 'CERTIFICATE');
}

sub cert_der {
    return b64_decode(shift->certificate);
}

sub __pemify {
    my ($b64, $type) = @_;
    return undef unless $type;

    # just make sure it's upper case
    $type = uc($type);

    my ($pos, @pem) = (0, "-----BEGIN $type-----");
    while (my $string = substr($b64, $pos, 64)) {
        push(@pem, $string);
        $pos += 64;
    }
    push(@pem, "-----END $type-----");

    return join("\n", @pem);
}

sub __unpem {
    my ($pem) = @_;
    my $unpem = join('', split("\n", $pem));
    $unpem =~ s/-----[^-]+-----//g;
    return $unpem;
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self->next::method(@args);
}

sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'meritcommons_keyregistry_purpose_idx',
        fields => ['purpose'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_keyregistry_type_idx',
        fields => ['type'],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_keyregistry_status_idx',
        fields => ['status'],
    );
}

1;
