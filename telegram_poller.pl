#!/usr/bin/perl

use strict;
use warnings;
use lib 'OpenLash/Providers';
use OpenLash::Providers::Telegram;
use Data::Dumper;

my $tg = OpenLash::Providers::Telegram->new(token => $ENV{TELEGRAM_API});

my $last_update_id = 0;

while (1) {
    my $updates = $tg->get_updates({ offset => $last_update_id + 1, timeout => 30 });
    if ($updates->{ok}) {
        foreach my $update (@{$updates->{result}}) {
            $last_update_id = $update->{update_id};
            if ($update->{message} && $update->{message}->{text} =~ m|/start|) {
                my $chat_id = $update->{message}->{chat}->{id};
                my $user = $update->{message}->{from}->{username} || $update->{message}->{from}->{first_name};
                if ($user eq 'MorganCarter') {
                    print "Received /start from $user in chat $chat_id\n";
                    $tg->send_message($chat_id, "Hello Morgan! OL_Alfred2_bot is online and received your /start.");
                }
            }
        }
    }
    sleep 1;  # Avoid tight loop
}