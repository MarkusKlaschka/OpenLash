package OpenLash::Providers::Telegram;

use strict;
use warnings;
use WWW::Telegram::BotAPI;
use OpenLash::Log qw(OLinfo OLdebug);

our $VERSION = '0.1';

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;

    $self->{token} = $args{token} || $ENV{TELEGRAM_API} or die "Telegram API token required";
    $self->{bot} = WWW::Telegram::BotAPI->new(token => $self->{token});

    OLinfo("Telegram provider initialized");

    return $self;
}

sub send_message {
    my ($self, $chat_id, $text) = @_;
    my $response = $self->{bot}->sendMessage({
        chat_id => $chat_id,
        text => $text
    });
    OLdebug("Sent message to $chat_id: $text");
    return $response;
}

sub get_updates {
    my ($self) = @_;
    my $updates = $self->{bot}->getUpdates();
    OLdebug("Retrieved updates");
    return $updates;
}

1;

__END__

=head1 NAME

OpenLash::Providers::Telegram - Telegram Provider for OpenLash

=head1 SYNOPSIS

  use OpenLash::Providers::Telegram;
  my $tg = OpenLash::Providers::Telegram->new(token => 'your_token');
  $tg->send_message('chat_id', 'Hello!');

=head1 DESCRIPTION

Handles Telegram bot interactions for OpenLash.

=cut