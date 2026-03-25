# WebServer.pm - SSL Web Server Module for OpenClaw

package WebServer;

use strict;
use warnings;
use IO::Socket::SSL;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use OpenLash::Log qw(OLinfo OLlog);

our $VERSION = '0.1';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;

    $self->{port} = $args{port} || 443;
    $self->{cert_file} = $args{cert_file} || 'cert.pem';
    $self->{key_file} = $args{key_file} || 'key.pem';
    $self->{logger} = 'OpenLash::Log';  # Use functions directly

    return $self;
}

sub start {
    my ($self) = @_;

    OpenLash::Log::OLinfo("Starting SSL web server on port $self->{port}");

    my $server = IO::Socket::SSL->new(
        LocalPort => $self->{port},
        Listen    => 5,
        Reuse     => 1,
        SSL_cert_file => $self->{cert_file},
        SSL_key_file  => $self->{key_file},
        SSL_verify_mode => SSL_VERIFY_NONE,  # For simplicity; adjust for production
    ) or die "Cannot create SSL socket: " . IO::Socket::SSL::errstr();

    OpenLash::Log::OLinfo("SSL Server started and listening on port $self->{port}");

    while (my $client = $server->accept()) {
        $self->handle_request($client);
    }

    $server->close();
}

sub handle_request {
    my ($self, $client) = @_;

    use HTTP::Daemon::SSL;
    my $d = HTTP::Daemon::SSL->new(
        LocalPort => $self->{port},
        SSL_cert_file => $self->{cert_file},
        SSL_key_file => $self->{key_file},
    ) or die "Cannot create daemon: $!";
    
    while (my $c = $d->accept) {
        while (my $r = $c->get_request) {
            $self->handle_request($c, $r);
        }
        $c->close;
    }

    OpenLash::Log::OLlog('INFO', "Received request: $request from " . $client->peerhost());

    # Basic response (to be expanded with WebUI integration)
    my $response = HTTP::Response->new(RC_OK);
    $response->content("Hello from OpenClaw WebServer!");
    print $client $response->as_string();

    $client->close();
}

1;

__END__

=head1 NAME

WebServer - SSL Web Server for OpenClaw

=head1 SYNOPSIS

  use WebServer;
  my $server = WebServer->new(port => 443, cert_file => 'cert.pem', key_file => 'key.pem');
  $server->start();

=head1 DESCRIPTION

Starts an SSL web server using IO::Socket::SSL.

=cut
