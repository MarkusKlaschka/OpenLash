package OpenLash::Server;
use strict; use warnings;
use IO::Socket::UNIX;
use IO::Socket::INET;
use IO::Select;
use OpenLash;

sub new {
	my ($class, %args) = @_;
	my $self = bless {
		socket_path => $args{socket} || "/tmp/OpenLash.sock",
		port => $args{port},
		agent	   => $args{agent},
		running	 => 0,
	}, $class;
	return $self;
}

sub start {
	my $self = shift;
	if ($self->{port}) {
		$self->{sock} = IO::Socket::INET->new(
			LocalAddr => '0.0.0.0',
			LocalPort => $self->{port},
			Proto     => 'tcp',
			Listen    => 5,
			Reuse     => 1,
		) or die "Cannot open TCP socket on port $self->{port}: $!";
		print "OpenLash Daemon running on port $self->{port}\n";
	} else {
		unlink $self->{socket_path} if -e $self->{socket_path};
		$self->{sock} = IO::Socket::UNIX->new(
			Local  => $self->{socket_path},
			Type   => SOCK_STREAM,
			Listen => 5
		) or die "Kann Socket nicht öffnen: $!";
		print "OpenLash Daemon läuft – Socket: $self->{socket_path}\n";
	}
	$self->{running} = 1;

	my $select = IO::Select->new($self->{sock});
	while ($self->{running}) {
		my @ready = $select->can_read(1);
		for my $s (@ready) {
			if ($s == $self->{sock}) {
				my $client = $self->{sock}->accept;
				$self->handle_client($client);
			}
		}
	}
}

sub handle_client {
	my ($self, $client) = @_;
	while (my $line = <$client>) {
		chomp $line;
		last if $line eq "quit";
		if ($line =~ /^ask:(.+)$/) {
			my $answer = $self->{agent}->ask($1);
			print $client "$answer\n";
		} elsif ($line eq "status") {
			print $client "Daemon läuft\n";
		} else {
			print $client "Unbekannter Befehl\n";
		}
	}
	close $client;
}

sub stop {
	my $self = shift;
	$self->{running} = 0;
	if ($self->{sock}) {
		$self->{sock}->close();
	}
	if (!defined $self->{port} && $self->{socket_path} && -e $self->{socket_path}) {
		unlink $self->{socket_path};
	}
}

1;