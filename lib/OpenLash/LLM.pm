package OpenLash::LLM;

use strict;
use warnings;
use LWP::UserAgent;
use JSON::PP qw(encode_json decode_json);
use HTTP::Request::Common;

our $DEFAULT_ENDPOINT = 'http://localhost:11434/api/generate';
our $DEFAULT_MODEL = 'qwen2.5:32b-instruct-q6_K';

sub new {
    my ($class, $config) = @_;
    $config ||= {};
    my $self = {
        endpoint => $config->{endpoint} || $DEFAULT_ENDPOINT,
        model => $config->{model} || $DEFAULT_MODEL,
        ua => LWP::UserAgent->new(
            timeout => 300,  # 5 min for large inferences
            agent => 'OpenLash/1.0',
        ),
    };
    bless $self, $class;
    return $self;
}

sub call {
    my ($self, $prompt, $system_prompt, $max_tokens) = @_;
    $max_tokens ||= 1024;
    $system_prompt ||= 'You are a precise memory compressor. Extract structured facts without hallucination.';

    # For Ollama /api/generate
    my $req = POST $self->{endpoint},
        Content_Type => 'application/json',
        Content => encode_json({
            model => $self->{model},
            prompt => "$system_prompt\n\nUser: $prompt",
            stream => 0,
            options => { num_predict => $max_tokens, temperature => 0.3 },
        });

    my $res = $self->{ua}->request($req);
    die "LLM call failed: " . $res->status_line unless $res->is_success;

    my $data = decode_json($res->content);
    return $data->{response} || '';
}

# Fallback for OpenAI-compatible (vLLM)
sub call_openai_compat {
    my ($self, $prompt, $system_prompt, $max_tokens) = @_;
    my $endpoint = $self->{endpoint} || 'http://localhost:8000/v1/chat/completions';
    $max_tokens ||= 1024;
    $system_prompt ||= 'You are a precise memory compressor. Extract structured facts without hallucination.';

    my $req = POST $endpoint,
        Content_Type => 'application/json',
        Content => encode_json({
            model => $self->{model},
            messages => [
                { role => 'system', content => $system_prompt },
                { role => 'user', content => $prompt },
            ],
            stream => false,
            max_tokens => $max_tokens,
            temperature => 0.3,
        });

    my $res = $self->{ua}->request($req);
    die "LLM call failed: " . $res->status_line unless $res->is_success;

    my $data = decode_json($res->content);
    return $data->{choices}[0]{message}{content} || '';
}

1;
__END__