#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Memory;

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },
    chroma => { endpoint => 'mock://' },
    md_dir => 'test_md',
};

my $memory = Memory->new($config);

# Test command processing
my $remember = $memory->process_command("Remember this: Important fact about Perl.");
is($remember, "Remembered: Important fact about Perl.", "Processes remember command");
ok(scalar @{$memory->{memories}{working}} >= 1, "Stores from command");

my $important = $memory->process_command("This was important: Important fact about Perl.");
is($important, "Marked as important: Important fact about Perl.", "Marks important");

my $forget = $memory->process_command("Forget this: Low note.");
is($forget, "Forgot: Low note.", "Processes forget");

my $review = $memory->process_command("Review memory: Perl");
like($review, qr/Memory Review/, "Generates review");

# Test MD export/import
$memory->store("Test entry for MD.", { importance => 0.6 });
$memory->consolidate;
my $md_file = path($config->{md_dir})->child('daily-log.md');
ok(-e $md_file, "Exports to daily-log.md");
ok($md_file->slurp =~ /Test entry/, "Content in MD");

# Load from MD
my $new_mem = Memory->new($config);
ok(scalar @{$new_mem->{memories}{working}} >= 1, "Imports from MD on load");

# User profile
$memory->store("User likes coffee.", { tags => ['user'] });
$memory->consolidate;
my $profile_file = path($config->{md_dir})->child('user-profile.md');
ok(-e $profile_file, "Exports user profile");

# Project notes (default)
$memory->store("Project note.", { project_id => 'OpenLash' });
$memory->consolidate;
my $project_file = path($config->{md_dir})->child('project-notes.md');
ok(-e $project_file, "Exports project notes");

done_testing;