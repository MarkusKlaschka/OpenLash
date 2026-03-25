use Test::More;
use Test::MockModule;
use JSON::XS;
use strict;
use warnings;

# Assuming there's a Providers module that loads configs and makes calls
# For example, mock OpenAI provider

my $mock_ua = Test::MockModule->new('LWP::UserAgent');
$mock_ua->redefine('post', sub { return { success => 1, content => '{"response": "mocked"}' }; });

# Load config (simplified)
my $config_file = 'providers/openai.json';
open my $fh, '<', $config_file or die "Can't open $config_file";
my $json = do { local $/; <$fh> };
my $config = decode_json($json);

ok($config->{api_key}, 'OpenAI API key is defined');

# Test API call (assuming a function like call_openai)
# sub call_openai { ... } # Would be in Providers.pm

# my $response = call_openai('prompt');
# is($response->{response}, 'mocked', 'Mocked API response');

# Add more tests for other providers

done_testing();
