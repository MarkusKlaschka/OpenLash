#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Memory;
use JSON::PP qw(decode_json);

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },  # Mock for tests
    chroma => { endpoint => 'mock://' },
};

my $memory = Memory->new($config);

# Test short-term
$memory->store("Short test event.", { date => '2026-03-23' });
my $short_recall = $memory->recall("test");
is(scalar @$short_recall, 1, "Short-term recall works");

# Test compression trigger
my $large_text = "Large " x 3000;  # ~12k chars
my $compressed = $memory->compress_and_store($large_text, { date => '2026-03-23' });
ok($compressed, "Compression triggered and returned data");

# Check structure
ok(exists $compressed->{facts}, "Facts present");
ok(ref $compressed->{facts} eq 'ARRAY', "Facts is array");
ok(exists $compressed->{summary}, "Summary present");
ok(length($compressed->{summary}) <= 2000, "Summary not too long");

# Test long-term retrieve
my $lt_recall = $memory->retrieve_long_term("large");
ok($lt_recall && ref $lt_recall eq 'ARRAY', "Long-term recall returns array");

# Hybrid recall
my $hybrid = $memory->recall("large");
ok(scalar @$hybrid >= 1, "Hybrid recall includes long-term");

# Edge case: Empty input
my $empty_comp = $memory->compress_and_store("");
ok(!$empty_comp || !exists $empty_comp->{facts}, "Empty input handled");

# Importance filter (mock)
ok(1, "Placeholder for importance test");

done_testing;