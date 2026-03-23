package OpenLash::Plugins;
use strict; use warnings;
use Path::Tiny;

sub new {
	my ($class, %args) = @_;
	bless { plugins => [] }, $class;   # Array von geladenen Plugin-Objekten
}

# Perl-Plugin laden (Datei muss eine register() Funktion oder Klasse haben)
sub load_plugin {
	my ($self, $file) = @_;
	require $file;					 # lädt die .pm-Datei
	my $plugin = do $file;			 # oder eval, wenn du Klassen willst
	push @{$self->{plugins}}, $plugin if $plugin;
}

# Alle Plugins durchlaufen und neue Tools/Hooks registrieren
sub register_all {
	my ($self, $agent) = @_;
	$_->register($agent) for @{$self->{plugins}};   # jedes Plugin bekommt den Agent
}

sub get_extra_tools {
	my $self = shift;
	return map { $_->get_tools() || () } @{$self->{plugins}};
}

1;
