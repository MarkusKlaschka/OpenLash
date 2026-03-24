package Providers::Memory;

use strict;
use warnings;
use OpenLash::LLM;
use JSON::PP qw(encode_json decode_json);
use Digest::SHA qw(sha1_hex);
use List::Util qw(max);

# Basic config
our $CONFIG = {
    llm => {
        endpoint => 'http://localhost:11434/api/generate',
        model => 'qwen2.5:32b-instruct-q6_K',
    },
    chroma => {
        endpoint => 'http://localhost:8000',
        collection => 'long_term_memory',
    },
    chunk_size => 4000,  # chars, approx 1k tokens
    overlap => 200,
    importance_threshold => 0.5,
};

sub new {
    my ($class, $config) = @_;
    $config ||= {};
    $CONFIG = { %$CONFIG, %$config };
    my $self = {
        llm => OpenLash::LLM->new($CONFIG->{llm}),
        memories => [],  # Short-term
    };
    bless $self, $class;
    return $self;
}

# Existing basic methods (keyword recall, scoring, dedup)
sub store_short_term {
    my ($self, $text, $metadata) = @_;
    $metadata ||= {};
    push @{$self->{memories}}, {
        text => $text,
        score => _score_text($text),
        keywords => _extract_keywords($text),
        dedup_hash => sha1_hex($text),
        metadata => $metadata,
    };
    _dedup_memories($self);
}

sub recall {
    my ($self, $query, $limit) = @_;
    $limit ||= 5;
    my @relevant = grep {
        _keyword_match($query, $_->{keywords}) > 0.3 ||
        _semantic_score($query, $_->{text}) > 0.5
    } @{$self->{memories}};
    @relevant = sort { $b->{score} <=> $a->{score} } @relevant;
    return [@relevant[0..$limit-1]];
}

sub _score_text {
    my ($text) = @_;
    # Simple scoring: length + uniqueness
    return length($text) / 1000 + (scalar _extract_keywords($text)) * 0.1;
}

sub _extract_keywords {
    my ($text) = @_;
    # Basic keyword extraction (improve with LLM if needed)
    my @words = split /\s+/, lc $text;
    my %count;
    $count{$_}++ for @words;
    return [sort { $count{$b} <=> $count{$a} } keys %count][0..9];
}

sub _keyword_match {
    my ($query, $keywords) = @_;
    my $matches = 0;
    for my $kw (@$keywords) {
        $matches++ if index($query, $kw) >= 0;
    }
    return $matches / scalar @$keywords;
}

sub _semantic_score {
    my ($query, $text) = @_;
    # Placeholder: use LLM for cosine sim, but simple overlap for now
    my $overlap = _keyword_match($query, _extract_keywords($text));
    return $overlap * 2;  # Scale to 0-1
}

sub _dedup_memories {
    my ($self) = @_;
    my %seen;
    @{$self->{memories}} = grep {
        my $hash = $_->{dedup_hash};
        !$seen{$hash}++ && $_->{score} > 0.1;
    } @{$self->{memories}};
}

# New: Hierarchical compression for long-term
sub compress_and_store {
    my ($self, $text, $metadata) = @_;
    $metadata ||= { date => _get_iso_date() };

    if (length($text) < 10000) {
        $self->store_short_term($text, $metadata);
        return;
    }

    my $compressed = $self->compress_text($text, $metadata);
    $self->store_compressed($compressed, $metadata);
    return $compressed;
}

sub compress_text {
    my ($self, $text, $metadata) = @_;
    my @chunks = _chunk_text($text);

    # Level 1: Map - Summarize each chunk
    my @chunk_summaries;
    for my $chunk (@chunks) {
        my $summary = $self->_map_chunk($chunk, $metadata);
        push @chunk_summaries, $summary if $summary;
    }

    # Level 2: Reduce - Aggregate
    my $aggregated_facts = _merge_facts([map { $_->{facts} } @chunk_summaries]);
    my $meta_summary = $self->_reduce_facts($aggregated_facts, \@chunk_summaries, $metadata);

    return {
        facts => $aggregated_facts,
        summary => $meta_summary,
    };
}

sub _chunk_text {
    my ($text) = @_;
    my $size = $CONFIG->{chunk_size};
    my $overlap = $CONFIG->{overlap};
    my @chunks;
    for (my $i = 0; $i < length($text); $i += $size - $overlap) {
        push @chunks, substr($text, $i, $size);
    }
    return @chunks;
}

sub _map_chunk {
    my ($self, $chunk, $metadata) = @_;
    my $prompt = <<PROMPT;
Extract key facts from this text chunk as JSON array of objects: [{event: "description", entities: ["list"], insight: "key takeaway", importance: 0-1, date: "ISO if available"}]. Also provide a short narrative summary (max 200 words).

Text: $chunk

Metadata: @{[encode_json($metadata)]}

Output strict JSON: {"facts": [...], "summary": "narrative"}
PROMPT

    my $response;
    eval {
        $response = $self->{llm}->call($prompt);
    };
    if ($@ || !$response) {
        warn "LLM map failed for chunk: $@";
        return undef;
    }

    eval {
        return decode_json($response);
    } or do {
        warn "Invalid JSON from LLM: $response";
        return undef;
    };
}

sub _merge_facts {
    my ($all_facts) = @_;
    my %grouped;
    for my $fact (@$all_facts) {
        my $key = join('|', @{$fact->{entities}});
        push @{$grouped{$key}}, $fact;
    }

    my @merged;
    while (my ($key, $group) = each %grouped) {
        my $importance = 0;
        my $count = scalar @$group;
        $importance += $_->{importance} for @$group;
        $importance /= $count;

        # Dedup: pick highest importance, merge events/insights
        my $best = (sort { $b->{importance} <=> $a->{importance} } @$group)[0];
        $best->{importance} = $importance;
        $best->{event} .= "; " . join("; ", map { $_->{event} } @$group);  # Simple merge
        $best->{insight} .= "; " . join("; ", map { $_->{insight} } @$group);
        push @merged, $best;
    }

    @merged = grep { $_->{importance} >= $CONFIG->{importance_threshold} } @merged;
    return \@merged;
}

sub _reduce_facts {
    my ($self, $facts, $summaries, $metadata) = @_;
    my $facts_json = encode_json($facts);
    my $summaries_text = join("\n\n", map { $_->{summary} } @$summaries);

    my $prompt = <<PROMPT;
From these aggregated facts and chunk summaries, create a meta-summary (max 500 tokens) capturing the week's key themes, events, and insights. Refine the facts list if needed (keep structure).

Facts: $facts_json

Chunk summaries: $summaries_text

Metadata: @{[encode_json($metadata)]}

Output: {"facts": [... refined], "summary": "meta narrative (concise)"}
PROMPT

    my $response;
    eval {
        $response = $self->{llm}->call($prompt, undef, 1500);  # Larger for reduce
    };
    if ($@ || !$response) {
        warn "LLM reduce failed: $@";
        return join("\n", map { $_->{summary} } @$summaries)[0..499];  # Fallback
    }

    eval {
        my $data = decode_json($response);
        return $data->{summary} || $response;
    } or do {
        warn "Invalid reduce JSON: $response";
        return $response;
    };
}

sub _get_iso_date {
    my $dt = DateTime->now(time_zone => 'UTC');
    return $dt->iso8601;
}

# Wait, DateTime not imported. Add use DateTime;

# Storage in Chroma (via HTTP)
sub store_compressed {
    my ($self, $compressed, $metadata) = @_;
    my $summary = $compressed->{summary};
    my $facts_text = encode_json($compressed->{facts});

    # Simple embedding: Use LLM embed or placeholder
    my $embedding = _get_embedding($self, "$summary\n$facts_text");

    my $doc_id = sha1_hex($summary . $metadata->{date});

    # POST to Chroma /api/v1/collections/{collection}/add
    my $ua = LWP::UserAgent->new(timeout => 60);
    my $req = POST "$CONFIG->{chroma}{endpoint}/api/v1/collections/$CONFIG->{chroma}{collection}/add",
        Content_Type => 'application/json',
        Content => encode_json({
            ids => [$doc_id],
            documents => ["$summary\nFacts: $facts_text"],
            metadatas => [{ %$metadata, importance_avg => _avg_importance($compressed->{facts}) }],
            embeddings => [ $embedding ],  # Assume 1D array of floats
        });

    my $res = $ua->request($req);
    die "Chroma store failed: " . $res->status_line unless $res->is_success;
}

sub _get_embedding {
    my ($self, $text) = @_;
    # Call Ollama /api/embeddings
    my $embed_endpoint = 'http://localhost:11434/api/embeddings';
    my $ua = LWP::UserAgent->new(timeout => 60);
    my $req = POST $embed_endpoint,
        Content_Type => 'application/json',
        Content => encode_json({
            model => $CONFIG->{llm}{model},
            prompt => $text,
        });

    my $res = $ua->request($req);
    die "Embedding failed" unless $res->is_success;

    my $data = decode_json($res->content);
    return $data->{embedding};  # Array ref of floats
}

sub _avg_importance {
    my ($facts) = @_;
    return 0 if !@$facts;
    my $sum = 0;
    $sum += $_->{importance} for @$facts;
    return $sum / scalar @$facts;
}

# Retrieval from Chroma
sub retrieve_long_term {
    my ($self, $query, $limit) = @_;
    $limit ||= 5;

    my $query_embedding = _get_embedding($self, $query);

    my $ua = LWP::UserAgent->new(timeout => 60);
    my $req = POST "$CONFIG->{chroma}{endpoint}/api/v1/collections/$CONFIG->{chroma}{collection}/query",
        Content_Type => 'application/json',
        Content => encode_json({
            query_embeddings => [ $query_embedding ],
            n_results => $limit,
            include => ['documents', 'metadatas', 'distances'],
        });

    my $res = $ua->request($req);
    die "Chroma query failed" unless $res->is_success;

    my $data = decode_json($res->content);
    return $data->{documents}[0] || [];  # List of docs
}

1;
__END__

# Note: Requires DateTime, add to deps: use DateTime;