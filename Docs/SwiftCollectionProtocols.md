# Swift Collection Protocols

本文总结 Swift 集合协议体系，以及它们如何应用于 Bedrock 的集合类型。

## 协议层级

```text
Sequence
└── Collection
    ├── BidirectionalCollection
    │   └── RandomAccessCollection
    ├── MutableCollection
    └── RangeReplaceableCollection
```

`MutableCollection` 和 `RangeReplaceableCollection` 属于横向扩展能力，并不是获得
`RandomAccessCollection` 所必须经历的步骤。

一个具体类型可以同时遵循多个协议，只要其语义合理即可。例如 `Array` 同时遵循：

- `RandomAccessCollection`
- `MutableCollection`
- `RangeReplaceableCollection`

## Sequence

`Sequence` 表示一个类型能够按顺序逐个产生元素。

典型要求：

```swift
func makeIterator() -> Iterator
```

常见能力：

```swift
for element in sequence {}
sequence.map(transform)
sequence.filter(predicate)
sequence.reduce(initial, combine)
sequence.forEach(body)
sequence.compactMap(transform)
sequence.first(where: predicate)
sequence.contains(where: predicate)
sequence.allSatisfy(predicate)
```

重要语义：`Sequence` 可能是单次遍历（single-pass）的。也就是说，遍历一次后可能被消耗掉。

```swift
let generator = someSequence
```

对于数组风格的数据结构来说，仅实现 `Sequence` 通常是不够的。

## Collection

`Collection` 在 `Sequence` 基础上增加：

- 稳定索引（stable indexing）
- 多次遍历（multi-pass iteration）

典型要求：

```swift
var startIndex: Index { get }
var endIndex: Index { get }

subscript(position: Index) -> Element { get }

func index(after index: Index) -> Index
```

常见能力：

```swift
collection.count
collection.isEmpty
collection.first
collection.indices
collection.prefix(3)
collection.dropFirst()
collection.map(transform)
collection.filter(predicate)
```

这是自定义集合开始真正具备 Swift 标准集合体验的阶段。

## BidirectionalCollection

`BidirectionalCollection` 增加反向遍历能力。

典型要求：

```swift
func index(before index: Index) -> Index
```

常见能力：

```swift
collection.last
collection.reversed()
collection.suffix(3)
```

当底层存储能够高效地向后移动时，应实现此协议。

## RandomAccessCollection

`RandomAccessCollection` 在 `BidirectionalCollection` 基础上进一步承诺：任意距离的索引移动都足够高效。

它非常适合数组类结构。

常见能力：

```swift
collection[index]
collection.index(index, offsetBy: n)
collection.distance(from: start, to: end)
collection.prefix(10)
collection.suffix(10)
```

重点并不是 API，而是复杂度保证。

例如链表：

```text
node -> node -> node -> ...
```

向前跳 `n` 个节点：

```swift
collection.index(start, offsetBy: n)
```

仍然需要逐个节点移动，复杂度是 `O(n)`。因此链表不应该实现 `RandomAccessCollection`。

Bedrock 的 `OrderedDictionary` 底层使用数组保存顺序元素，因此实现 `RandomAccessCollection` 是合理的。

## MutableCollection

`MutableCollection` 表示元素能够按位置原地替换。

典型要求：

```swift
subscript(position: Index) -> Element { get set }
```

对于数组来说，这完全合理：

```swift
array[0] = newValue
```

但对于字典类有序集合则未必。`OrderedDictionary.Element` 是：

```swift
(key: Key, value: Value)
```

如果允许：

```swift
dictionary[0] = (
    key: "new-key",
    value: 1
)
```

则必须维护：

- 旧 key 删除
- 新 key 插入
- 重建索引
- 检查重复 key

更重要的是，这种 API 暴露了错误的修改模型。

更自然的 API 应该是：

```swift
dictionary[for: key] = value
dictionary.updateValue(value, for: key)
dictionary.insert(value, for: key, at: index)
dictionary.removeValue(for: key)
```

因此当前阶段不建议让 `OrderedDictionary` 实现 `MutableCollection`。

如果未来需要位置修改 value，更推荐：

```swift
mutating func updateValue(
    at index: Int,
    to value: Value
) -> Value
```

这样可以保持 key 不可通过位置修改，从而保护内部索引结构。

## RangeReplaceableCollection

`RangeReplaceableCollection` 支持区间级插入和删除。

典型要求：

```swift
init()

mutating func replaceSubrange(
    _ subrange: Range<Index>,
    with newElements: C
)
```

常见能力：

```swift
collection.append(element)
collection.append(contentsOf: elements)
collection.insert(element, at: index)
collection.remove(at: index)
collection.removeSubrange(range)
```

对于 key-based collection，存在额外语义问题：

- 插入元素出现重复 key 怎么办？
- 新元素与已有元素 key 冲突怎么办？
- 替换时是报错还是覆盖？
- 顺序是否必须完全保留？
- 是否做 merge？

因此目前不建议急于实现：

```swift
OrderedDictionary: RangeReplaceableCollection
```

未来更适合提供明确命名的批量 API。

## Bedrock 指南

对于有序哈希集合：

```text
OrderedDictionary -> RandomAccessCollection
OrderedSet        -> RandomAccessCollection
LRUCache          -> 暂时不要实现 Collection
```

mutation 相关协议要更谨慎。只有当公开 mutation 语义足够清楚时，再考虑加入。

当前 `OrderedDictionary` 的选择是：

```text
RandomAccessCollection: yes
MutableCollection: no
RangeReplaceableCollection: not yet
```

这样用户可以获得标准 Swift 遍历和高阶函数能力，同时 key/value 不变量仍然由 Bedrock 自己的 API 控制。
