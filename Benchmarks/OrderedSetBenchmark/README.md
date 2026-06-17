# OrderedSetBenchmark

`OrderedSetBenchmark` compares value-semantic, array-backed implementation
strategies for `OrderedSet`.

Class-based linked-list variants are intentionally excluded. They are more
relevant to an `LRUCache` benchmark than to a Swift collection that should feel
array-like and support `RandomAccessCollection`.

## Compared Layouts

```swift
// Elements + Indices
private var elements: [Element]
private var indices: [Element: Int]
```

```swift
// Array + Set
private var elements: [Element]
private var members: Set<Element>
```

```swift
// OrderedDictionary wrapper
private var storage: OrderedDictionary<Element, Void>
```

## Running

```bash
swift run -c release OrderedSetBenchmark
swift run -c release OrderedSetBenchmark 1000
swift run -c release OrderedSetBenchmark 10000
```

The optional argument controls the unique element count. Duplicate-input tests
insert each element twice. Removal tests remove `count / 5` elements. Each
measurement prints the best time from 3 iterations.

## Expected Tradeoffs

- `elements + indices` should be the best default for Bedrock: clear semantics,
  fast membership, fast index lookup, and direct random access.
- `elements + Set` may be slightly simpler and can be fast for `contains`, but
  `index(for:)` and remove-by-element require a linear search.
- `OrderedDictionary<Element, Void>` is a useful reuse experiment, but it adds a
  value slot that `OrderedSet` does not need.

## Local Baseline

Environment:

- Machine: MacBook Pro 16-inch, 2024
- Chip: Apple M4 Max
- Memory: 128 GB
- macOS: Tahoe 26.5.1
- Swift: Apple Swift 6.3.2
- Target: arm64-apple-macosx26.0
- Architecture: arm64

### Size 1,000

| Operation | Elements + Indices | Array + Set | Dictionary + Void |
| --- | ---: | ---: | ---: |
| Create unique | 0.032 ms | 0.018 ms | 0.205 ms |
| Create duplicate-heavy | 0.035 ms | 0.027 ms | 0.193 ms |
| Update existing | 0.076 ms | 0.185 ms | 90.674 ms |
| Contains existing | 0.009 ms | 0.005 ms | 0.009 ms |
| Index lookup existing | 0.009 ms | 0.133 ms | 0.009 ms |
| Remove preserving order | 0.702 ms | 0.058 ms | 7.524 ms |
| Random access shuffled indices | 0.249 ms | 0.249 ms | 0.264 ms |

### Size 10,000

| Operation | Elements + Indices | Array + Set | Dictionary + Void |
| --- | ---: | ---: | ---: |
| Create unique | 0.293 ms | 0.220 ms | 1.815 ms |
| Create duplicate-heavy | 0.374 ms | 0.313 ms | 1.940 ms |
| Update existing | 1.078 ms | 15.021 ms | 9444.045 ms |
| Contains existing | 0.115 ms | 0.089 ms | 0.109 ms |
| Index lookup existing | 0.126 ms | 12.702 ms | 0.123 ms |
| Remove preserving order | 81.896 ms | 3.370 ms | 843.297 ms |
| Random access shuffled indices | 0.302 ms | 0.309 ms | 0.312 ms |

## Conclusion

`elements + indices` remains the best default for Bedrock's `OrderedSet`.

The local `elements + indices` variant gives balanced performance across
membership, index lookup, update, and random access. It is the only simple
layout that keeps `index(for:)` and `update(with:)` efficient while still
supporting direct array-backed traversal.

`Array + Set` is attractive if the type only needs membership and ordered
iteration. It is very fast for creation, contains, and preserving-order removal
because it avoids rebuilding an index dictionary. However, it makes
`index(for:)` and `update(with:)` linear operations, which conflicts with the
API shape we want for Bedrock.

`OrderedDictionary<Element, Void>` is not a good implementation strategy for
`OrderedSet`. It can reuse lookup behavior, but replacing an existing stored
element requires remove-and-insert work to preserve the real element value. That
shows up as pathological update performance.

The benchmark executable also prints the public Bedrock `OrderedSet` as a
module-boundary observation. It is intentionally excluded from the storage
layout tables above, because those tables are meant to compare implementation
strategies rather than the current public package surface. If public package
performance becomes important, investigate `@inlinable` / `@usableFromInline`
separately.

## Notes

- These benchmarks compare storage layout only.
- Preserving-order removal remains `O(n)` for array-backed layouts.
- The benchmark should stay dependency-free and small enough to rerun while
  designing collection APIs.
