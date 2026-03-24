#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use lib './OpenLash';
use OpenLash;
use OpenLash::Server;

my $socket_path = '/tmp/OpenLash.sock';
my $port;

GetOptions(
    'socket=s' => \$socket_path,
    'port=i' => \$port,
) or die "Usage: $0 [--socket=path] [--port=number]\n";

my $agent = OpenLash->new();

my %args = (agent => $agent);
if ($port) {
    $args{port} = $port;
} else {
    $args{socket} = $socket_path;
}

my $server = OpenLash::Server->new(%args);

$SIG{INT} = sub {
    $server->stop();
    exit 0;
};

$server->start();