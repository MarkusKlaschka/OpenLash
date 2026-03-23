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

# Load per-provider JSON configs from dir
sub load_provider_configs {
    my ($self, $dir) = @_;
    $dir ||= 'providers';
    my $path = path($dir);
    return unless $path->exists;
    
    for my $json_file ($path->children(qr/\.json$/)) {
        my $data = decode_json($json_file->slurp);
        my $prov = $data->{provider};
        $self->add_provider($prov->{name}, %$prov) if $prov;
        
        for my $model (@{$data->{models} || []}) {
            $model->{provider} = $prov->{name};
            $self->add_model($model->{name}, %$model);
        }
    }
    return scalar keys %{$self->{providers}};
}

# Aufruf (verwendet Provider + Model-Metadaten)
sub call {
    my ($self, $system, $messages, $model_name) = @_;
    my $name = $model_name || $self->{default_model};
    my $model = $self->{models}{$name} or die "Model '$name' not found!";
    my $prov = $self->{providers}{$model->{provider}} or die "Provider missing!";

    # Security: Ensure env var is set
    my $key = $ENV{$prov->{key_env}};
    die "API key missing: Set $prov->{key_env}" unless $key;

    my $http = HTTP::Tiny->new;
    my $headers = $prov->{type} eq "anthropic"
        ? {"x-api-key" => $key, "anthropic-version" => "2023-06-01", "Content-Type" => "application/json"}
        : {"Authorization" => "Bearer $key", "Content-Type" => "application/json"};

    my $body = $prov->{type} eq "anthropic"
        ? {model => $name, max_tokens => $model->{max_tokens_out}, system => $system, messages => $messages}
        : {model => $name, messages => [{role => "system", content => $system}, @$messages], stream => "false", temperature => 0};

    # Rate limit: Adaptive sleep based on provider (e.g., 1s for xai, 0.5s others)
    my $rate_sleep = $prov->{name} eq 'xai' ? 1 : 0.5;
    sleep $rate_sleep;

    my $res = $http->post($prov->{base_url}, {headers => $headers, content => encode_json($body)});
    return decode_json($res->{content}) if $res->{success};
    die "LLM error: $res->{content}";
}

1;
al backoff stub
            $res = $http->post($prov->{base_url}, {headers => $headers, content => encode_json($body)});
        }
        return decode_json($res->{content}) if $res->{success};
    }
    die "LLM error: $res->{content} (status: $res->{status})";
}

1;
