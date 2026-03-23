#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 8;
use Providers::Memory;
use JSON::PP qw(decode_json);

# Mock LLM and Chroma for testing
# Assume mocks are set up or skip real calls

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },
    chroma => { endpoint => 'mock://' },
};

my $memory = Providers::Memory->new($config);

# Test basic store/recall
$memory->store_short_term("Test event: Meeting with team.", { date => '2026-03-23' });
my $recalled = $memory->recall("meeting");
ok(scalar @$recalled > 0, "Basic recall works");

# Test compression (mock large text)
my $large_text = "A" x 20000;  # Simulate large input
my $compressed = $memory->compress_and_store($large_text, { date => '2026-03-23' });

# Since mocked, check if method runs without die
ok($compressed, "Compression runs");

# Test long-term retrieve (mock)
my $lt = $memory->retrieve_long_term("test");
ok(1, "Retrieve long-term runs");  # Placeholder

# Check output format
ok(exists $compressed->{facts} && ref $compressed->{facts} eq 'ARRAY', "Facts array");
ok(exists $compressed->{summary}, "Summary present");
ok(length($compressed->{summary}) <= 500, "Summary concise");  # Approx tokens, but char check

# Integration test: Store and recall hybrid
my $hybrid = $memory->recall("large", 1);  # Should include compressed if integrated
ok(1, "Hybrid recall placeholder");

done_testing;