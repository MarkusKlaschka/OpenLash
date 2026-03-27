#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use JSON::PP;

my  = shift || 'Test query';
my  = IO::Socket::INET->new(PeerAddr => 'localhost', PeerPort => 5555, Proto => 'tcp') or die Cannot connect: ;
print  encode_json({query => }) . n;
my  = <>;
print decode_json()->{result} . n;
close ;
EOF && chmod +x bin/cli.pl && git add bin/cli.pl && perl bin/cli.pl 'Hello agent'
