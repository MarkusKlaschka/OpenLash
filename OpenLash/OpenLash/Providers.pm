package OpenLash::Providers;

use strict;
use warnings;
use JSON::XS;

sub load_plugins {
    my ($config_file) = @_;
    my $config = decode_json( do { local $/; open my $fh, '<', $config_file; <$fh> } );
    my @plugins;
    for my $plugin (@{$config->{plugins}}) {
        require $plugin->{module};
        push @plugins, $plugin->{module}->new($plugin->{config});
    }
    return @plugins;
}

1;
