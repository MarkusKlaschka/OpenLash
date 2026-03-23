package OpenLash::Plugins;
use strict; use warnings;
use Path::Tiny;
use HTTP::Tiny;  # For weather fetch

sub new {
    my ($class, %args) = @_;
    bless { plugins => [] }, $class;   # Array von geladenen Plugin-Objekten
}

# Perl-Plugin laden (Datei muss eine register() Funktion oder Klasse haben)
sub load_plugin {
    my ($self, $file) = @_;
    require $file;                      # lädt die .pm-Datei
    my $plugin = do $file;              # oder eval, wenn du Klassen willst
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

# Run a plugin tool (stub)
sub run_plugin_tool {
    my ($self, $name, $args) = @_;
    my $plugin = (grep { $_->can('get_name') && $_->get_name eq $name } @{$self->{plugins}})[0] or return "Plugin $name not found";
    
    if ($name eq 'weather') {
        my $location = $args->{location} || 'auto';
        my $http = HTTP::Tiny->new;
        my $res = $http->get("https://wttr.in/$location?format=3");
        return $res->{success} ? $res->{content} : "Weather fetch failed";
    }
    
    # Add more plugins here
    return "Plugin $name executed (stub)";
}

# Example Weather plugin stub (loaded via load_plugin)
package OpenLash::Weather;
sub new { bless {}, shift }
sub register { my ($self, $agent) = @_; $self->{agent} = $agent; }
sub get_name { 'weather' }
sub get_tools { [{name => 'weather', desc => 'Get weather', params => {location => {type => 'string'}}}] }

1;
