package OpenLash::LLM;

use strict;
use warnings;
use LWP::UserAgent;
use JSON::PP qw(encode_json decode_json);
use HTTP::Request::Common;

sub new {
    my ($class, $config) = @_;
    my $self = {
        ua => LWP::UserAgent->new(timeout => 120),
        endpoint => $config->{endpoint} || 'http://localhost:11434/api/generate',
        model => $config->{model} || 'qwen2.5:32b-instruct-q6_K',
    };
    bless $self, $class;
    return $self;
}

sub call {
    my ($self, $prompt, $options, $max_tokens) = @_;
    $options ||= {};
    $max_tokens ||= 2048;

    my $req = POST $self->{endpoint},
        Content_Type => 'application/json',
        Content => encode_json({
            model => $self->{model},
            prompt => $prompt,
            options => {
                temperature => 0.3,
                top_p => 0.9,
                max_tokens => $max_tokens,
                %$options,
            },
        });

    my $res = $self->{ua}->request($req);
    die "LLM call failed: " . $res->status_line unless $res->is_success;

    my $data = decode_json($res->content);
    return $data->{response} || '';
}

1;