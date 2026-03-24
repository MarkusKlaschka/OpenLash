#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 12;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Memory;
use JSON::PP qw(decode_json);

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },  # Mock for tests
    chroma => { endpoint => 'mock://' },
};

my $memory = Memory->new($config);

# Test classification
my $layer_working = $memory->_classify_layer("Current task: fix bug", {});
is($layer_working, 'working', "Classifies short-term as working");

my $layer_episodic = $memory->_classify_layer("I met John today at conference", {});
is($layer_episodic, 'episodic', "Classifies event as episodic");

my $layer_semantic = $memory->_classify_layer("Perl is a dynamic language", {});
is($layer_semantic, 'semantic', "Classifies fact as semantic");

my $layer_procedural = $memory->_classify_layer("To install: cpan Module", {});
is($layer_procedural, 'procedural', "Classifies howto as procedural");

# Test store working
$memory->store("Working memory test.", { date => '2026-03-23' });
my $working_recall = $memory->_recall_working("test", 5);
ok(scalar @$working_recall >= 1, "Stores and recalls working memory");

# Test store layered
$memory->store_layered("Episodic event test.", 'episodic', { date => '2026-03-23' });
my $episodic_recall = $memory->recall("event", 5, 'episodic');
ok(scalar @$episodic_recall >= 1, "Stores and recalls episodic layer");

# Test capacity eviction
my $large_working = "Item " x 200;
for (1..110) { $memory->store($large_working, { date => '2026-03-23' }); }
is(scalar @{$memory->{memories}{working}}, 100, "Evicts beyond working capacity");

# Test recall all layers
my $all_recall = $memory->recall("test", 5);
ok(scalar @$all_recall >= 1, "Recalls from all layers");

# Test fallback classification
$memory->{llm} = undef;  # Simulate failure
my $fallback = $memory->_classify_layer("Test fallback", {});
is($fallback, 'episodic', "Falls back to episodic");

# Compression with layer
my $compressed = $memory->compress_and_store("Large " x 3000, { date => '2026-03-23' }, 'semantic');
ok($compressed, "Compresses with layer");

# Multi-layer recall
my $multi = $memory->recall("large", 10, '');
ok(scalar @$multi >= 1, "Multi-layer hybrid recall");

done_testing;