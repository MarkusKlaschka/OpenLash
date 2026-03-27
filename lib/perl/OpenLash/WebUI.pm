package WebUI;

use strict;
use warnings;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->stringify;

our $VERSION = '0.1';

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

# Stub for handling UI requests
sub handle_ui_request {
    my ($self, $request) = @_;
    return "WebUI handling: $request";
}

1;

__END__

=head1 NAME

WebUI - Web UI Module for OpenLash

=head1 SYNOPSIS

  use WebUI;
  my $ui = WebUI->new();

=cut