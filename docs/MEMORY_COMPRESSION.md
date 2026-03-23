# Memory Compression in OpenLash

## Overview
This feature adds hierarchical Map-Reduce summarization for long-term memory storage in Chroma Vector DB. Compresses large texts (50k+ tokens) into JSON facts + narrative summary.

## Usage
```perl
my $memory = Providers::Memory->new({ llm => { endpoint => 'http://localhost:11434/api/generate' } });
my $compressed = $memory->compress_and_store($large_text, { date => '2026-03-23' });
my $results = $memory->retrieve_long_term("query");
```

## Requirements
- Ollama or vLLM for LLM (Qwen2.5-32B/72B).
- Chroma server at http://localhost:8000.
- Perl deps: LWP::UserAgent, JSON::PP, Digest::SHA, DateTime, HTTP::Request::Common.

## Workflow
1. Chunk text.
2. LLM extracts facts/summary per chunk.
3. Merge and meta-summarize.
4. Embed and store in Chroma.

## Config
Set in Memory.pm $CONFIG or pass to new().

## Testing
Run `prove t/memory_compression.t` (mocks LLM/Chroma).