use Test::More;
use JSON::XS;

# Test for provider configuration loading
sub load_provider_config {
    my ($file) = @_;
    open my $fh, '<', $file or return undef;
    local $/;
    my $json = <$fh>;
    close $fh;
    return decode_json($json);
}

my $config = load_provider_config('providers/openai.json');
ok(defined $config, 'OpenAI config loads');
ok(exists $config->{api_key}, 'API key exists in config');

# Mock API call test (assuming a mock function)
sub mock_api_call {
    return { success => 1 };
}

my $response = mock_api_call();
is($response->{success}, 1, 'Mock API call succeeds');

done_testing();
