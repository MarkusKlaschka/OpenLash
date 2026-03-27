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
    graph_file => '/root/OpenLash/agent_files/entities_graph.json',
    md_dir => '/root/OpenLash/agent_files/memory_md',  # Directory for Markdown files
    md_files => {
        MEMORY => 'MEMORY.md',  # Long-term semantic/episodic
        DAILY_LOG => 'daily-log.md',  # Working/episodic today
        USER_PROFILE => 'user-profile.md',  # Semantic about user
        PROJECT_NOTES => 'project-notes.md',  # Per project, but one file for now
    },
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
        md_files => {},  # Loaded MD data
    };
    bless $self, $class;
    $self->_load_graph;
    $self->_load_md_files;
    return $self;
}

sub _load_graph {
    my $self = shift;
    if (-e $CONFIG->{graph_file}) {
        my $data = decode_json(path($CONFIG->{graph_file})->slurp);
        $self->{graph} = $data;
    }
}

sub _save_graph {
    my $self = shift;
    path($CONFIG->{graph_file})->spew(encode_json($self->{graph}));
}

sub _load_md_files {
    my $self = shift;
    for my $type (keys %{$CONFIG->{md_files}}) {
        my $file = path($CONFIG->{md_dir})->child($CONFIG->{md_files}{$type});
        if (-e $file) {
            my $content = $file->slurp;
            $self->_import_from_md($content, $type);
        }
    }
}

sub _import_from_md {
    my ($self, $content, $type) = @_;
    # Parse Markdown to memories (simple: split by sections, treat as entries)
    my @entries = split /## /, $content;
    foreach my $entry (@entries) {
        next unless $entry =~ /(.+)/s;
        my $text = $1;
        my $metadata = { type => $type, source => 'md_file', importance => 0.7 };  # Default
        if ($type eq 'USER_PROFILE') {
            $metadata->{layer} = 'semantic';
        } elsif ($type eq 'DAILY_LOG') {
            $metadata->{layer} = 'episodic';
        } else {
            $metadata->{layer} = 'semantic';
        }
        $self->store($text, $metadata);
    }
}

sub _export_to_md {
    my ($self, $type) = @_;
    my $file = path($CONFIG->{md_dir})->child($CONFIG->{md_files}{$type});
    my $content = $self->_generate_md_content($type);
    $file->spew($content);
}

sub _generate_md_content {
    my ($self, $type) = @_;
    my @relevant = $self->recall('', 50, ['semantic', 'episodic'], 'all');  # All for MEMORY
    if ($type eq 'DAILY_LOG') {
        @relevant = $self->recall('', 20, ['recent'], 'all');  # Recent working/episodic
    } elsif ($type eq 'USER_PROFILE') {
        @relevant = grep { $_->{metadata}{tags} && grep { $_ eq 'user' || $_ eq 'profile' } @{$_->{metadata}{tags}} } @relevant;
    } elsif ($type eq 'PROJECT_NOTES') {
        @relevant = $self->recall('', 30, ['all'], 'OpenLash');  # Example project
    }

    my $md = "# $type\n\n";
    foreach my $mem (@relevant) {
        $md .= "## Entry: " . ($mem->{metadata}{date} || 'Unknown') . "\n";
        $md .= $mem->{text} . "\n\n";
        if ($mem->{metadata}{importance}) {
            $md .= "*Importance: " . $mem->{metadata}{importance} . "*\n\n";
        }
        if ($mem->{related_entities}) {
            $md .= "*Related: " . join(', ', keys %{$mem->{related_entities}}) . "*\n\n";
        }
    }
    return $md;
}

# Auto-update MD files during consolidation
sub consolidate {
    my $self = shift;
    # ... (previous consolidation logic)
    my @high_importance = grep { $_->{importance} > $CONFIG->{importance_threshold} } @{$self->{memories}{working}};
    foreach my $mem (@high_importance) {
        my $layer = $self->_classify_layer($mem->{text}, $mem->{metadata});
        $self->store_layered($mem->{text}, $layer, $mem->{metadata});
    }
    @{$self->{memories}{working}} = grep { $_->{importance} <= $CONFIG->{importance_threshold} } @{$self->{memories}{working}};
    $self->{last_consolidation} = time;
    $self->self_reflect;

    # Export to MD
    $self->_export_to_md('DAILY_LOG');
    $self->_export_to_md('MEMORY');
    if ($self->{session_id} && $self->{session_id} =~ /user/) {
        $self->_export_to_md('USER_PROFILE');
    }
}

# User commands
sub process_command {
    my ($self, $input) = @_;
    if ($input =~ /^Remember this: (.+)/i) {
        my $text = $1;
        $self->store($text, { importance => 0.8, source => 'user_remember' });
        $self->_export_to_md('MEMORY');
        return "Remembered: $text";
    } elsif ($input =~ /^This was important: (.+)/i) {
        my $target = $1;
        $self->_mark_important($target);
        return "Marked as important: $target";
    } elsif ($input =~ /^Forget this: (.+)/i) {
        my $target = $1;
        $self->_forget($target);
        return "Forgot: $target";
    } elsif ($input =~ /^Review memory: (.+)/i) {
        my $query = $1 || '';
        my $results = $self->recall($query, 10);
        return $self->_format_review($results);
    } else {
        return undef;  # Not a command
    }
}

sub _mark_important {
    my ($self, $target) = @_;
    # Find by text hash or id (simplified: search working)
    foreach my $mem (@{$self->{memories}{working}}) {
        if (index($mem->{text}, $target) >= 0) {
            $mem->{metadata}{importance} = 1.0;
            $self->consolidate;  # Re-consolidate
            return;
        }
    }
    # For long-term, update metadata in chroma (placeholder: re-store with high importance)
}

sub _forget {
    my ($self, $target) = @_;
    # Similar search and remove from working or chroma
    @{$self->{memories}{working}} = grep { index($_->{text}, $target) < 0 } @{$self->{memories}{working}};
    # For chroma, delete by id (implement if needed)
}

sub _format_review {
    my ($self, $results) = @_;
    my $output = "Memory Review:\n";
    foreach my $mem (@$results) {
        $output .= "- " . substr($mem->{text}, 0, 100) . "... (Importance: " . ($mem->{metadata}{importance} || 'N/A') . ")\n";
    }
    return $output;
}

# Store method updated to check for user commands? No, process_command separate.

# Rest of methods unchanged (store, recall, etc. from previous)
# ... (copy all previous methods: _classify_layer, store_working, store_layered, _get_project_provider, recall, _retrieve_*, _rrf_fuse, compress_text, etc.)

# For brevity, assume all previous code is included here.

1;