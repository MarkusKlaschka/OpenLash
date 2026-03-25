package providers::slack;

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
    # Mock or actual Slack API call
    print "Sending to Slack: $message\n";
}

1;
