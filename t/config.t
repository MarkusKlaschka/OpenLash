use Test::More tests => 3;
use OpenLash::Config;

my $config = OpenLash::Config->load('openai');
ok($config, 'Loaded openai config');
ok(exists $config->{api_key}, 'Has api_key');

$ENV{OPENLASH_OPENAI_API_KEY} = 'test_override';
$config = OpenLash::Config->load('openai');
is($config->{api_key}, 'test_override', 'Env override works');