# OrderedDictionaryBenchmark

`OrderedDictionaryBenchmark` is a small local benchmark target for comparing
candidate storage layouts before committing them to Bedrock's public
implementation.

It is intentionally dependency-free. The numbers are not meant to be universal
performance claims; they are local baselines for choosing simple implementation
tradeoffs.

## OrderedDictionary Storage

The current `OrderedDictionary` API exposes elements as a `(key: Key, value:
Value)` tuple. We compared two internal layouts:

```swift
// Element storage
private var elements: [(key: Key, value: Value)]
private var indices: [Key: Int]
```

```swift
// Split storage
private var keys: [Key]
private var values: [Value]
private var indices: [Key: Int]
```

## Conclusion

The benchmark does not show a meaningful performance win for split storage.
At 10,000 elements, create, read, update, and preserving-order removal are
effectively tied. Front insertion is dominated by array shifting and index
rebuilding in both layouts.

Because the public model is element-centric, the first implementation should
prefer `elements + indices`:

- CRUD code is easier to read.
- Returning and moving `(key, value)` elements is direct.
- Future batch insert/remove APIs can operate on one logical element stream.
- The measured performance difference is too small to justify a less direct
  implementation.

Revisit this if real workloads show a consistent double-digit percentage gap.

## Running

```bash
swift run -c release OrderedDictionaryBenchmark
swift run -c release OrderedDictionaryBenchmark 1000
swift run -c release OrderedDictionaryBenchmark 10000
```

The optional argument controls the element count. Removal tests remove
`count / 5` keys. Each measurement prints the best time from 3 iterations.

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

| Operation | Element storage | Split storage |
| --- | ---: | ---: |
| Create by appending unique keys | 0.086 ms | 0.086 ms |
| Read existing keys | 0.022 ms | 0.021 ms |
| Update existing keys | 0.111 ms | 0.111 ms |
| Remove by key, preserving order | 1.368 ms | 0.870 ms |
| Insert unique keys at front | 5.071 ms | 4.729 ms |

### Size 10,000

| Operation | Element storage | Split storage |
| --- | ---: | ---: |
| Create by appending unique keys | 0.303 ms | 0.310 ms |
| Read existing keys | 0.115 ms | 0.123 ms |
| Update existing keys | 0.434 ms | 0.445 ms |
| Remove by key, preserving order | 84.584 ms | 84.592 ms |
| Insert unique keys at front | 458.563 ms | 454.987 ms |

## Notes

- These benchmarks compare storage layout only, not public API overhead.
- Preserving-order removal and front insertion are `O(n)` operations in both
  layouts because later indices must be rebuilt.
- The benchmark target should stay lightweight and executable from SwiftPM so
  storage experiments remain easy to rerun.
