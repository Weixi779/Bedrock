# Bedrock

English | [简体中文](README.zh-CN.md)

![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)
![SPM](https://img.shields.io/badge/SwiftPM-supported-brightgreen)
![Platform](https://img.shields.io/badge/platform-Apple%20Platforms%20%7C%20Linux-blue)
![License](https://img.shields.io/github/license/Weixi779/Bedrock)

Bedrock is a small collection of common Swift data structures and lightweight
data models. It is written as project-level foundation code: simple enough to
read, copy, adapt, and test.

The package is available through SwiftPM, but importing the whole package is not
the main point. If one type is useful, feel free to copy that single source file
into your project and adjust it for your own needs. If Bedrock saves you time,
a star is appreciated.

Some implementations are shaped by benchmark experiments in `Benchmarks/`.
Those benchmarks are design notes and sanity checks, not a performance
framework.

## Supported Types

### Collections

| Type | Source | Summary |
| --- | --- | --- |
| `OrderedDictionary` | [OrderedDictionary.swift](Sources/Bedrock/Collections/OrderedDictionary.swift) | A hash-backed dictionary that keeps key/value pairs in insertion order. |
| `OrderedSet` | [OrderedSet.swift](Sources/Bedrock/Collections/OrderedSet.swift) | A hash-backed set that keeps members in insertion order. |
| `Stack` | [Stack.swift](Sources/Bedrock/Collections/Stack.swift) | A small last-in, first-out collection. |
| `Queue` | [Queue.swift](Sources/Bedrock/Collections/Queue.swift) | A first-in, first-out collection backed by two arrays. |
| `Deque` | [Deque.swift](Sources/Bedrock/Collections/Deque.swift) | A double-ended queue backed by circular storage. |
| `RingBuffer` | [RingBuffer.swift](Sources/Bedrock/Collections/RingBuffer.swift) | A fixed-capacity FIFO buffer that overwrites old values when full. |

### Caches

| Type | Source | Summary |
| --- | --- | --- |
| `LRUCache` | [LRUCache.swift](Sources/Bedrock/Caches/LRUCache.swift) | A fixed-capacity least-recently-used cache. |

## Examples

```swift
var dictionary: OrderedDictionary<String, Int> = [
    "one": 1,
    "two": 2
]

dictionary.updateValue(3, forKey: "three")
dictionary[key: "two"] = 20

print(dictionary.keys)      // ["one", "two", "three"]
print(dictionary[0].key)    // "one"
```

```swift
var cache = LRUCache<String, Int>(capacity: 2)
cache.updateValue(1, forKey: "a")
cache.updateValue(2, forKey: "b")
cache.value(forKey: "a")
cache.updateValue(3, forKey: "c")

print(cache.keys)           // ["a", "c"]
```

## Notes

- [Swift Collection Protocols](Docs/SwiftCollectionProtocols.md)
- [Roadmap](ROADMAP.md)

## Benchmarks

- [OrderedDictionaryBenchmark](Benchmarks/OrderedDictionaryBenchmark/README.md)
- [OrderedSetBenchmark](Benchmarks/OrderedSetBenchmark/README.md)
- [DequeBenchmark](Benchmarks/DequeBenchmark/README.md)
- [LRUCacheBenchmark](Benchmarks/LRUCacheBenchmark/README.md)

## License

Bedrock is available under the license in [LICENSE](LICENSE).
