use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Digest::SHA qw/sha256_hex/;
use Mojo::Util qw/b64_decode/;
use Crypt::Sodium;

use_ok 'MeritCommons';

my $t = Test::Mojo->new('MeritCommons');

my $app = $t->app;

ok(length($app->crypto->random_string(16)) == 16, "Testing unencoded string lengths");
ok(length($app->crypto->random_hex(16)) == 16, "Testing even hexadecimal string lengths");
ok(length($app->crypto->random_hex(15)) == 15, "Testing odd hexadecimal string lengths");
ok(length($app->crypto->random_a85(16)) == 16, "Testing Ascii 85 string lengths");
ok(length($app->crypto->random_b64(16)) == 16, "Testing Base 64 string lengths");
ok(length($app->crypto->random_b64u(16)) == 16, "Testing Base 64 URL string lengths");
ok(sha256_hex("Hello, World!") eq $app->crypto->sha256_hex("Hello, World!"), "Sanity checking our sha256_hex against Digest::SHA");
ok(length(b64_decode($app->crypto->new_stream_cipher_key)) == crypto_stream_KEYBYTES, "Making sure we generate crypto_stream keys at the proper length");

my $cleartext = 'p@ssw0rd';
my $key = $app->crypto->new_stream_cipher_key;
my $nonce = 31337;
my $encrypted = $app->crypto->encrypt_pw($cleartext, $key, $nonce);

ok($app->crypto->decrypt_pw($encrypted, $key, $nonce) eq $cleartext, "Testing round trip password encrypt / decrypt");

done_testing();