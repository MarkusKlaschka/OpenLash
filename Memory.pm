package Memory;

use strict;
use warnings;
use JSON::PP qw(encode_json decode_json);
use Digest::SHA qw(sha1_hex);
use List::Util qw(max sum);
use LWP::UserAgent;
use HTTP::Request::Common;
use DateTime;
use Path::Tiny;
use lib 'lib';
use OpenLash::LLM;

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
    chunk_size => 4000,
    overlap => 200,
    importance_threshold => 0.5,
    layers => {
        working => { type => 'in_memory', capacity => 100 },
        episodic => { type => 'chroma', tags => ['event', 'timestamp'] },
        semantic => { type => 'chroma', tags => ['fact', 'concept'] },
        procedural => { type => 'chroma', tags => ['skill', 'howto'] },
    },
    rrf_k => 60,
    consolidation_interval => 3600,
    forget_threshold => 0.2,
    graph_file => 'entities_graph.json',
    md_dir => 'memory_md',
    md_files => {
        MEMORY => 'MEMORY.md',
        DAILY_LOG => 'daily-log.md',
        USER_PROFILE => 'user-profile.md',
        PROJECT_NOTES => 'project-notes.md',
    },
    advanced => {
        multi_query_count => 3,
        hyde_enabled => 1,
        cluster_size => 5,
        eval_threshold => 0.5,
    },
    session_history_file => 'session_history.json',  # For cross-session
};

sub new {
    my ($class, $config) = @_;
    $config ||= {};
    $CONFIG = { %$CONFIG, %$config };
    Path::Tiny->import(qw(path));
    path($CONFIG->{md_dir})->mkpath unless -d $CONFIG->{md_dir};
    my $self = {
        llm => OpenLash::LLM->new($CONFIG->{llm}),
        ua => LWP::UserAgent->new(timeout => 60),
        memories => {
            working => [],
        },
        chroma_providers => {},
        last_consolidation => 0,
        session_id => undef,
        graph => { entities => {}, relations => [] },
        project_memories => {},
        md_files => {},
        session_history => {},  # Load cross-session
    };
    bless $self, $class;
    $self->_load_graph;
    $self->_load_md_files;
    $self->_load_session_history;
    return $self;
}

sub _load_session_history {
    my $self = shift;
    if (-e $CONFIG->{session_history_file}) {
        my $data = decode_json(path($CONFIG->{session_history_file})->slurp);
        $self->{session_history} = $data;
        # Load previous session memories if session_id matches
        if ($self->{session_id} && exists $data->{$self->{session_id}}) {
            foreach my $entry (@{$data->{$self->{session_id}}}) {
                $self->store($entry->{text}, $entry->{metadata});
            }
        }
    }
}

sub _save_session_history {
    my $self = shift;
    $self->{session_history}{$self->{session_id}} ||= [];
    push @{$self->{session_history}{$self->{session_id}}}, {
        text => $_->{text},
        metadata => $_->{metadata},
    } for @{$self->{memories}{working}};
    path($CONFIG->{session_history_file})->spew(encode_json($self->{session_history}));
}

# Enhanced recall with advanced boosters
sub recall {
    my ($self, $query, $limit, $modes, $project_filter) = @_;
    $limit ||= 5;
    $modes ||= ['all'];
    $project_filter ||= 'all';

    $self->consolidate if time - $self->{last_consolidation} > $CONFIG->{consolidation_interval} / 2;

    # Multi-Query
    my @queries = $self->_generate_multi_queries($query);
    my %all_results;

    foreach my $q (@queries) {
        my $results = $self->_retrieve_base($q, $limit, $modes, $project_filter);
        $all_results{$q} = $results;
    }

    # HyDE if enabled
    if ($CONFIG->{advanced}{hyde_enabled}) {
        my $hyde_doc = $self->_generate_hyde($query);
        my $hyde_results = $self->_retrieve_base($hyde_doc, $limit, $modes, $project_filter);
        push @queries, $hyde_doc;
        $all_results{$hyde_doc} = $hyde_results;
    }

    # Fuse all
    my @fused = $self->_advanced_fuse(\%all_results, $limit);

    # Clustering (group similar)
    @fused = $self->_cluster_results(\@fused, $CONFIG->{advanced}{cluster_size});

    # Evaluation loop
    @fused = $self->_evaluate_relevance($query, \@fused, $CONFIG->{advanced}{eval_threshold});

    # Save for cross-session
    $self->_save_session_history if $self->{session_id};

    return \@fused;
}

sub _generate_multi_queries {
    my ($self, $query) = @_;
    my $prompt = qq{Generate $CONFIG->{advanced}{multi_query_count} varied queries for better retrieval coverage from this original query.

Original: $query

Output JSON array: ["query1", "query2", ...]};

    my $response;
    eval {
        $response = $self->{llm}->call($prompt);
    }; if ($@) {
        return ($query);  # Fallback
    }

    eval {
        my $qs = decode_json($response);
        return ref $qs eq 'ARRAY' ? @$qs : ($query);
    }; if ($@) {
        return ($query);
    }
}

sub _generate_hyde {
    my ($self, $query) = @_;
    my $prompt = qq{Hypothetical Document: Generate a detailed example document that would answer the query: $query. Make it informative and relevant (200-500 words).};

    my $response;
    eval {
        $response = $self->{llm}->call($prompt, undef, 1000);
    }; if ($@) {
        return $query;  # Fallback
    }
    return $response;
}

sub _retrieve_base {
    my ($self, $q, $limit, $modes, $project_filter) = @_;
    # Use previous hybrid retrieval logic
    my %retrievers = (
        keyword => sub { $self->_retrieve_keyword($q, $limit, $project_filter) },
        semantic => sub { $self->_retrieve_semantic($q, $limit, $project_filter) },
        # ... other modes
    );
    # Implement as before, return results
    return [];  # Placeholder - use actual
}

sub _advanced_fuse {
    my ($self, $all_results, $limit) = @_;
    my %doc_scores;
    my $doc_counter = 0;
    foreach my $q (keys %$all_results) {
        foreach my $doc (@{$all_results->{$q}}) {
            $doc->{doc_id} ||= $doc_counter++;
            $doc_scores{$doc->{doc_id}} += ($doc->{score} || 0) / scalar keys %$all_results;  # Average score
        }
    }
    my @sorted = sort { $doc_scores{$b} <=> $doc_scores{$a} } keys %doc_scores;
    my @fused;
    for my $id (@sorted[0..$limit-1]) {
        # Find doc by id (simplified)
        push @fused, { score => $doc_scores{$id} };  # Placeholder
    }
    return @fused;
}

sub _cluster_results {
    my ($self, $results, $cluster_size) = @_;
    # Simple clustering: group by similarity (use keyword overlap > 0.7)
    my @clusters;
    foreach my $res (@$results) {
        my $added = 0;
        foreach my $cluster (@clusters) {
            if (@$cluster < $cluster_size && _similarity($res, $cluster->[0]) > 0.7) {
                push @$cluster, $res;
                $added = 1;
                last;
            }
        }
        push @clusters, [$res] unless $added;
    }
    # Flatten top from each cluster
    my @top = map { $_->[0] } @clusters;
    return @top[0..scalar(@top)-1];
}

sub _similarity {
    my ($doc1, $doc2) = @_;
    # Keyword Jaccard
    my %set1 = map { $_ => 1 } @{$doc1->{keywords} || []};
    my %set2 = map { $_ => 1 } @{$doc2->{keywords} || []};
    my $inter = scalar keys %set1 & %set2;
    my $union = scalar keys %set1 | %set2;
    return $union ? $inter / $union : 0;
}

sub _evaluate_relevance {
    my ($self, $query, $results, $threshold) = @_;
    my @relevant;
    foreach my $res (@$results) {
        my $prompt = qq{Is this memory relevant to query? Score 0-1.

Query: $query

Memory: $res->{text}

Output: number only 0-1.};
        my $score;
        eval {
            $score = $self->{llm}->call($prompt);
            $score = $1 if $score =~ /(\d\.\d+)/;
        }; if ($@ || $score < $threshold) {
            next;
        }
        push @relevant, $res;
    }
    return @relevant;
}

# Compression/clustering enhancement in store_compressed
sub compress_text {
    my ($self, $text, $metadata) = @_;
    # Enhanced with clustering: after map-reduce, cluster facts
    my $base = $self->_base_compress($text, $metadata);  # Previous
    my $clustered_facts = $self->_cluster_facts($base->{facts});
    $base->{facts} = $clustered_facts;
    return $base;
}

sub _cluster_facts {
    my ($self, $facts) = @_;
    # Group by entity overlap
    my %groups;
    foreach my $fact (@$facts) {
        my $key = join('|', sort @{$fact->{entities}});
        push @{$groups{$key}}, $fact;
    }
    my @clustered;
    foreach my $group (@groups) {
        if (@$group > 1) {
            # Merge cluster
            my $merged = { %{$group->[0]}, entities => [keys %groups], text => join('; ', map { $_->{insight} } @$group) };
            push @clustered, $merged;
        } else {
            push @clustered, $group->[0];
        }
    }
    return \@clustered;
}

sub _base_compress {
    # Previous compress logic
    my ($self, $text, $metadata) = @_;
    return { facts => [], summary => substr($text, 0, 500) };  # Placeholder
}

# Other methods as before (store, recall base, etc.)
# ... (include all previous)

sub set_session {
    my ($self, $session_id) = @_;
    $self->{session_id} = $session_id;
}

sub process_command {
    # As before
}

1;