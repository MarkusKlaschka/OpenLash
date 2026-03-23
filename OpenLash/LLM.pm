package OpenLash::LLM;
use strict; use warnings;
use JSON::PP;
use HTTP::Tiny;
use Path::Tiny;
use Data::Dumper;
sub new {
	my ($class) = @_;
	my $self = bless {
		providers => {},
		models	=> {},
		default_model => 'grok-4-1-fast',
	}, $class;

	# Standard-Provider (weitere per ->add_provider() hinzufügen)
	$self->add_provider('xai',	   base_url => 'https://api.x.ai/v1/chat/completions', console_url => 'https://console.x.ai',	   key_env => 'XAI_API_KEY',	   type => 'openai');
	$self->add_provider('anthropic', base_url => 'https://api.anthropic.com/v1/messages', console_url => 'https://console.anthropic.com', key_env => 'ANTHROPIC_API_KEY', type => 'anthropic');
	$self->add_provider('google',	base_url => 'https://generativelanguage.googleapis.com/v1beta/models', console_url => 'https://aistudio.google.com', key_env => 'GEMINI_API_KEY', type => 'google');
	$self->add_provider('openai',	base_url => 'https://api.openai.com/v1/chat/completions', console_url => 'https://platform.openai.com', key_env => 'OPENAI_API_KEY', type => 'openai');

	# Standard-Modelle (mit allen Metadaten)
	$self->add_model('grok-4-1-fast',	  provider => 'xai',	   max_tokens_in => 128000, max_tokens_out => 8192, cost_in_per_m => 0.50, cost_out_per_m => 2.00, has_reasoning => 0, performance => 95);
	$self->add_model('claude-3-5-sonnet',  provider => 'anthropic', max_tokens_in => 200000, max_tokens_out => 8192, cost_in_per_m => 3.00, cost_out_per_m => 15.00, has_reasoning => 1, performance => 98);
	$self->add_model('gemini-1.5-flash',   provider => 'google',	max_tokens_in => 1000000, max_tokens_out => 8192, cost_in_per_m => 0.35, cost_out_per_m => 1.05, has_reasoning => 0, performance => 92);
	$self->add_model('gpt-4o-mini',		provider => 'openai',	max_tokens_in => 128000, max_tokens_out => 16384, cost_in_per_m => 0.15, cost_out_per_m => 0.60, has_reasoning => 0, performance => 93);

	return $self;
}

sub add_provider {
	my ($self, $name, %p) = @_;
	$self->{providers}{$name} = \%p;
}

sub add_model {
	my ($self, $name, %m) = @_;
	$self->{models}{$name} = \%m;
}

sub set_default { $_[0]->{default_model} = $_[1] }

# JSON Import/Export
sub load_config { my ($self, $file) = @_; my $data = decode_json(path($file)->slurp); $self->add_provider($_->{name}, %{$_->{provider}}) for @{$data->{providers} || []}; $self->add_model($_->{name}, %$_) for @{$data->{models} || []}; }
sub save_config { my ($self, $file) = @_; path($file)->spew(encode_json({providers => [values %{$self->{providers}}], models => [values %{$self->{models}}]})); }

# Aufruf (verwendet Provider + Model-Metadaten)
sub call {
	my ($self, $system, $messages, $model_name) = @_;
	my $name = $model_name || $self->{default_model};
	my $model = $self->{models}{$name} or die "Modell '$name' nicht gefunden!";
	my $prov  = $self->{providers}{$model->{provider}} or die "Provider fehlt!";

	my $http = HTTP::Tiny->new;
	my $headers = $prov->{type} eq "anthropic"
		? {"x-api-key" => $ENV{$prov->{key_env}}, "anthropic-version" => "2023-06-01"}
		: {"Authorization" => "Bearer " . $ENV{$prov->{key_env}}};
	$headers->{"Content-Type"} = "application/json";

	my $body = $prov->{type} eq "anthropic"
		? {model => $name, max_tokens => $model->{max_tokens_out}, system => $system, messages => $messages}
		: {model => $name, messages => [{role=>"system", content=>$system}, @$messages],stream=>"false",temperature=>0};

	my $body_encoded = encode_json($body);
	$body_encoded =~ s/"false"/false/g;

	print "BE:$body_encoded\n";
	#print "H:".Dumper(\$headers)."\n";
	#print "B:".Dumper(\$body)."\n";
	my $res = $http->post($prov->{base_url}, {headers => $headers, content => $body_encoded});
	print Dumper(\$res);
	return decode_json($res->{content}) if $res->{success};
	die "LLM-Fehler: $res->{content}";
}

1;
