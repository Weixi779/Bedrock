# Bedrock

[English](README.md) | 简体中文

![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)
![SPM](https://img.shields.io/badge/SwiftPM-supported-brightgreen)
![Platform](https://img.shields.io/badge/platform-Apple%20Platforms%20%7C%20Linux-blue)
![License](https://img.shields.io/github/license/Weixi779/Bedrock)

Bedrock 是一组常见 Swift 数据结构和轻量数据模型。它更像项目级的
foundation code：简单、可读、方便复制、方便按需调整，也方便测试。

这个仓库支持通过 SwiftPM 使用，但这不是重点。如果你只需要其中一个类型，
可以直接把对应的单个源码文件复制到自己的项目里，再按业务需求调整。如果
Bedrock 节省了你的时间，欢迎点一个 star。

部分实现来自 `Benchmarks/` 里的 benchmark 实验。这些 benchmark 更像设计
笔记和合理性校验，不是一个独立的性能测试框架。

## 已支持类型

### Collections

| Type | Source | Summary |
| --- | --- | --- |
| `OrderedDictionary` | [OrderedDictionary.swift](Sources/Bedrock/Collections/OrderedDictionary.swift) | 哈希表支持的有序字典，保留 key/value 的插入顺序。 |
| `OrderedSet` | [OrderedSet.swift](Sources/Bedrock/Collections/OrderedSet.swift) | 哈希表支持的有序集合，保留成员的插入顺序。 |
| `Stack` | [Stack.swift](Sources/Bedrock/Collections/Stack.swift) | 小型后进先出集合。 |
| `Queue` | [Queue.swift](Sources/Bedrock/Collections/Queue.swift) | 基于两个数组实现的先进先出集合。 |
| `Deque` | [Deque.swift](Sources/Bedrock/Collections/Deque.swift) | 基于环形存储的双端队列。 |
| `RingBuffer` | [RingBuffer.swift](Sources/Bedrock/Collections/RingBuffer.swift) | 固定容量 FIFO buffer，满时覆盖旧值。 |

### Caches

| Type | Source | Summary |
| --- | --- | --- |
| `LRUCache` | [LRUCache.swift](Sources/Bedrock/Caches/LRUCache.swift) | 固定容量的 least-recently-used cache。 |

## 示例

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

## 文档

- [Swift Collection Protocols](Docs/SwiftCollectionProtocols.md)
- [Roadmap](ROADMAP.md)

## Benchmarks

- [OrderedDictionaryBenchmark](Benchmarks/OrderedDictionaryBenchmark/README.md)
- [OrderedSetBenchmark](Benchmarks/OrderedSetBenchmark/README.md)
- [DequeBenchmark](Benchmarks/DequeBenchmark/README.md)
- [LRUCacheBenchmark](Benchmarks/LRUCacheBenchmark/README.md)

## License

Bedrock 使用 [LICENSE](LICENSE) 中的开源协议。
