#!/usr/bin/perl

use strict;
use warnings;
use WebServer;
use WebUI;
use WebUI;
use lib 'OpenLash/lib';
use OpenLash::Log qw(OLinfo);

# Initialize logger
my $logger = Log->new();

$logger->OLinfo("Starting webserver script");

# Create and start the web server
my $server = WebServer->new(
    port => 443,
    cert_file => 'cert.pem',
    key_file => 'key.pem'
);

# Integrate WebUI - assuming it's hooked in WebServer

$server->start();

