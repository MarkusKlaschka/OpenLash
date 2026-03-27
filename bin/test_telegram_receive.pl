#!/usr/bin/perl

use strict;
use warnings;
use lib 'OpenLash/lib', 'OpenLash/Providers';
use OpenLash::Providers::Telegram;
use Data::Dumper;

my $tg = OpenLash::Providers::Telegram->new(token => $ENV{TELEGRAM_API});

my $updates = $tg->get_updates({ offset => -1 });  # Get last update

print Dumper($updates);

if ($updates->{ok}) {
    foreach my $update (@{$updates->{result}}) {
        if ($update->{message} && $update->{message}->{text} =~ m|/start|) {
            my $chat_id = $update->{message}->{chat}->{id};
            my $user = $update->{message}->{from}->{username} || $update->{message}->{from}->{first_name};
            if ($user eq 'MorganCarter') {
                print "Received /start from $user in chat $chat_id\n";
                $tg->send_message($chat_id, "Hello Morgan! OpenLash Telegram bot is online. Received your /start command.");
            }
        }
    }
}