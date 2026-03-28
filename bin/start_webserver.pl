#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib/perl';
use OpenLash::WebServer;

my  = OpenLash::WebServer->new(8080);
->run();
EOF && chmod +x bin/start_webserver.pl && git add bin/start_webserver.pl
