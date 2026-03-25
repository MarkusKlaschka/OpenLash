#!/usr/bin/perl

use strict;
use warnings;
use WebServer;
use WebUI;
use Log;  # Assuming Log.pm is available

# Initialize logger
my $logger = Log->new();

$logger->OLinfo("Starting webserver script");

# Create and start the web server
my $server = WebServer->new(
    port => 443,
    cert_file => 'cert.pem',
    key_file => 'key.pem'
);

# Integrate WebUI for handling requests
# Note: In a real setup, you'd hook WebUI into the request handler in WebServer.pm

$server->start();

