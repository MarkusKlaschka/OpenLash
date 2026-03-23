#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 15;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Memory;
use JSON::PP qw(decode_json);

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },  # Mock for tests
    chroma => { endpoint => 'mock://' },
};

my $memory = Memory->new($config);

# Store test data for modes
$memory->store("Working memory test about Perl bug fix.", { date => '2026-03-23T21:00:00Z', tags => ['task'] });
$memory->store("I met John at conference - episodic event.", { date => '2026-03-23T20:00:00Z' });
$memory->store("Perl is dynamic language - semantic fact.", { date => '2026-03-23T19:00:00Z' });
$memory->store("Lesson: Always test edge cases.", { date => '2026-03-23T18:00:00Z', importance => 0.8 });
$memory->store("To fix bug: run cpan install.", { date => '2026-03-23T17:00:00Z', tags => ['task'] });

# Test keyword retrieval
my $kw_results = $memory->_retrieve_keyword("Perl", 3);
ok(scalar @$kw_results >= 1, "Keyword retrieval finds Perl mentions");
is($kw_results->[0]{text}, "Working memory test about Perl bug fix.", "Correct keyword doc");

# Test semantic (mock assumes working has semantic sim)
my $sem_results = $memory->_retrieve_semantic("programming", 3);
ok(scalar @$sem_results >= 1, "Semantic retrieval works");

# Test recent
my $recent_results = $memory->_retrieve_recent("test", 3);
ok(scalar @$recent_results >= 1, "Recent retrieval works");

# Test entity (e.g., John)
my $entity_results = $memory->_retrieve_entity("John", 3);
ok(scalar @$entity_results >= 1, "Entity retrieval finds John");

# Test task
my $task_results = $memory->_retrieve_task("fix", 3);
ok(scalar @$task_results >= 1, "Task retrieval finds tasks");

# Test lessons
my $lessons_results = $memory->_retrieve_lessons("test", 3);
ok(scalar @$lessons_results >= 1, "Lessons retrieval finds high importance");

# Test full hybrid recall all modes
my $hybrid_all = $memory->recall("Perl fix", 5, ['all']);
ok(scalar @$hybrid_all >= 2, "Hybrid all modes returns multiple");
ok(exists $hybrid_all->[0]{rrf_score}, "RRF score present");

# Test specific modes
my $hybrid_specific = $memory->recall("John conference", 3, ['entity', 'recent']);
ok(scalar @$hybrid_specific >= 1, "Specific modes work");

# Test RRF fusion logic (simple check)
my %test_ranked = (
    1 => { keyword => { rank => 1 }, semantic => { rank => 3 } },
    2 => { keyword => { rank => 2 }, semantic => { rank => 1 } },
);
my @fused_test = $memory->_rrf_fuse(\%test_ranked, 2);
is(scalar @fused_test, 2, "RRF fuses correctly");
ok($fused_test[0]{rrf_score} > $fused_test[1]{rrf_score}, "Higher RRF score first");

# Edge: no results
my $empty_hybrid = $memory->recall("nonexistent", 1, ['all']);
ok(scalar @$empty_hybrid == 0 || $empty_hybrid->[0]{text} eq '', "Handles empty results");

# Multi-query like (but single for test)
done_testing;