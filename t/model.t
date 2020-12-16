use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use_ok 'MeritCommons';

my $aca = new MeritCommons;
my $model = $aca->m;

done_testing();
