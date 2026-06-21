# LRUCacheBenchmark

`LRUCacheBenchmark` records the implementation-strategy comparison that
informed Bedrock's `LRUCache`. The shipped `LRUCache` adopted the winning
`IndexedLinkedListLRUCache` shape: a dictionary for lookup plus an
array-indexed intrusive doubly-linked list with a free list.

The benchmark is intentionally dependency-free. It measures candidate storage
layouts in isolation rather than importing the public cache API, which keeps
the comparison focused on layout and avoids module-boundary or inlining
effects. The `IndexedLinkedListLRUCache` candidate therefore mirrors the
shipped design rather than importing it, and the ordered-dictionary candidate
is likewise implemented locally instead of importing Bedrock's public
`OrderedDictionary`.

## Run

```sh
swift run -c release LRUCacheBenchmark
swift run -c release LRUCacheBenchmark 1024 50000
swift run -c release LRUCacheBenchmark 4096 5000
swift run -c release LRUCacheBenchmark 128 200000
```

Arguments:

- `capacity`: maximum cache entries. Default: `256`.
- `operations`: operation count per workload. Default: `20000`.

Each measurement prints the best time from 3 iterations plus nanoseconds per
operation.

## Research Summary

LRU cache operations are dominated by "move this existing key to the most
recent position". That makes this problem different from ordinary ordered
iteration collections.

References from other implementations point to the same core shape:

- Java `LinkedHashMap` has an access-order mode. Its implementation stores
  `head` and `tail` links, moves an accessed node to the tail, and exposes
  `removeEldestEntry` for cache-style eviction.
- CPython `functools.lru_cache` keeps a dictionary from key to link and a
  circular doubly-linked list; cache hits unlink and relink the node.
- Go `groupcache/lru` uses `container/list` plus a map from key to list
  element; `Get` and `Add` call `MoveToFront`.
- Swift Collections `OrderedDictionary` is an ordered hash table backed by an
  `OrderedSet` of keys and a contiguous value buffer. Key lookup/update is
  expected O(1), but preserving-order removal is O(`count`).

Swift-specific conclusion: an exact LRU should not be a thin wrapper over an
array-backed ordered dictionary, because every hit requires a preserving-order
remove followed by append. That turns hot-cache reads into O(`capacity`) work.

For Swift, a linked-list design can still avoid object-heavy pointer nodes. The
recommended implementation direction is an index-backed intrusive list:

```swift
private var indices: [Key: Int]
private var nodes: [Node?]
private var freeList: [Int]
private var head: Int?
private var tail: Int?
```

This keeps the same LRU asymptotics as the classic dictionary + doubly linked
list design while avoiding per-entry class allocation and weak-reference
overhead.

## Candidates

- `LocalOrderedDictionaryLRUCache`: exact wrapper around a benchmark-local
  ordered dictionary. Simple, but hit/update/evict need O(`capacity`) movement
  because the ordered dictionary stores order in an array-backed sequence.
- `ClassLinkedListLRUCache`: classic dictionary + doubly-linked object nodes.
  This is close to the Java/Python/Go reference shape, but Swift class
  allocation and weak `previous` references add overhead.
- `IndexedLinkedListLRUCache`: dictionary + array-indexed doubly-linked nodes
  with a free list. This is the Swift-oriented candidate.

## Workloads

- `Hot hit refreshes`: prefill the cache, then repeatedly read existing keys.
  This isolates move-to-most-recent cost.
- `Mixed get-or-insert access`: prefill the cache, then access a keyspace twice
  the capacity; misses are inserted.
- `Sequential insertions with eviction`: repeatedly insert new keys so every
  post-fill insert evicts the oldest entry.

## Local Result Snapshot

Cache creation and prefill run in an untimed setup step, so each measurement
isolates the operation loop itself.

Environment:

- Date: 2026-06-21
- Platform: macOS 26.5.1, arm64
- Swift: Apple Swift 6.3.2
- Build: SwiftPM release

### Capacity 128, Operations 100,000

Command:

```sh
swift run -c release LRUCacheBenchmark 128 100000
```

| Workload | Local ordered dictionary | Class linked list | Indexed linked list |
|---|---:|---:|---:|
| Hot hit refreshes | 902.0 ns/op | 137.6 ns/op | 10.9 ns/op |
| Mixed get-or-insert access | 959.0 ns/op | 211.9 ns/op | 45.1 ns/op |
| Sequential insertions with eviction | 1,022.1 ns/op | 202.0 ns/op | 67.8 ns/op |

### Capacity 1,024, Operations 50,000

Command:

```sh
swift run -c release LRUCacheBenchmark 1024 50000
```

| Workload | Local ordered dictionary | Class linked list | Indexed linked list |
|---|---:|---:|---:|
| Hot hit refreshes | 7,373.4 ns/op | 138.2 ns/op | 13.2 ns/op |
| Mixed get-or-insert access | 7,650.5 ns/op | 225.9 ns/op | 54.1 ns/op |
| Sequential insertions with eviction | 7,525.9 ns/op | 198.0 ns/op | 64.9 ns/op |

### Capacity 4,096, Operations 5,000

Command:

```sh
swift run -c release LRUCacheBenchmark 4096 5000
```

| Workload | Local ordered dictionary | Class linked list | Indexed linked list |
|---|---:|---:|---:|
| Hot hit refreshes | 26,890.7 ns/op | 187.6 ns/op | 16.0 ns/op |
| Mixed get-or-insert access | 30,602.2 ns/op | 226.2 ns/op | 61.3 ns/op |
| Sequential insertions with eviction | 5,935.2 ns/op | 86.7 ns/op | 27.0 ns/op |

## Conclusion

Bedrock's `LRUCache` shipped as the indexed intrusive-list design: a dictionary
for lookup plus a dedicated array-indexed doubly-linked recency list for O(1)
move and eviction. The numbers above are why a thin wrapper over an array-backed
ordered dictionary was rejected — every hot read on that layout costs
O(`capacity`) movement.

Across all three capacities the indexed intrusive list is roughly an order of
magnitude faster than the class-node list on hot reads and consistently ahead on
mixed and insert-heavy workloads, which is what motivated the shipped design.
