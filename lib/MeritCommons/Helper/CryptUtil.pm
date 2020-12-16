#
# CryptUtil
# MeritCommons Portal
# (c) 2015 Wayne State University
#

package MeritCommons::Helper::CryptUtil;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File;
use Crypt::Digest qw/digest_data digest_data_hex digest_file digest_file_hex/;
use MIME::Base64 qw/encode_base64url decode_base64url encode_base64 decode_base64/;
use Digest::CRC qw/crc32/;
use Crypt::Sodium;
use Crypt::X509;
use Crypt::PK::RSA;

sub register {
    my ($self, $app) = @_;

    # hash helpers, deprecated first
    $app->deprecated_helper(crc_hex             => \&_crc_hex, '$c->crypto->crc_hex', 'Helper renamed');
    $app->deprecated_helper(md5_hex             => \&_md5_hex, '$c->crypto->md5_hex', 'Helper renamed');
    $app->deprecated_helper(sha256_hex          => \&_sha256_hex, '$c->crypto->sha256_hex', 'Helper renamed');
    $app->deprecated_helper(thumbprint          => \&_thumbprint, '$c->crypto->thumbprint', 'Helper renamed');
    
    $app->helper('crypto.crc_hex'               => \&_crc_hex);
    $app->helper('crypto.md5_hex'               => \&_md5_hex);
    $app->helper('crypto.sha256_hex'            => \&_sha256_hex);
    $app->helper('crypto.thumbprint'            => \&_thumbprint);

    # random string generators
    $app->deprecated_helper(random_a85      => \&_random_a85, '$c->crypto->random_a85', 'Helper renamed');
    $app->deprecated_helper(random_b64      => \&_random_b64, '$c->crypto->random_b64', 'Helper renamed');
    $app->deprecated_helper(random_b64u     => \&_random_b64u, '$c->crypto->random_b64u', 'Helper renamed');
    $app->deprecated_helper(random_hex      => \&_random_hex, '$c->crypto->random_hex', 'Helper renamed');
    $app->deprecated_helper(random_string   => \&_random_string, '$c->crypto->random_string', 'Helper renamed');

    $app->helper('crypto.random_a85'        => \&_random_a85);
    $app->helper('crypto.random_b64'        => \&_random_b64);
    $app->helper('crypto.random_b64u'       => \&_random_b64u);
    $app->helper('crypto.random_hex'        => \&_random_hex);
    $app->helper('crypto.random_string'     => \&_random_string);

    # random key generator (for crypto_stream_xor)
    $app->deprecated_helper(crypto_stream_key   => \&_crypto_stream_key, '$c->crypto->new_stream_cipher_key', 'Helper renamed');
    $app->helper('crypto.new_stream_cipher_key' => \&_crypto_stream_key);

    # encryption functions
    $app->deprecated_helper(encrypt_pw          => \&_encrypt_pw, '$c->crypto->stream_cipher_encrypt', 'Helper renamed');
    $app->deprecated_helper(decrypt_pw          => \&_decrypt_pw, '$c->crypto->stream_cipher_decrypt', 'Helper renamed');
    $app->helper('crypto.stream_cipher_encrypt' => \&_encrypt_pw);
    $app->helper('crypto.stream_cipher_decrypt' => \&_decrypt_pw);

    # weird string encoding functions (that really aren't used anywhere else)
    $app->deprecated_helper(encode_a85  => \&_encode_a85, '$c->crypto->encode_a85', 'Helper renamed');
    $app->deprecated_helper(decode_a85  => \&_decode_a85, '$c->crypto->decode_a85', 'Helper renamed');
    $app->helper('crypto.encode_a85'    => \&_encode_a85);
    $app->helper('crypto.decode_a85'    => \&_decode_a85);

    # these generate signed random tokens with ephemeral keys.  the public key is
    # never shared, just stashed in memcache and retrieved later to check.
    $app->helper('crypto.random_signed_token' => \&_random_signed_token);
    $app->helper('crypto.verify_signed_token' => \&_verify_signed_token);

    # key initialization!  by default we keep a 4096 bit RSA key on hand for plugins that might
    # need it.

    my ($system_cert, $system_pk, $system_sk, $syskey_row);

    foreach my $option (
        qw/front_door_host administrator_email service_country service_state service_locality
        service_organization service_organizational_unit/
      ) {
        unless ($app->global_config->{$option}) {
            $app->log->warn(
                "$option not set in configuration file, will not be able to generate RSA certificates properly");
        }
    }

    my $schema_exists;
    eval { my $test = $app->m->resultset('User')->search({}, { where => \'1 = 0', rows => 1 })->first; };

    # if there were no errors the schema exists
    $schema_exists = 1 unless $@;

    my $initialize_crypto = sub {

        # make this nonfatal since it depends on schema that may or may not be here, and will block schema upgrade
        # commands from running if it fails.
        eval {
            $syskey_row = $app->m->resultset('KeyRegistry')->search(
                {
                    type    => 'rsa',
                    purpose => 'system',
                    status  => 'active',
                },
                {
                    order_by => { -desc => 'id' }
                }
            )->first;

            if ($syskey_row && -e $syskey_row->key_file) {
                ($system_cert, $system_pk, $system_sk) =
                  ($syskey_row->cert_object, $syskey_row->pk_object, $syskey_row->sk_object);
            } else {

                # load (or generate) our keys
                my $timestamp    = time;
                my $crt_path     = "$ENV{MERITCOMMONS_HOME}/etc/keys/rsa.$timestamp.crt";
                my $key_path     = "$ENV{MERITCOMMONS_HOME}/etc/keys/rsa.$timestamp.key";
                my $gen_new_pair = 1;
                my ($crt_text, $rsa_pk, $rsa_sk, $x509_string, $rsa_x509);

                unless (-d "$ENV{MERITCOMMONS_HOME}/etc/keys") {
                    system("mkdir -p $ENV{MERITCOMMONS_HOME}/etc/keys");
                }

                if ($gen_new_pair) {

                    # generate the map...
                    open my $ossl_cfg, '>', "/tmp/meritcommons_openssl_config.$$.conf";
                    print $ossl_cfg "[ req ]\n";
                    print $ossl_cfg "default_bits = 4096\n";
                    print $ossl_cfg "distinguished_name = req_distinguished_name\n";
                    print $ossl_cfg "prompt = no\n\n";

                    print $ossl_cfg "[ req_distinguished_name ]\n";
                    print $ossl_cfg "C=@{[$app->global_config->{service_country}]}\n";
                    print $ossl_cfg "ST=@{[$app->global_config->{service_state}]}\n";
                    print $ossl_cfg "L=@{[$app->global_config->{service_locality}]}\n";
                    print $ossl_cfg "O=@{[$app->global_config->{service_organization}]}\n";
                    print $ossl_cfg "OU=@{[$app->global_config->{service_organizational_unit}]}\n";
                    print $ossl_cfg "CN=@{[$app->global_config->{front_door_host}]}\n";
                    print $ossl_cfg "emailAddress=@{[$app->global_config->{administrator_email}]}\n";
                    close $ossl_cfg;

                    # set aside stderr for a sec..

                    # looks like we have to gen these keys...
                    system("openssl genrsa -out $key_path 4096 >/dev/null 2>&1");
                    system(
                        "openssl req -new -x509 -key $key_path -out $crt_path -days 1825 -sha256 -config /tmp/meritcommons_openssl_config.$$.conf >/dev/null 2>&1"
                    );

                    # load the secret key and cert.....
                    my $key_text    = Mojo::File->new($key_path)->slurp;
                    my $test_rsa_sk = Crypt::PK::RSA->new(\$key_text);

                    $crt_text    = Mojo::File->new($crt_path)->slurp;
                    $x509_string = __unpem($crt_text);
                    my $test_rsa_x509 = Crypt::X509->new(cert => decode_base64($x509_string));
                    my $test_rsa_pk = Crypt::PK::RSA->new(\$test_rsa_x509->pubkey);

                    # test that this keypair matches..
                    my $plaintext = "Hello, World!\n";
                    my $sig = $test_rsa_sk->sign_message($plaintext, 'SHA256', 'v1.5');

                    if ($test_rsa_pk->verify_message($sig, $plaintext, 'SHA256', 'v1.5')) {

                        # this pair works, let's use it!
                        $gen_new_pair = 0;
                        $rsa_pk       = $test_rsa_pk;
                        $rsa_sk       = $test_rsa_sk;
                        $rsa_x509     = $test_rsa_x509;
                        if ($ENV{MERITCOMMONS_DEBUG}) {
                            print "[crypto] created new RSA keypair (Thumbprint: " .
                              $app->thumbprint(decode_base64($x509_string)) . ")\n";
                            print "         Valid after " . localtime($rsa_x509->not_before) . "\n";
                            print "         Valid until " . localtime($rsa_x509->not_after) . "\n";
                        }
                    }
                }

                $syskey_row = $app->m->resultset("KeyRegistry")->create(
                    {
                        certificate => $x509_string,
                        thumbprint  => $app->thumbprint(decode_base64($x509_string)),
                        purpose     => 'system',
                        type        => 'rsa',
                        status      => 'active',
                        key_file    => $key_path,
                        key_length  => 4096,
                        expire_time => $rsa_x509->not_after,
                    }
                );

                ($system_cert, $system_pk, $system_sk) =
                  ($syskey_row->cert_object, $syskey_row->pk_object, $syskey_row->sk_object);

                print "[crypto] RSA key '" .
                  $app->thumbprint(decode_base64($x509_string)) . "' registered as primary 'system' key\n"
                  if $ENV{MERITCOMMONS_DEBUG};

                # cleanup
                unlink("/tmp/meritcommons_openssl_config.$$.conf") if -e "/tmp/meritcommons_openssl_config.$$.conf";

                # throw fatal error if we couldn't find or make a key
                if ($gen_new_pair) {
                    print "[fatal] system couldn't find or generate RSA key pair\n";
                    exit 1;
                }
            }

            if (my $error = $@) {
                die "[fatal] couldn't initialize system RSA key pair: $error\n";
            }

            my $cert_pem = $syskey_row->cert_pem;
            $app->helper(
                system_rsa_cert_pem => sub {
                    return $cert_pem;
                }
            );

            my $x509_string = $syskey_row->certificate;
            $app->helper(
                system_rsa_cert_b64 => sub {
                    return $x509_string;
                }
            );

            my $system_key_thumbprint = $syskey_row->thumbprint;
            $app->helper(
                system_rsa_thumbprint => sub {
                    return $system_key_thumbprint;
                }
            );

            # the row object
            $app->helper(
                system_rsa_row => sub {
                    return $syskey_row;
                }
            );

            # the instantiated Crypt::X509 and Crypt::PK::* objects
            $app->helper(
                system_rsa_cert => sub {
                    return $system_cert;
                }
            );

            $app->helper(
                system_rsa_pk => sub {
                    return $system_pk;
                }
            );

            $app->helper(
                system_rsa_sk => sub {
                    return $system_sk;
                }
            );
        };

        if (my $error = $@) {
            warn "[error] error initializing crypto subsystems; $error\n";
        }
    };

    if ($schema_exists) {
        $initialize_crypto->();
    } else {

        # move us to the front of the line.
        unshift(@{ $app->subscribers('schema_deployed') }, $initialize_crypto);
    }
}

=head2 C<_md5_hex>

  _md5_hex($string);

Returns the md5 hash of the supplied string as a hexidecimal string

=cut

sub _md5_hex {
    my ($controller, $string) = @_;
    return digest_data_hex('MD5', $string);
}

sub _sha256_hex {
    my ($controller, $string) = @_;
    return digest_data_hex('SHA256', $string);
}

sub _thumbprint {
    my ($c, $key) = @_;
    return encode_base64url(digest_data('SHA256', $key));
}

=head2 C<_crc_hex>

  _crc_hex($string);

Returns the crc sum of the supplied file as a hexidecimal string

=cut

sub _crc_hex {
    my ($controller, $string) = @_;
    return sprintf("%08x", crc32($string));
}

=head2 C<_md5_hex_file>

  _md5_hex_file($file_name);

Returns the md5 hash of the supplied file as a hexidecimal string

=cut

sub _md5_hex_file {
    my ($controller, $file_name) = @_;
    if (-e $file_name) {
        return digest_file_hex('MD5', $file_name);
    }
}

# random string generators, take one argument, the size of the output.
# NOTE: not the size of the string that was encoded!!!
sub _random_hex {
    my ($c, $length) = @_;
    return substr(unpack('H*', randombytes_buf(($length // 32) + 1)), 0, $length // 32);
}

sub _random_a85 {
    my ($c, $length) = @_;
    return substr($c->crypto->encode_a85(randombytes_buf($length // 32)), 0, $length // 32);
}

sub _random_b64 {
    my ($c, $length) = @_;
    return substr(encode_base64(randombytes_buf($length // 32), ''), 0, $length // 32);
}

sub _random_b64u {
    my ($c, $length) = @_;
    return substr(encode_base64url(randombytes_buf($length // 32), ''), 0, $length // 32);
}

# this one is unencoded.  though as above the argument is the size of the OUTPUT
sub _random_string {
    my ($c, $length) = @_;
    return randombytes_buf($length // 32);
}

sub _crypto_stream_key {
    my ($c) = @_;
    return encode_base64(randombytes_buf(crypto_stream_KEYBYTES), '');
}

# cookie crypto, crypto_stream_xor
sub _encrypt_pw {
    my ($self, $pw, $key, $nonce) = @_;

    # low entropy nonce, but we are only encrypting with this key once.
    $nonce = substr(digest_data('SHA256', $nonce), 0, crypto_stream_NONCEBYTES);
    return encode_base64(crypto_stream_xor($pw, $nonce, decode_base64($key)), '');
}

sub _decrypt_pw {
    my ($self, $pw_string, $key, $nonce) = @_;

    # low entropy nonce, but we are only using this key once.
    $nonce = substr(digest_data('SHA256', $nonce), 0, crypto_stream_NONCEBYTES);
    return crypto_stream_xor(decode_base64($pw_string), $nonce, decode_base64($key));
}

sub _random_signed_token {
    my ($self) = @_;
    
    # the token itself
    my $token = randombytes_buf(64);
    
    # the keys and a detached signature
    my ($spk, $ssk) = sign_keypair();
    my $sig = crypto_sign_detached($token, $ssk);
    
    return {
        token => encode_base64url($token),
        key => encode_base64url($spk),
        signature => encode_base64url($sig),
    }
}

sub _verify_signed_token {
    my ($self, $token, $sig, $pubkey) = (shift, map { decode_base64url($_) } @_);
            
    if (crypto_sign_verify_detached($sig, $token, $pubkey)) {
        return 1;
    } else {
        return undef;
    }
}

## borrowed from Convert::Ascii85
sub _encode_a85 {
    my ($c, $in, $opt) = @_;

    # shift everything left.
    unless (ref $c) {
        $opt = $in;
        $in  = $c;
    }

    my $_space_no = unpack 'N', ' ' x 4;

    my $compress_zero = exists $opt->{compress_zero} ? $opt->{compress_zero} : 1;
    my $compress_space = $opt->{compress_space};

    my $padding = -length($in) % 4;
    $in .= "\0" x $padding;
    my $out = '';

    for my $n (unpack 'N*', $in) {
        if ($n == 0 && $compress_zero) {
            $out .= 'z';
            next;
        }
        if ($n == $_space_no && $compress_space) {
            $out .= 'y';
            next;
        }

        my $tmp = '';
        for my $i (reverse 0 .. 4) {
            my $mod = $n % 85;
            $n = int($n / 85);
            vec($tmp, $i, 8) = $mod + 33;
        }
        $out .= $tmp;
    }

    $padding or return $out;

    $out =~ s/z\z/!!!!!/;
    substr $out, 0, length($out) - $padding;
}

sub _decode_a85 {
    my ($c, $in) = @_;

    # shift everything left.
    unless (ref $c) {
        $in = $c;
    }

    for ($in) {
        tr[ \t\r\n\f][]d;
        s/z/!!!!!/g;
        s/y/+<VdL/g;
    }

    my $padding = -length($in) % 5;
    $in .= 'u' x $padding;
    my $out = '';

    for my $n (unpack '(a5)*', $in) {
        my $tmp = 0;
        for my $i (unpack 'C*', $n) {
            $tmp *= 85;
            $tmp += $i - 33;
        }
        $out .= pack 'N', $tmp;
    }

    substr $out, 0, length($out) - $padding;
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
    my $unpem = join('', split(/[\r\n]+/, $pem));
    $unpem =~ s/^-----[^-]+-----([^-]+).+$/$1/g;
    return $unpem;
}

1;
