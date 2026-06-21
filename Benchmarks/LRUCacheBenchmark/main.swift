//
//  main.swift
//  LRUCacheBenchmark
//
//  Created by weixi on 2026/6/19.
//

import Foundation

@main
struct LRUCacheBenchmark {
    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        let capacity = arguments.first.flatMap(Int.init) ?? 256
        let operationCount = arguments.dropFirst().first.flatMap(Int.init) ?? 20_000

        precondition(capacity >= 0, "Capacity must not be negative")
        precondition(operationCount >= 0, "Operation count must not be negative")

        let hotKeys = makeKeys(
            count: operationCount,
            keySpace: max(1, capacity),
            seed: 0x1A11_CAC4
        )
        let mixedKeys = makeKeys(
            count: operationCount,
            keySpace: max(1, capacity * 2),
            seed: 0x1A11_CAC5
        )

        print("LRUCache design benchmark")
        print("capacity: \(capacity)")
        print("operations: \(operationCount)")
        print("")

        benchmarkHotHits(capacity: capacity, keys: hotKeys)
        benchmarkMixedAccess(capacity: capacity, keys: mixedKeys)
        benchmarkSequentialInsertions(capacity: capacity, operationCount: operationCount)
    }

    private static func benchmarkHotHits(capacity: Int, keys: [Int]) {
        print("Hot hit refreshes")
        runHotHits(
            "local ordered dictionary",
            as: LocalOrderedDictionaryLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runHotHits(
            "class linked list",
            as: ClassLinkedListLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runHotHits(
            "indexed linked list",
            as: IndexedLinkedListLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        print("")
    }

    private static func benchmarkMixedAccess(capacity: Int, keys: [Int]) {
        print("Mixed get-or-insert access")
        runMixed(
            "local ordered dictionary",
            as: LocalOrderedDictionaryLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runMixed(
            "class linked list",
            as: ClassLinkedListLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runMixed(
            "indexed linked list",
            as: IndexedLinkedListLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        print("")
    }

    private static func benchmarkSequentialInsertions(
        capacity: Int,
        operationCount: Int
    ) {
        print("Sequential insertions with eviction")
        runSequential(
            "local ordered dictionary",
            as: LocalOrderedDictionaryLRUCache<Int, Int>.self,
            capacity: capacity,
            operationCount: operationCount
        )
        runSequential(
            "class linked list",
            as: ClassLinkedListLRUCache<Int, Int>.self,
            capacity: capacity,
            operationCount: operationCount
        )
        runSequential(
            "indexed linked list",
            as: IndexedLinkedListLRUCache<Int, Int>.self,
            capacity: capacity,
            operationCount: operationCount
        )
        print("")
    }

    /// Times only the hot-read loop; the cache is created and prefilled in the
    /// untimed `setup` step.
    private static func runHotHits<Cache: LRUCacheCandidate>(
        _ label: String,
        as type: Cache.Type,
        capacity: Int,
        keys: [Int]
    ) where Cache.Key == Int, Cache.Value == Int {
        measure(label, operations: keys.count, setup: {
            var cache = Cache(capacity: capacity)
            prefill(&cache, capacity: capacity)
            return cache
        }) { cache in
            var checksum = 0
            for key in keys {
                checksum &+= cache.value(for: key) ?? 0
            }
            return checksum &+ cache.count
        }
    }

    /// Times only the get-or-insert loop; prefill happens in the untimed
    /// `setup` step.
    private static func runMixed<Cache: LRUCacheCandidate>(
        _ label: String,
        as type: Cache.Type,
        capacity: Int,
        keys: [Int]
    ) where Cache.Key == Int, Cache.Value == Int {
        measure(label, operations: keys.count, setup: {
            var cache = Cache(capacity: capacity)
            prefill(&cache, capacity: capacity)
            return cache
        }) { cache in
            var checksum = 0
            for key in keys {
                if let value = cache.value(for: key) {
                    checksum &+= value
                } else {
                    cache.setValue(key, for: key)
                    checksum &-= key
                }
            }
            return checksum &+ cache.count
        }
    }

    /// Times only the insertion loop; the empty cache is created in the untimed
    /// `setup` step.
    private static func runSequential<Cache: LRUCacheCandidate>(
        _ label: String,
        as type: Cache.Type,
        capacity: Int,
        operationCount: Int
    ) where Cache.Key == Int, Cache.Value == Int {
        measure(label, operations: operationCount, setup: {
            Cache(capacity: capacity)
        }) { cache in
            for key in 0..<operationCount {
                cache.setValue(key, for: key)
            }
            return cache.count
        }
    }

    private static func prefill<Cache: LRUCacheCandidate>(
        _ cache: inout Cache,
        capacity: Int
    ) where Cache.Key == Int, Cache.Value == Int {
        guard capacity > 0 else {
            return
        }

        for key in 0..<capacity {
            cache.setValue(key, for: key)
        }
    }

    private static func measure<State>(
        _ label: String,
        operations: Int,
        iterations: Int = 3,
        setup: () -> State,
        _ body: (inout State) -> Int
    ) {
        var best = UInt64.max
        var checksum = 0

        for _ in 0..<iterations {
            var state = setup()
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= body(&state)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            best = min(best, elapsed)
        }

        let nsPerOperation = operations == 0 ? 0 : Double(best) / Double(operations)
        let formattedNs = String(format: "%.1f", nsPerOperation)
        print(
            "  \(label): \(milliseconds(best)) best of \(iterations), " +
            "\(formattedNs) ns/op (checksum: \(checksum))"
        )
    }

    private static func milliseconds(_ nanoseconds: UInt64) -> String {
        let whole = nanoseconds / 1_000_000
        let fraction = (nanoseconds % 1_000_000) / 1_000
        let fractionText = String(fraction)
        let padding = String(repeating: "0", count: max(0, 3 - fractionText.count))

        return "\(whole).\(padding)\(fractionText) ms"
    }

    private static func makeKeys(
        count: Int,
        keySpace: Int,
        seed: UInt64
    ) -> [Int] {
        guard count > 0 else {
            return []
        }

        var generator = SeededGenerator(seed: seed)
        return (0..<count).map { _ in
            Int(generator.next() % UInt64(keySpace))
        }
    }
}

private protocol LRUCacheCandidate {
    associatedtype Key: Hashable
    associatedtype Value

    init(capacity: Int)

    var count: Int { get }

    mutating func value(for key: Key) -> Value?
    mutating func setValue(_ value: Value, for key: Key)
}

private struct LocalOrderedDictionaryLRUCache<Key: Hashable, Value>: LRUCacheCandidate {
    private let capacity: Int
    private var storage: BenchmarkOrderedDictionary<Key, Value>

    var count: Int {
        storage.count
    }

    init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.capacity = capacity
        self.storage = BenchmarkOrderedDictionary()
        self.storage.reserveCapacity(capacity)
    }

    mutating func value(for key: Key) -> Value? {
        guard let value = storage[key: key] else {
            return nil
        }

        storage.removeValue(forKey: key)
        storage.updateValue(value, forKey: key)
        return value
    }

    mutating func setValue(_ value: Value, for key: Key) {
        guard capacity > 0 else {
            return
        }

        if storage.contains(key: key) {
            storage.removeValue(forKey: key)
            storage.updateValue(value, forKey: key)
            return
        }

        if storage.count == capacity {
            storage.remove(at: 0)
        }

        storage.updateValue(value, forKey: key)
    }
}

private struct BenchmarkOrderedDictionary<Key: Hashable, Value> {
    private typealias Element = (key: Key, value: Value)

    private var elements: [Element] = []
    private var indices: [Key: Int] = [:]

    var count: Int {
        elements.count
    }

    subscript(key key: Key) -> Value? {
        guard let index = indices[key] else {
            return nil
        }

        return elements[index].value
    }

    func contains(key: Key) -> Bool {
        indices[key] != nil
    }

    mutating func reserveCapacity(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
        indices.reserveCapacity(minimumCapacity)
    }

    mutating func updateValue(_ value: Value, forKey key: Key) {
        if let index = indices[key] {
            elements[index].value = value
            return
        }

        indices[key] = elements.count
        elements.append((key: key, value: value))
    }

    @discardableResult
    mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = indices.removeValue(forKey: key) else {
            return nil
        }

        let element = elements.remove(at: index)
        rebuildIndices(startingAt: index)
        return element.value
    }

    mutating func remove(at index: Int) {
        let element = elements.remove(at: index)
        indices.removeValue(forKey: element.key)
        rebuildIndices(startingAt: index)
    }

    private mutating func rebuildIndices(startingAt startIndex: Int) {
        guard startIndex < elements.count else {
            return
        }

        for index in startIndex..<elements.count {
            indices[elements[index].key] = index
        }
    }
}

private struct ClassLinkedListLRUCache<Key: Hashable, Value>: LRUCacheCandidate {
    private let capacity: Int
    private var nodes: [Key: ClassLinkedNode<Key, Value>] = [:]
    private var head: ClassLinkedNode<Key, Value>?
    private var tail: ClassLinkedNode<Key, Value>?

    var count: Int {
        nodes.count
    }

    init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.capacity = capacity
        self.nodes.reserveCapacity(capacity)
    }

    mutating func value(for key: Key) -> Value? {
        guard let node = nodes[key] else {
            return nil
        }

        moveToBack(node)
        return node.value
    }

    mutating func setValue(_ value: Value, for key: Key) {
        guard capacity > 0 else {
            return
        }

        if let node = nodes[key] {
            node.value = value
            moveToBack(node)
            return
        }

        if nodes.count == capacity, let oldest = head {
            remove(oldest)
            nodes.removeValue(forKey: oldest.key)
        }

        let node = ClassLinkedNode(key: key, value: value)
        append(node)
        nodes[key] = node
    }

    private mutating func moveToBack(_ node: ClassLinkedNode<Key, Value>) {
        guard tail !== node else {
            return
        }

        remove(node)
        append(node)
    }

    private mutating func append(_ node: ClassLinkedNode<Key, Value>) {
        node.previous = tail
        node.next = nil

        if let tail {
            tail.next = node
        } else {
            head = node
        }

        tail = node
    }

    private mutating func remove(_ node: ClassLinkedNode<Key, Value>) {
        let previous = node.previous
        let next = node.next

        if let previous {
            previous.next = next
        } else {
            head = next
        }

        if let next {
            next.previous = previous
        } else {
            tail = previous
        }

        node.previous = nil
        node.next = nil
    }
}

private final class ClassLinkedNode<Key: Hashable, Value> {
    let key: Key
    var value: Value
    weak var previous: ClassLinkedNode?
    var next: ClassLinkedNode?

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

private struct IndexedLinkedListLRUCache<Key: Hashable, Value>: LRUCacheCandidate {
    private let capacity: Int
    private var indices: [Key: Int] = [:]
    private var nodes: [IndexedLinkedNode<Key, Value>?] = []
    private var freeList: [Int] = []
    private var head: Int?
    private var tail: Int?

    var count: Int {
        indices.count
    }

    init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.capacity = capacity
        self.indices.reserveCapacity(capacity)
        self.nodes.reserveCapacity(capacity)
        self.freeList.reserveCapacity(capacity)
    }

    mutating func value(for key: Key) -> Value? {
        guard let index = indices[key] else {
            return nil
        }

        moveToBack(index)
        return nodes[index]!.value
    }

    mutating func setValue(_ value: Value, for key: Key) {
        guard capacity > 0 else {
            return
        }

        if let index = indices[key] {
            nodes[index]!.value = value
            moveToBack(index)
            return
        }

        if indices.count == capacity, let oldest = head {
            let oldestKey = nodes[oldest]!.key
            removeIndex(oldest)
            indices.removeValue(forKey: oldestKey)
        }

        let index = allocateNode(key: key, value: value)
        appendIndex(index)
        indices[key] = index
    }

    private mutating func allocateNode(key: Key, value: Value) -> Int {
        let node = IndexedLinkedNode<Key, Value>(
            key: key,
            value: value,
            previous: nil,
            next: nil
        )

        if let index = freeList.popLast() {
            nodes[index] = node
            return index
        }

        nodes.append(node)
        return nodes.count - 1
    }

    private mutating func moveToBack(_ index: Int) {
        guard tail != index else {
            return
        }

        unlinkIndex(index)
        appendIndex(index)
    }

    private mutating func appendIndex(_ index: Int) {
        nodes[index]!.previous = tail
        nodes[index]!.next = nil

        if let tail {
            nodes[tail]!.next = index
        } else {
            head = index
        }

        tail = index
    }

    private mutating func removeIndex(_ index: Int) {
        unlinkIndex(index)
        nodes[index] = nil
        freeList.append(index)
    }

    private mutating func unlinkIndex(_ index: Int) {
        let previous = nodes[index]!.previous
        let next = nodes[index]!.next

        if let previous {
            nodes[previous]!.next = next
        } else {
            head = next
        }

        if let next {
            nodes[next]!.previous = previous
        } else {
            tail = previous
        }

        nodes[index]!.previous = nil
        nodes[index]!.next = nil
    }
}

private struct IndexedLinkedNode<Key: Hashable, Value> {
    let key: Key
    var value: Value
    var previous: Int?
    var next: Int?
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
