#!/usr/bin/perl
use strict; use warnings;
use FindBin '$RealBin';
use lib "$RealBin/..";
use lib './';
use OpenLash::LLM;
use OpenLash::Comm;
use OpenLash::Skills;
use OpenLash::Plugins;
use OpenLash::Memory;
use OpenLash::Lessons;
use OpenLash::Tasks;
use OpenLash;

my $llm	 = OpenLash::LLM->new();
my $comm	= OpenLash::Comm->new();
my $skills  = OpenLash::Skills->new();
my $plugins = OpenLash::Plugins->new();
my $memory  = OpenLash::Memory->new();
my $lessons = OpenLash::Lessons->new();
my $tasks   = OpenLash::Tasks->new();

$comm->add_channel('cli', 'cli');

my $agent = OpenLash->new(
    llm => $llm,
    comm => $comm,
    skills_obj => $skills,
    plugins_obj => $plugins,
    memory => $memory,
    lessons => $lessons,
    tasks => $tasks,
);

print "OpenLash CLI ready (exit zum Beenden)\n";
while (1) {
	print "> ";
	my $input = <STDIN>; chomp $input;
	last if $input eq "exit";
 try { $comm->handle_message('cli', $input) or print $agent->ask($input), "\n"; } catch { warn "Error: $_"; };
}
