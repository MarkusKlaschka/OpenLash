package OpenLash;
use strict; use warnings;
use Path::Tiny;
use DBI;
use lib './';
use OpenLash::LLM;
use OpenLash::Comm;
use Data::Dumper;
use JSON::PP qw(decode_json encode_json);

# ... (rest of the file remains, but add DESTROY for cleanup)
sub DESTROY {
    my $self = shift;
    $self->{dbh}->disconnect if $self->{dbh};
    $self->{comm}->stop if $self->{comm} && $self->{comm}->can('stop');
}

1;
