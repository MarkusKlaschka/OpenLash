package OpenLash::Server;

use strict;
use warnings;
use IO::Socket::INET;
use Protocol::WebSocket::Server;  # Assuming installed
use JSON;

sub new {
    my ($class, %args) = @_;
    my $self = { agent => $args{agent} };
    bless $self, $class;
    return $self;
}

sub start {
    my ($self) = @_;

    my $sock = IO::Socket::INET->new(
        LocalPort => 8080,
        Proto     => 'tcp',
        Listen    => 5,
        Reuse     => 1
    ) or die "Cannot create socket: $!";

    print "Server started on port 8080\n";

    while (my $client = $sock->accept()) {
        my $ws = Protocol::WebSocket::Server->new(socket => $client);

        $ws->on('connect' => sub {
            print "Client connected\n";
        });

        $ws->on('message' => sub {
            my ($ws, $frame) = @_;
            my $msg = $frame->payload;
            # Proxy to agent or providers, e.g., Telegram
            # For demo, echo back
            $ws->send_message({ type => 'echo', content => $msg });
        });

        $ws->on('disconnect' => sub {
            print "Client disconnected\n";
        });

        $ws->serve;
    }
}

1;