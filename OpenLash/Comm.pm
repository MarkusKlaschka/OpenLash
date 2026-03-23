#
# last edit: 2026-03-21
package OpenLash::Comm;
use strict;
use warnings;
use Telegram::Bot;
use Data::Dumper;

sub new {
	my ($class, %args) = @_;
	my $self = bless {
		channels => $args{channels}, # || "/tmp/myclaw.sock",
		handlers => $args{handlers},
		token => $args{token},
	}, $class;

#	foreach my $c ($args{channels}) {
#		$self->add_channel($args{name}, $args{type}, $c);
#	}
	return $self;
}

sub add_channel {
	my ($self, $name, $type, $config) = @_;
	if ($type eq 'telegram') {
		die "TELEGRAM_TOKEN missing!" unless $self->{token};
		$self->{channels}{$name} = {
			type	=> 'telegram',
			bot	 => Telegram::Bot->new(token => $self->{token}),
			chat_id => $config->{chat_id} || 'default'
		};
	} elsif ($type eq 'cli') {
		$self->{channels}{$name} = { type => 'cli' };
	} elsif ($type eq 'irc') {
		$self->{channels}{$name} = { type => 'irc', config => $config };
	} else {
		die "Unknown channel type: $type";
	}
}

sub load_config {
	my ($self, $file) = @_;
	# TODO: missing completely...
}

sub send {
	my ($self, $channel_name, $text) = @_;
	my $ch = $self->{channels}{$channel_name} or return;
	if ($ch->{type} eq 'telegram') {
		$ch->{bot}->sendMessage({chat_id => $ch->{chat_id}, text => $text});
	} elsif ($ch->{type} eq 'cli') {
		print "[$channel_name] $text\n";
	}
}

sub register_handler {
	my ($self, $callback) = @_;
	push @{$self->{handlers}}, $callback;
}

sub start_listening {
	my $self = shift;
	# Telegram polling
	for my $name (keys %{$self->{channels}}) {
		my $ch = $self->{channels}{$name};
		if ($ch->{type} eq 'telegram') {
			$ch->{bot}->listen(sub {
				my $msg = shift;
				$_->($name, $msg->{text}) for @{$self->{handlers}};
			});
		}
	}
}

1;
