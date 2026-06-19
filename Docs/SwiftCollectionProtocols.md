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
dictionary[key: key] = value
dictionary.updateValue(value, forKey: key)
dictionary.insert(value, forKey: key, at: index)
dictionary.removeValue(forKey: key)
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

各集合类型当前的协议选择：

| 类型 | Collection | RandomAccess | Mutable | RangeReplaceable | Equatable / Hashable |
|---|---|---|---|---|---|
| `OrderedDictionary` | ✅ | ✅ | ❌ | ❌ | 条件遵循（`Value: Equatable` / `Value: Hashable`） |
| `OrderedSet` | ✅ | ✅ | ❌ | ❌ | ✅ |
| `Deque` | ✅ | ✅ | ✅ | ✅ | 条件遵循（`Element: …`） |
| `RingBuffer` | ✅ | ✅ | ✅ | ❌ | 条件遵循（`Element: …`） |
| `Stack` | ❌ | — | — | — | 条件遵循（`Element: …`） |
| `Queue` | ❌ | — | — | — | 条件遵循（`Element: …`） |

总原则：**只有当一个协议的语义对该类型确实成立、且不会引诱出破坏不变量的用法时才遵循它。** mutation 相关协议（`MutableCollection` / `RangeReplaceableCollection`）尤其要谨慎。

### 有序哈希集合：`OrderedDictionary` / `OrderedSet`

底层用数组保存顺序元素 + 哈希表保存索引，因此 `RandomAccessCollection` 合理。但不实现 `MutableCollection` / `RangeReplaceableCollection`：

- 按位置原地替换会绕过 key/element 唯一性与索引重建（见上文 `MutableCollection`、`RangeReplaceableCollection` 两节）。
- 这些不变量由 Bedrock 自己命名清晰的 API 维护（`updateValue(_:forKey:)`、`insert(_:forKey:at:)`、`update(with:)` 等）。

相等性是**顺序敏感**的：`OrderedSet([1, 2]) != OrderedSet([2, 1])`，`OrderedDictionary` 同理。这一点与标准 `Set` / `Dictionary` 不同，刻意写进了类型文档。

### `Deque`

环形缓冲、逻辑下标从 0 到 `count - 1` 稠密排列，且没有 key 这类额外不变量，因此三个协议都安全：

```text
RandomAccessCollection:    yes
MutableCollection:         yes   // 按位置改值不破坏任何不变量
RangeReplaceableCollection: yes  // 区间插入/删除语义清晰
```

队头、队尾插入与删除都是均摊 O(1)。

### `RingBuffer`

固定容量的环形缓冲，满则覆盖最旧元素。`RandomAccessCollection` + `MutableCollection` 与 `Deque` 同理成立，但**不实现 `RangeReplaceableCollection`**：固定容量下「区间替换」语义不清（插入超过容量怎么办、淘汰谁、是否返回被挤出的元素），更适合由专门命名的 `append(_:) -> Element?` 表达。

实现上 `RingBuffer` 是 `Deque` 之上的一层「有界 + 覆盖」策略（组合一个 `Deque`，自己只管 `capacity` 与满时淘汰），而不是再写一份环形逻辑。

### `Stack` / `Queue`

刻意**不**实现 `Collection`。它们的契约只有端操作（`push`/`pop`/`top`，`enqueue`/`dequeue`/`front`/`back`），暴露稳定索引与位置下标只会引诱出违反 LIFO/FIFO 的用法。需要遍历时通过它们各自的有序视图即可。

两者仍条件遵循 `Equatable` / `Hashable`（顺序敏感）；`Queue` 的相等比较的是**逻辑前后顺序**，与内部 inbox/outbox 的切分无关。
