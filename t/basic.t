use Mojo::Base -strict;

use Test::More tests => 4;
use MeritCommons::Test;
use Mojo::JSON qw/encode_json/;
use Mojo::URL;

use_ok 'MeritCommons';

my $config = {
    front_door_host => 'localhost',
};
$ENV{MERITCOMMONS_CONFIG_OVERRIDE} = encode_json($config);

my $t = MeritCommons::Test->new();

$t->get_ok('/')->status_is(200)->content_like(qr/MeritCommons/i);
