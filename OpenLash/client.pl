use IO::Socket::UNIX;
my $sock = IO::Socket::UNIX->new("/tmp/OpenLash.sock") or die;
print $sock "ask..:\n";
print while <$sock>;
