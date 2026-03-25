package providers::discord;

use strict;
use warnings;

sub new {
    my ($class, $config) = @_;
    my $self = { config => $config };
    bless $self, $class;
    return $self;
}

sub send_message {
    my ($self, $message) = @_;
    # Mock or actual Discord API call
    print "Sending to Discord: $message\n";
}

1;
