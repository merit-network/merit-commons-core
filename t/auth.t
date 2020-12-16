use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use_ok 'MeritCommons';

my $t = Test::Mojo->new('MeritCommons');

# obtain the model
my $model = $t->app->m;

done_testing();