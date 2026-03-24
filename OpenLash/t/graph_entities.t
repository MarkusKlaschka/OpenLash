#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 12;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Memory;
use JSON::PP qw(decode_json);

my $config = {
    llm => { endpoint => 'mock://', model => 'mock' },
    chroma => { endpoint => 'mock://' },
};

my $memory = Memory->new($config);

# Test entity extraction
my ($ents, $rels) = $memory->_extract_entities_relations("John works on ProjectX, which uses Perl.", {});
ok(scalar @$ents >= 2, "Extracts entities: John, ProjectX");
ok(scalar @$rels >= 1, "Extracts relations: John works_on ProjectX");

# Store with entities
$memory->store("John met Alice at OpenLash project meeting.", { project_id => 'OpenLash' });
ok(exists $memory->{graph}{entities}{John}, "Graph adds entity John");
ok(exists $memory->{graph}{entities}{Alice}, "Graph adds entity Alice");
ok(scalar @{$memory->{graph}{relations}} >= 1, "Adds relation met");

# Test graph query
my $related = $memory->_query_graph_entities(['John'], 5);
ok(scalar @$related >= 1, "Queries related entities");

# Test project-based store/recall
$memory->store("Project specific note for OpenLash.", { project_id => 'OpenLash' });
my $project_recall = $memory->recall("note", 1, ['all'], 'OpenLash');
ok(scalar @$project_recall >= 1, "Project-filtered recall");

# Enhance recall with related
my $enhanced = $memory->recall("meeting", 1);
ok(exists $enhanced->[0]{related_entities}, "Recall enhanced with related entities");

# Graph persistence (mock save/load)
$memory->_save_graph;
my $new_mem = Memory->new($config);
ok(scalar keys %{$new_mem->{graph}{entities}} > 0, "Graph persists");

# Relation dedup (add duplicate)
$memory->store("John met Alice again.", { project_id => 'OpenLash' });
ok(scalar @{$memory->{graph}{relations}} <= 2, "Deduplicates relations");

# Entity in recall
my $entity_recall = $memory->_retrieve_entity_graph("John", 2);
ok(scalar @$entity_recall >= 1, "Graph entity retrieval");

done_testing;