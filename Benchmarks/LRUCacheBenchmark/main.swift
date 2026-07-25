//
//  main.swift
//  LRUCacheBenchmark
//
//  Created by weixi on 2026/6/19.
//

import Foundation

@main
struct LRUCacheBenchmark {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())

        if arguments.first == "--trace" {
            try benchmarkTwitterTrace(arguments: arguments.dropFirst())
            return
        }

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

        print("LRUCache implementation benchmark")
        print("capacity: \(capacity)")
        print("operations: \(operationCount)")
        print("")

        benchmarkHotHits(capacity: capacity, keys: hotKeys)
        benchmarkMixedAccess(capacity: capacity, keys: mixedKeys)
        benchmarkSequentialInsertions(
            capacity: capacity,
            operationCount: operationCount
        )
    }

    private static func benchmarkTwitterTrace(
        arguments: ArraySlice<String>
    ) throws {
        guard let path = arguments.first else {
            throw BenchmarkError.missingTracePath
        }

        let capacity = arguments.dropFirst().first.flatMap(Int.init) ?? 16_384
        let requestLimit = arguments.dropFirst(2).first.flatMap(Int.init)
        precondition(capacity >= 0, "Capacity must not be negative")
        if let requestLimit {
            precondition(requestLimit >= 0, "Request limit must not be negative")
        }

        let requests = try loadTwitterCSV(
            at: path,
            requestLimit: requestLimit
        )
        guard !requests.isEmpty else {
            throw BenchmarkError.emptyTrace
        }

        print("LRUCache Twitter trace benchmark")
        print("trace: \(path)")
        print("capacity: \(capacity) entries")
        print("requests: \(requests.count)")
        print("")

        let reference = measureTrace(
            "reference-node LRU",
            as: LocalReferenceLRUCache<UInt64, Int>.self,
            capacity: capacity,
            requests: requests
        )
        let indexed = measureTrace(
            "index-backed LRU",
            as: LocalIndexedLRUCache<UInt64, Int>.self,
            capacity: capacity,
            requests: requests
        )
        _ = measureTrace(
            "NSCache",
            as: LocalNSCache<UInt64, Int>.self,
            capacity: capacity,
            requests: requests
        )

        precondition(
            reference.statistics == indexed.statistics,
            "Exact LRU implementations produced different trace results"
        )
    }

    private static func benchmarkHotHits(capacity: Int, keys: [Int]) {
        print("Hot hit refreshes")
        runHotHits(
            "reference-node LRU",
            as: LocalReferenceLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runHotHits(
            "index-backed LRU",
            as: LocalIndexedLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runHotHits(
            "NSCache",
            as: LocalNSCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        print("")
    }

    private static func benchmarkMixedAccess(capacity: Int, keys: [Int]) {
        print("Mixed get-or-insert access")
        runMixed(
            "reference-node LRU",
            as: LocalReferenceLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runMixed(
            "index-backed LRU",
            as: LocalIndexedLRUCache<Int, Int>.self,
            capacity: capacity,
            keys: keys
        )
        runMixed(
            "NSCache",
            as: LocalNSCache<Int, Int>.self,
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
            "reference-node LRU",
            as: LocalReferenceLRUCache<Int, Int>.self,
            capacity: capacity,
            operationCount: operationCount
        )
        runSequential(
            "index-backed LRU",
            as: LocalIndexedLRUCache<Int, Int>.self,
            capacity: capacity,
            operationCount: operationCount
        )
        runSequential(
            "NSCache",
            as: LocalNSCache<Int, Int>.self,
            capacity: capacity,
            operationCount: operationCount
        )
        print("")
    }

    /// Times only the hot-read loop; cache creation and prefill are untimed.
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
            return checksum
        }
    }

    /// Times only the get-or-insert loop; prefill is untimed.
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
            return checksum
        }
    }

    /// Times only the insertion loop; cache creation is untimed.
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

            guard operationCount > 0 else {
                return 0
            }
            return cache.value(for: operationCount - 1) ?? 0
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

    private static func measureTrace<Cache: LRUCacheCandidate>(
        _ label: String,
        as type: Cache.Type,
        capacity: Int,
        requests: [TraceRequest],
        iterations: Int = 3
    ) -> TraceMeasurement where Cache.Key == UInt64, Cache.Value == Int {
        var best = TraceMeasurement(
            nanoseconds: UInt64.max,
            statistics: TraceStatistics()
        )

        for _ in 0..<iterations {
            var cache = Cache(capacity: capacity)
            var statistics = TraceStatistics()
            let start = DispatchTime.now().uptimeNanoseconds

            for request in requests {
                if let value = cache.value(for: request.objectID) {
                    statistics.hits &+= 1
                    statistics.checksum &+= value
                } else {
                    statistics.misses &+= 1
                    statistics.checksum &-= request.objectSize
                    cache.setValue(request.objectSize, for: request.objectID)
                }
            }

            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            if elapsed < best.nanoseconds {
                best = TraceMeasurement(
                    nanoseconds: elapsed,
                    statistics: statistics
                )
            }
        }

        let nsPerRequest = Double(best.nanoseconds) / Double(requests.count)
        let hitRate = Double(best.statistics.hits) / Double(requests.count)
        print(
            "  \(label): \(milliseconds(best.nanoseconds)) best of " +
            "\(iterations), \(String(format: "%.1f", nsPerRequest)) ns/req, " +
            "hit rate \(String(format: "%.2f%%", hitRate * 100)) " +
            "(checksum: \(best.statistics.checksum))"
        )
        return best
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

    private static func loadTwitterCSV(
        at path: String,
        requestLimit: Int?
    ) throws -> [TraceRequest] {
        let data = try Data(
            contentsOf: URL(fileURLWithPath: path),
            options: .mappedIfSafe
        )
        let estimatedCount = data.count / 36
        var requests: [TraceRequest] = []
        requests.reserveCapacity(min(requestLimit ?? estimatedCount, estimatedCount))

        data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var column = 0
            var number: UInt64 = 0
            var objectID: UInt64 = 0
            var objectSize: UInt64 = 0
            var hasObjectID = false
            var hasObjectSize = false
            var skipLine = false
            var atLineStart = true

            for byte in bytes {
                if skipLine {
                    if byte == 10 {
                        skipLine = false
                        atLineStart = true
                    }
                    continue
                }

                if atLineStart, byte == 35 {
                    skipLine = true
                    continue
                }
                atLineStart = false

                switch byte {
                case 48...57 where column <= 2:
                    number = number &* 10 &+ UInt64(byte - 48)
                case 44:
                    if column == 1 {
                        objectID = number
                        hasObjectID = true
                    } else if column == 2 {
                        objectSize = number
                        hasObjectSize = true
                    }
                    column &+= 1
                    number = 0
                case 10:
                    if hasObjectID, hasObjectSize {
                        requests.append(
                            TraceRequest(
                                objectID: objectID,
                                objectSize: Int(objectSize)
                            )
                        )
                    }

                    if let requestLimit, requests.count >= requestLimit {
                        return
                    }

                    column = 0
                    number = 0
                    objectID = 0
                    objectSize = 0
                    hasObjectID = false
                    hasObjectSize = false
                    atLineStart = true
                default:
                    break
                }
            }

            if hasObjectID, hasObjectSize,
               requestLimit.map({ requests.count < $0 }) ?? true
            {
                requests.append(
                    TraceRequest(
                        objectID: objectID,
                        objectSize: Int(objectSize)
                    )
                )
            }
        }

        return requests
    }
}

private enum BenchmarkError: Error, CustomStringConvertible {
    case missingTracePath
    case emptyTrace

    var description: String {
        switch self {
        case .missingTracePath:
            return "Usage: LRUCacheBenchmark --trace <csv-path> " +
                "[capacity] [request-limit]"
        case .emptyTrace:
            return "The trace did not contain any requests"
        }
    }
}

private struct TraceRequest {
    let objectID: UInt64
    let objectSize: Int
}

private struct TraceStatistics: Equatable {
    var hits = 0
    var misses = 0
    var checksum = 0
}

private struct TraceMeasurement {
    let nanoseconds: UInt64
    let statistics: TraceStatistics
}

private protocol LRUCacheCandidate {
    associatedtype Key: Hashable
    associatedtype Value

    init(capacity: Int)

    mutating func value(for key: Key) -> Value?
    mutating func setValue(_ value: Value, for key: Key)
}

/// Mirrors Bedrock's `ReferenceLRUCache` in this compilation unit so the
/// benchmark does not include module-boundary effects.
private final class LocalReferenceLRUCache<Key: Hashable, Value>:
    LRUCacheCandidate
{
    private let capacity: Int
    private var nodes: [Key: ReferenceNode<Key, Value>] = [:]
    private var head: ReferenceNode<Key, Value>?
    private var tail: ReferenceNode<Key, Value>?

    init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.capacity = capacity
        nodes.reserveCapacity(capacity)
    }

    func value(for key: Key) -> Value? {
        guard let node = nodes[key] else {
            return nil
        }

        moveToBack(node)
        return node.value
    }

    func setValue(_ value: Value, for key: Key) {
        guard capacity > 0 else {
            return
        }

        if let node = nodes[key] {
            node.value = value
            moveToBack(node)
            return
        }

        if nodes.count == capacity, let oldest = head {
            unlink(oldest)
            nodes.removeValue(forKey: oldest.key)
        }

        let node = ReferenceNode(key: key, value: value)
        append(node)
        nodes[key] = node
    }

    private func moveToBack(_ node: ReferenceNode<Key, Value>) {
        guard tail !== node else {
            return
        }

        unlink(node)
        append(node)
    }

    private func append(_ node: ReferenceNode<Key, Value>) {
        node.previous = tail
        node.next = nil

        if let tail {
            tail.next = node
        } else {
            head = node
        }

        tail = node
    }

    private func unlink(_ node: ReferenceNode<Key, Value>) {
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

private final class ReferenceNode<Key: Hashable, Value> {
    let key: Key
    var value: Value
    weak var previous: ReferenceNode?
    var next: ReferenceNode?

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

/// Mirrors Bedrock's `LRUCache` in this compilation unit so the benchmark does
/// not include module-boundary effects.
private struct LocalIndexedLRUCache<Key: Hashable, Value>: LRUCacheCandidate {
    private let capacity: Int
    private var indices: [Key: Int] = [:]
    private var nodes: [IndexedNode<Key, Value>?] = []
    private var freeList: [Int] = []
    private var head: Int?
    private var tail: Int?

    init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.capacity = capacity
        indices.reserveCapacity(capacity)
        nodes.reserveCapacity(capacity)
        freeList.reserveCapacity(capacity)
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
        let node = IndexedNode(
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

private struct IndexedNode<Key: Hashable, Value> {
    let key: Key
    var value: Value
    var previous: Int?
    var next: Int?
}

/// Adapts generic Swift keys and values to `NSCache`'s object-only API.
///
/// `NSCache.countLimit` is not a strict capacity guarantee and its eviction
/// order is intentionally unspecified. This candidate is therefore a
/// performance baseline, not an exact semantic substitute for the LRU types.
private final class LocalNSCache<Key: Hashable, Value>: LRUCacheCandidate {
    private let capacity: Int
    private let storage = NSCache<NSCacheKey<Key>, NSCacheValue<Value>>()

    init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.capacity = capacity
        storage.countLimit = capacity
    }

    func value(for key: Key) -> Value? {
        storage.object(forKey: NSCacheKey(key))?.value
    }

    func setValue(_ value: Value, for key: Key) {
        guard capacity > 0 else {
            return
        }

        storage.setObject(NSCacheValue(value), forKey: NSCacheKey(key))
    }
}

private final class NSCacheKey<Key: Hashable>: NSObject {
    let value: Key

    init(_ value: Key) {
        self.value = value
    }

    override var hash: Int {
        value.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? NSCacheKey else {
            return false
        }

        return value == other.value
    }
}

private final class NSCacheValue<Value>: NSObject {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
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
