#!/usr/bin/perl
use strict;
use warnings;
use lib './';

use OpenLash::Server;
use OpenLash;
use OpenLash::Comm;

# Load real config (no more hardcoded mess)
my $comm = OpenLash::Comm->new();
$comm->load_config('connections.json') if -e 'connections.json';

my $agent = OpenLash->new(
 workspace => '/tmp/OpenLash', # consistent key
 comm => $comm,
 default_channel => 'OpenLashTeam'
);

my $server = OpenLash::Server->new(agent => $agent);
$server->start;
);

my $agent = OpenLash->new(
 workspace => $workspace,
 comm => $comm,
 default_channel => $default_channel
);

my $server = OpenLash::Server->new(agent => $agent);
$server->start;