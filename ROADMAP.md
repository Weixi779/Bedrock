# Roadmap

Bedrock `0.1.0` is the baseline release. It is intentionally small: a set of
project-friendly Swift foundation types with readable implementations,
predictable semantics, and minimal abstraction.

The roadmap is directional, not a promise that every item will ship. A feature
belongs in Bedrock only when it is common across projects, useful with a small
API surface, and not better left to application-specific policy.

## Near-Term Work

- Improve README examples for the existing types.
- Add focused documentation for frequently used types as needs become clear.
- Document key semantics clearly: ordering, equality, capacity behavior,
  mutation costs, and edge cases.
- Keep benchmarks tied to implementation decisions instead of turning them into
  a separate performance framework.

## Candidate Features

### JSON Number Original-Text Capture Follow-ups

The supplemental original-text path is integrated for v0.2.1 through
`JSONDecoder.decodePreservingNumberText`. v0.2.0 remains unchanged. The
path-directed prototype's measured overhead was accepted on 2026-11-05;
further micro-optimization is deferred. See the
[benchmark](Benchmarks/JSONNumberTextBenchmark/README.md) for a reproducible
measurement of the integrated implementation.

The direction is lazy, path-directed lookup: provide per-decode source context,
start work only when JSONNumber needs it, index containers along codingPath,
skip unrelated values, and cache the indexed containers. Keep original text
optional. Ambiguous key mappings or unavailable text fall back to ordinary
numeric decoding; never invent original text from a converted number.

Local optimized-build measurements on M4 Max / Swift 6.4, for typed page
responses with three dynamic cursor numbers, showed additional per-decode
costs of approximately 0.009 ms at 2 KB, 0.030 ms at 22 KB, 0.224 ms at 220 KB,
and 1.201 ms at 1.1 MB. A dense array of 1,000 dynamic numbers added about
0.363 ms. These are prototype measurements, not shipping performance guarantees
or iOS device results.

Deferred optimization TODOs:

- [ ] Reduce source-byte copies and temporary allocations; measure peak memory
  and retained response-buffer lifetime as well as latency.
- [ ] Explore a fast path for unescaped object keys, preserving Unicode and
  duplicate-key behavior and retaining a safe path for escaped keys.
- [ ] Profile repeated work in numeric-heavy payloads before adding caches or
  changing numeric conversion and equality semantics.
- [x] Add reproducible benchmarks for no-dynamic-number responses, typed pages
  with small cursors, and numeric-heavy payloads.
- [ ] Measure target iOS devices before making platform performance claims.

Any optimization must preserve conservative handling of key collisions,
per-request isolation, and normal Codable behavior when raw text is unavailable.

### Existing Type Polish

- Small convenience APIs when real usage shows repeated boilerplate.
- Reordering or update helpers when they preserve clear type invariants.
- Additional examples for common usage patterns.
- More benchmark notes when they explain implementation tradeoffs.

### Possible Later Types

- `Counter` / `Bag`
- `Multimap`
- `BiMap`

These are candidates because they are common project-level primitives, but each
should be added only if the API can stay small and the behavior is easy to
explain.

## Non-Goals

- Replacing Swift Collections.
- Framework-level architecture.
- Thread-safe containers by default.
- Built-in serialization policies for every type.
- Large abstraction layers around collection protocols.
- Features added only for completeness.
