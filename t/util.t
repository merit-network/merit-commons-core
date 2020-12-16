use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use_ok 'MeritCommons::Util';

my $hash1 = {
    'key1' => 'value1',
    'key2' => 'value2'
};
my $hash2 = {
    'key1' => 'value10',
    'key3' => 'value3'
};

MeritCommons::Util::update_hash($hash1, $hash2);
is($hash1->{'key1'}, 'value10');
is($hash1->{'key2'}, 'value2');
is($hash1->{'key3'}, 'value3');

my $hash3 = {
    'key1' => {
        'subkey1' => {
            'subsubkey1' => 'subsubvalue1',
        },
    },
    'key2' => {
        'subkey2' => 'subvalue2',
    },
    'key3' => 'value3',
    'key5' => {
        'subkey5' => 'subvalue5',
    },
};

my $hash4 = {
    'key1' => {
        'subkey1' => {
            'subsubkey1' => 'subsubvalue1new',
        },
    },
    'key4' => {
        'subkey4' => 'subvalue4new',
    },
    'key5' => 'value5new',
};

MeritCommons::Util::update_hash($hash3, $hash4);
is($hash3->{'key1'}->{'subkey1'}->{'subsubkey1'}, 'subsubvalue1new');
is($hash3->{'key2'}->{'subkey2'}, 'subvalue2');
is($hash3->{'key3'}, 'value3');
is($hash3->{'key4'}->{'subkey4'}, 'subvalue4new');
is($hash3->{'key5'}, 'value5new');

done_testing();

