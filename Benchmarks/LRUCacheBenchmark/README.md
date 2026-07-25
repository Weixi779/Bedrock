# LRUCacheBenchmark

`LRUCacheBenchmark` compares three cache implementation shapes:

- `LocalReferenceLRUCache`: a dictionary plus class-allocated doubly-linked
  nodes, mirroring Bedrock's public `ReferenceLRUCache`.
- `LocalIndexedLRUCache`: a dictionary plus an array-indexed intrusive list and
  free list, mirroring Bedrock's public `LRUCache`.
- `LocalNSCache`: Foundation's thread-safe `NSCache`, adapted to generic Swift
  `Hashable` keys and values with object boxes.

All three candidates live in `main.swift`. The benchmark target deliberately
does not depend on the Bedrock library, so candidates are compiled in the same
module and results do not include unequal module-boundary or cross-module
inlining effects.

`NSCache` is a useful engineering baseline, but it is not semantically
equivalent to the exact LRU implementations:

- its eviction order is unspecified;
- `countLimit` is advisory rather than a strict capacity guarantee;
- it is thread-safe, while the two local LRU candidates are not;
- generic value-type keys and values must be boxed for its object-only API.

The benchmark therefore compares operation cost under the same calls and
datasets. It does not claim that the three caches provide identical behavior.

## Run

```sh
swift run -c release LRUCacheBenchmark
swift run -c release LRUCacheBenchmark 128 100000
swift run -c release LRUCacheBenchmark 1024 50000
swift run -c release LRUCacheBenchmark 4096 5000
swift run -c release LRUCacheBenchmark --trace trace.csv 16384
swift run -c release LRUCacheBenchmark --trace trace.csv 16384 1000000
```

Arguments:

- `capacity`: maximum cache entries. Default: `256`.
- `operations`: operation count per workload. Default: `20000`.
- `--trace <csv-path> [capacity] [request-limit]`: replays a Twitter-style
  `time, object, size, next_access_vtime` CSV trace. Trace capacity defaults to
  `16384` entries. The optional request limit uses only the prefix of the trace.

Each measurement prints the best time from three iterations and nanoseconds per
operation. Cache construction and prefill are excluded from the timed region.
Trace loading and parsing also happen before timing.

## Reproducible Datasets

The benchmark uses fixed-seed synthetic traces generated before timing:

- `Hot hit refreshes`: uniform keys in `[0, capacity)`, seed `0x1A11_CAC4`.
  The cache is prefilled, so every operation is a hit that refreshes recency for
  the exact LRU implementations.
- `Mixed get-or-insert access`: uniform keys in `[0, capacity * 2)`, seed
  `0x1A11_CAC5`. The cache starts full; misses insert the requested key.
- `Sequential insertions with eviction`: keys `0..<operations`. Every
  post-fill insertion forces capacity management.

Every candidate receives the same key sequence, key/value types, capacity, and
operation count. Checksums confirm that all candidates observed the same values
for these runs; they do not assert identical eviction order for `NSCache`.

## Paper Trace

The real-workload run uses the first 10 million requests from Twitter cache
cluster 52, distributed with libCacheSim as
`twitter_cluster52_10m.csv.zst`. The trace originates from:

> Juncheng Yang, Yao Yue, and K. V. Rashmi. "A large scale analysis of hundreds
> of in-memory cache clusters at Twitter." OSDI 2020.

- [USENIX paper and presentation](https://www.usenix.org/conference/osdi20/presentation/yang)
- [Open cache trace catalog](https://github.com/cacheMon/cache_dataset)
- [libCacheSim](https://github.com/1a1a11a/libCacheSim)

The compressed trace must be decompressed before running this dependency-free
Swift benchmark:

```sh
zstd -d twitter_cluster52_10m.csv.zst -o twitter_cluster52_10m.csv
swift run -c release LRUCacheBenchmark \
  --trace twitter_cluster52_10m.csv 16384
```

For repeated local experiments, Bedrock keeps untracked datasets under:

```text
Benchmarks/LRUCacheBenchmark/Data/
```

This directory is ignored by Git. For example:

```sh
swift run -c release LRUCacheBenchmark \
  --trace Benchmarks/LRUCacheBenchmark/Data/twitter_cluster52_10m.csv \
  16384
```

The benchmark maps object IDs to `UInt64` keys and object sizes to `Int` values.
All caches use an entry-count capacity; object size is not used as a cost.
Trace parsing, allocation of the request array, and cache construction are
outside the timed region. Cache hits perform a lookup and recency refresh;
misses insert the object.

This 10-million-request file is a real-trace excerpt, not the complete Twitter
dataset. libCacheSim explicitly warns against using its small bundled samples
to make eviction-policy miss-ratio claims. It is suitable here for exercising
the same implementations under a real production access distribution; the hit
rates are reported to describe the workload, not to rank cache policies.

## Local Result Snapshot

Environment:

- Date: 2026-07-25
- Platform: macOS 26.5.1, arm64
- Swift: Apple Swift 6.3.3
- Build: SwiftPM release

### Capacity 128, Operations 100,000

| Workload | Reference-node LRU | Index-backed LRU | NSCache |
|---|---:|---:|---:|
| Hot hit refreshes | 179.1 ns/op | 12.7 ns/op | 125.5 ns/op |
| Mixed get-or-insert access | 279.4 ns/op | 42.6 ns/op | 823.0 ns/op |
| Sequential insertions with eviction | 248.8 ns/op | 67.5 ns/op | 235.1 ns/op |

### Capacity 1,024, Operations 50,000

| Workload | Reference-node LRU | Index-backed LRU | NSCache |
|---|---:|---:|---:|
| Hot hit refreshes | 136.3 ns/op | 13.6 ns/op | 131.5 ns/op |
| Mixed get-or-insert access | 276.5 ns/op | 54.5 ns/op | 574.3 ns/op |
| Sequential insertions with eviction | 233.0 ns/op | 65.9 ns/op | 265.6 ns/op |

### Capacity 4,096, Operations 5,000

| Workload | Reference-node LRU | Index-backed LRU | NSCache |
|---|---:|---:|---:|
| Hot hit refreshes | 195.0 ns/op | 16.4 ns/op | 120.4 ns/op |
| Mixed get-or-insert access | 259.3 ns/op | 52.3 ns/op | 379.9 ns/op |
| Sequential insertions with eviction | 133.6 ns/op | 25.2 ns/op | 267.0 ns/op |

### Twitter Cluster 52, 10 Million Requests

| Capacity | Reference-node LRU | Index-backed LRU | NSCache |
|---:|---:|---:|---:|
| 1,024 | 205.3 ns/req, 62.92% hit | 37.4 ns/req, 62.92% hit | 230.4 ns/req, 64.53% hit |
| 16,384 | 208.2 ns/req, 79.64% hit | 28.9 ns/req, 79.64% hit | 211.0 ns/req, 80.52% hit |
| 65,536 | 217.5 ns/req, 85.44% hit | 25.7 ns/req, 85.44% hit | 228.5 ns/req, 86.13% hit |

The exact LRU candidates produced identical hit counts and checksums at every
capacity. `NSCache` produced different hit rates and checksums because its
eviction policy and `countLimit` behavior are not exact LRU semantics.

## Conclusion

The index-backed LRU wins every measured workload. In these runs it is roughly
10–14 times faster than the reference-node implementation on hot hits and
about 3.5–6.6 times faster on mutation-heavy workloads.

On the Twitter production trace excerpt, the index-backed LRU is approximately
5.5–8.5 times faster than the reference-node implementation across capacities
from 1,024 to 65,536 entries. This removes the strongest weakness of the
uniform synthetic traces: the result persists under a real workload's
popularity skew and temporal reuse.

`NSCache` is competitive with or faster than the reference-node LRU on hot
hits, but loses to the index-backed LRU throughout. Its mixed workload is
especially expensive here because misses exercise synchronization, eviction,
and the generic key/value object adaptation.

The result supports a narrow conclusion: for an exact, single-threaded Swift
LRU over value-type keys and values, Bedrock's index-backed intrusive list has
substantially lower operation cost than both class-linked nodes and `NSCache`
under both reproducible synthetic traces and a real Twitter trace excerpt. It
does not establish memory usage, multi-threaded scalability, or hit-ratio
superiority over `NSCache`'s unspecified eviction policy.
