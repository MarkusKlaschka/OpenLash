#!/usr/bin/perl
use strict;
use warnings;
use Protocol::WebSocket::Client;
use IO::Socket::SSL;

my $ws = Protocol::WebSocket::Client->new(url => 'ws://localhost:8080');

$ws->on('connect' => sub {
    print "Connected to server\n";
    $ws->send("Hello, WebSocket!");
});

$ws->on('message' => sub {
    my ($ws, $message) = @_;
    print "Received: $message\n";
});

$ws->on('error' => sub {
    my ($ws, $error) = @_;
    print "Error: $error\n";
});

$ws->connect;

# Simple loop to keep it running
while (1) {
    $ws->read;
}