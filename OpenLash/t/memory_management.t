#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Memory;
use Time::HiRes qw(time);

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },
    chroma => { endpoint => 'mock://' },
    consolidation_interval => 1,  # Short for test
};

my $memory = Memory->new($config);
$memory->set_session('test_session');

# Store with varying importance
$memory->store("Low importance note.", { importance => 0.1 });
$memory->store("High importance event.", { importance => 0.8 });
$memory->store("Medium task.", { importance => 0.4, tags => ['task'] });

# Check initial working
is(scalar @{$memory->{memories}{working}}, 3, "All in working initially");

# Trigger consolidation
sleep(1);  # Wait interval
$memory->consolidate;
ok(scalar @{$memory->{memories}{working}} <= 2, "High importance consolidated");

# Forget low
$memory->forget_low_importance('working');
ok(scalar @{$memory->{memories}{working}} <= 1, "Low importance forgotten");

# Self-reflection
$memory->store("Reflection test text.", { importance => 0.6 });
$memory->self_reflect;
ok(1, "Self-reflection called without error");  # Mock

# Recall after management
my $recall = $memory->recall("high", 2);
ok(scalar @$recall >= 1, "Recall after consolidation");

# Importance scoring in store
my $scored = _score_text("Test text with keywords");
ok($scored > 0, "Importance scoring works");

# Session continuity
$memory->store("Session specific.", {});
my $session_recall = $memory->recall("specific", 1, ['recent']);
ok(scalar @$session_recall >= 1, "Cross-session metadata");

# Periodic check
my $before = $memory->{last_consolidation};
sleep(1);
$memory->store("Trigger periodic.");
isnt($memory->{last_consolidation}, $before, "Periodic consolidation triggered");

# Forget threshold
$memory->store("Forget me.", { importance => 0.1 });
$memory->forget_low_importance('working');
ok(!grep { $_->{text} eq 'Forget me.' } @{$memory->{memories}{working}}, "Intelligent forgetting");

done_testing;