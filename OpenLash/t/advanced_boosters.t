#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 12;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Memory;

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },
    chroma => { endpoint => 'mock://' },
};

my $memory = Memory->new($config);
$memory->set_session('test_session');

# Test multi-query
my @queries = $memory->_generate_multi_queries("Perl memory management");
ok(scalar @queries >= 2, "Generates multiple queries");

# Test HyDE
my $hyde = $memory->_generate_hyde("Best Perl practices");
ok(length($hyde) > 100, "Generates hypothetical document");

# Test clustering
$memory->store("Fact1 about Perl.", {});
$memory->store("Fact2 similar to Perl.", {});
my @results = ({ keywords => ['perl'] }, { keywords => ['perl', 'fact'] });
my @clustered = $memory->_cluster_results(\@results, 2);
ok(scalar @clustered == 2, "Clusters results");

# Test evaluation
my @eval_res = $memory->_evaluate_relevance("Perl", [{ text => "Perl fact" }], 0.5);
ok(scalar @eval_res >= 1, "Evaluates relevance");

# Cross-session continuity
$memory->store("Session memory.", {});
$memory->_save_session_history;
my $new_mem = Memory->new($config);
$new_mem->set_session('test_session');
my $recall = $new_mem->recall("memory", 1);
ok(scalar @$recall >= 1, "Loads cross-session history");

# Compression clustering
my $compressed = $memory->compress_text("Multiple facts: Perl is great; OpenLash uses Perl.", {});
ok(exists $compressed->{facts} && ref $compressed->{facts} eq 'ARRAY', "Clusters in compression");

# Advanced fuse (placeholder test)
my %all_res = ( q1 => [{ score => 0.8 }], q2 => [{ score => 0.9 }] );
my @fused = $memory->_advanced_fuse(\%all_res, 1);
ok(scalar @fused >= 1, "Advanced fusion");

# Similarity
ok(_similarity({ keywords => ['perl'] }, { keywords => ['perl'] }) == 1, "Similarity 1 for identical");

# Full advanced recall
my $adv_recall = $memory->recall("Perl", 2);
ok(scalar @$adv_recall >= 1, "Advanced recall chain works");

# Save history persistence
ok(-e $config->{session_history_file}, "Saves session history file");

done_testing;