#!/usr/bin/perl

use strict;
use warnings;
use lib 'OpenLash/providers';
use OpenLash::Providers::Telegram;

my $token = $ENV{TELEGRAM_API} || die "TELEGRAM_API not set";
my $tg = OpenLash::Providers::Telegram->new(token => $token);

# For testing - replace with actual chat_id
my $chat_id = 'YOUR_CHAT_ID_HERE';  # Ask user for this
my $message = 'Test message from OpenLash Telegram provider';

$tg->send_message($chat_id, $message);

print "Message sent!\n";