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
 my ($self, $system, $messages, $model_name) = @_;
 INFO "Calling LLM with model: $model_name";
 $model_name ||= $self->{model};

 my $endpoint = $self->{endpoint} =~ s/generate/chat/r; # /api/chat instead of /api/generate
 my $req = POST $endpoint,
 Content_Type => 'application/json',
 Content => encode_json({
 model => $model_name || $self->{model},
 messages => [
 { role => "system", content => $system },
 @$messages
 ],
 stream => JSON::PP::false,
 options => { temperature => 0.3, top_p => 0.9 },
 # tools can be added here later (Ollama supports them)
 });

 my $res = $self->{ua}->request($req);
 die "LLM call failed: " . $res->status_line unless $res->is_success;

 my $data = decode_json($res->content);
 return $data; # now returns the full chat response (with tool_calls when supported)
 }

1;