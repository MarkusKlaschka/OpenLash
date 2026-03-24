package OpenLash::Config;

use strict;
use warnings;
use JSON::XS;
use File::Spec;

our $VERSION = '0.01';

sub load {
    my ($class, $provider) = @_;
    INFO "Loading config for provider: $provider";
    my $file = File::Spec->catfile('providers', "$provider.json");
    open my $fh, '<', $file or die "Cannot open $file: $!";
    my $json = do { local $/; <$fh> };
    close $fh;
    my $config = JSON::XS->new->decode($json);

    # Env var overrides
    for my $key (keys %$config) {
        my $env_key = uc("OPENLASH_${provider}_$key");
        if (exists $ENV{$env_key}) {
            $config->{$key} = $ENV{$env_key};
        }
    }

    # Basic validation
    die "Missing 'api_key' in config" unless $config->{api_key};

    return $config;
}

1;

__END__

=head1 NAME

OpenLash::Config - Unified configuration loader for providers

=head1 SYNOPSIS

  use OpenLash::Config;
  my $config = OpenLash::Config->load('openai');

=head1 DESCRIPTION

Loads and validates provider JSON configs, with env var overrides.

