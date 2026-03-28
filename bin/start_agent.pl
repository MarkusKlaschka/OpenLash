#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib/perl';
use OpenLash::Server;

my  = OpenLash::Server->new(5555);
->listen();
EOF && chmod +x bin/start_agent.pl && git add bin/start_agent.pl
