# Advanced Memory Compression in OpenLash

## Introduction
This enhancement to `Memory.pm` enables compression of large text inputs (50k–500k+ tokens, e.g., week-long logs) using hierarchical Map-Reduce summarization. The output is a structured JSON with facts array and narrative summary, stored in Chroma Vector DB for efficient retrieval.

## Key Features
- **Hierarchical Summarization**: Chunk → Per-chunk facts/summary → Aggregated meta-summary.
- **Output Format**: `{ facts: [{event, entities: [], insight, importance: 0-1, date}], summary: str (≤500 tokens) }`.
- **LLM Integration**: Local via Ollama (Qwen2.5-32B for 1x RTX 3090) or vLLM (72B multi-GPU).
- **Storage**: Embeddings in Chroma (cosine similarity search).
- **Seamless Integration**: Auto-compresses large inputs in `store`; hybrid recall in `recall`.

## Setup
1. Install deps: `cpan LWP::UserAgent JSON::PP Digest::SHA List::Util DateTime HTTP::Request::Common`.
2. Run LLM server: Ollama `ollama run qwen2.5:32b-instruct-q6_K` or vLLM for 72B.
3. Run Chroma: `chroma run --path ./data/chroma`.
4. Config in `new()`: `{ llm => {endpoint => '...', model => '...'}, chroma => {endpoint => 'http://localhost:8000'} }`.

## Usage Example
```perl
use Memory;
my $mem = Memory->new();
$mem->store($week_log_text, { date => '2026-03-23' });  # Auto-compress if large
my $results = $mem->recall("key event");  # Hybrid short/long-term
```

## Architecture Details
- **Chunking**: Overlapping 4k-char chunks.
- **Map Phase**: LLM extracts facts/summary per chunk.
- **Reduce Phase**: Merge facts by entities, LLM generates meta-summary.
- **Embedding**: Ollama `/api/embeddings` (768-dim).
- **Storage**: Chroma collection `long_term_memory`; query with distance-to-score conversion.
- **Deduplication**: Reuse existing hash-based dedup; entity grouping in merge.
- **Error Handling**: Eval-wrapped LLM calls; fallbacks to truncated text.

## Testing
- Run `prove -l t/memory_compression.t` (uses mocks; adapt for real LLM/Chroma).
- Simulate large inputs; check fact extraction accuracy.

## Limitations & Optimizations
- Assumes LLM server available; add retries (3x exponential backoff).
- For >500k tokens, add recursive reduce levels.
- Batching: Implement parallel chunk processing with threads for speed.
- Embeddings: If Ollama slow, integrate faster model like all-MiniLM-L6-v2 via Perl bindings.

## Files Added/Changed
- `Memory.pm`: Core logic, integration.
- `lib/OpenLash/LLM.pm`: LLM caller.
- `t/memory_compression.t`: Tests.
- `prompts/compression_prompts.json`: Templates (load dynamically if needed).
- `docs/MEMORY_COMPRESSION.md`: This doc.

Branch: `feat_memory`. Ready for review/PR.

For issues: Ensure Chroma/LLM ports free; test on target hardware (RTX 3090).