//
//  LRUCache.swift
//  Bedrock
//
//  Created by weixi on 2026/6/21.
//

/// A fixed-capacity least-recently-used cache.
///
/// `LRUCache` keeps key/value pairs ordered from least recently used to most
/// recently used. Reading a value through `value(forKey:)` refreshes that
/// entry, moving it to the most-recent position. `peekValue(forKey:)` reads
/// without changing recency.
///
/// The cache is backed by a hash table for lookup and an index-linked list for
/// recency order, so lookup, refresh, insertion, update, and eviction are O(1)
/// on average.
public struct LRUCache<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)

    @usableFromInline
    internal var indices: [Key: Int]

    @usableFromInline
    internal var nodes: [LRUCacheNode<Key, Value>?]

    @usableFromInline
    internal var freeList: [Int]

    @usableFromInline
    internal var leastRecentIndex: Int?

    @usableFromInline
    internal var mostRecentIndex: Int?

    /// The maximum number of key/value pairs the cache can hold.
    ///
    /// - Complexity: O(1).
    public let capacity: Int

    /// Creates an empty cache with the given capacity.
    ///
    /// - Precondition: `capacity` is not negative.
    /// - Complexity: O(1).
    @inlinable
    public init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.capacity = capacity
        self.indices = [:]
        self.nodes = []
        self.freeList = []
        self.leastRecentIndex = nil
        self.mostRecentIndex = nil

        indices.reserveCapacity(capacity)
        nodes.reserveCapacity(capacity)
        freeList.reserveCapacity(capacity)
    }

    /// Creates a cache from a sequence of key/value pairs.
    ///
    /// Pairs are inserted in order. If more pairs are inserted than the cache
    /// can hold, the least recently used pairs are evicted. If a key appears
    /// more than once, the latest value wins and the key becomes most recent.
    ///
    /// - Precondition: `capacity` is not negative.
    /// - Complexity: O(*n*) on average, where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(
        _ elements: S,
        capacity: Int
    ) where S.Element == Element {
        self.init(capacity: capacity)

        for element in elements {
            updateValue(element.value, forKey: element.key)
        }
    }

    /// The number of key/value pairs currently stored in the cache.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var count: Int {
        indices.count
    }

    /// A Boolean value indicating whether the cache is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        indices.isEmpty
    }

    /// A Boolean value indicating whether the cache is full.
    ///
    /// A zero-capacity cache is always full.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isFull: Bool {
        count == capacity
    }

    /// The least recently used key/value pair, or `nil` if the cache is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var leastRecentlyUsed: Element? {
        guard let index = leastRecentIndex else {
            return nil
        }

        let node = nodes[index]!
        return (key: node.key, value: node.value)
    }

    /// The most recently used key/value pair, or `nil` if the cache is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var mostRecentlyUsed: Element? {
        guard let index = mostRecentIndex else {
            return nil
        }

        let node = nodes[index]!
        return (key: node.key, value: node.value)
    }

    /// The keys of the cache, ordered from least to most recently used.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var keys: [Key] {
        elements.map(\.key)
    }

    /// The values of the cache, ordered from least to most recently used.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var values: [Value] {
        elements.map(\.value)
    }

    /// The key/value pairs of the cache, ordered from least to most recently
    /// used.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var elements: [Element] {
        var ordered: [Element] = []
        ordered.reserveCapacity(count)

        var current = leastRecentIndex
        while let index = current {
            let node = nodes[index]!
            ordered.append((key: node.key, value: node.value))
            current = node.next
        }

        return ordered
    }

    /// Returns a Boolean value indicating whether the cache contains `key`.
    ///
    /// Checking membership does not change recency.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    public func contains(key: Key) -> Bool {
        indices[key] != nil
    }

    /// Returns the value for `key` and refreshes it as most recently used.
    ///
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public mutating func value(forKey key: Key) -> Value? {
        guard let index = indices[key] else {
            return nil
        }

        moveToMostRecent(index)
        return nodes[index]!.value
    }

    /// Returns the value for `key` without changing recency.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    public func peekValue(forKey key: Key) -> Value? {
        guard let index = indices[key] else {
            return nil
        }

        return nodes[index]!.value
    }

    /// Inserts or updates a value and marks the key as most recently used.
    ///
    /// If the key is new and the cache is full, the least recently used entry
    /// is evicted first.
    ///
    /// - Returns: The value previously associated with `key`, or `nil` if the
    ///   key was newly inserted.
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        guard capacity > 0 else {
            return nil
        }

        if let index = indices[key] {
            let oldValue = nodes[index]!.value
            nodes[index]!.value = value
            moveToMostRecent(index)
            return oldValue
        }

        if isFull {
            removeLeastRecentlyUsed()
        }

        let index = allocateNode(key: key, value: value)
        appendAsMostRecent(index)
        indices[key] = index
        return nil
    }

    /// Removes and returns the value for `key`.
    ///
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = indices.removeValue(forKey: key) else {
            return nil
        }

        let node = removeNode(at: index)
        return node.value
    }

    /// Removes and returns the least recently used key/value pair.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func removeLeastRecentlyUsed() -> Element? {
        guard let index = leastRecentIndex else {
            return nil
        }

        let node = removeNode(at: index)
        indices.removeValue(forKey: node.key)
        return (key: node.key, value: node.value)
    }

    /// Removes and returns the most recently used key/value pair.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func removeMostRecentlyUsed() -> Element? {
        guard let index = mostRecentIndex else {
            return nil
        }

        let node = removeNode(at: index)
        indices.removeValue(forKey: node.key)
        return (key: node.key, value: node.value)
    }

    /// Removes all key/value pairs.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        indices.removeAll(keepingCapacity: keepCapacity)
        nodes.removeAll(keepingCapacity: keepCapacity)
        freeList.removeAll(keepingCapacity: keepCapacity)
        leastRecentIndex = nil
        mostRecentIndex = nil

        if keepCapacity {
            indices.reserveCapacity(capacity)
            nodes.reserveCapacity(capacity)
            freeList.reserveCapacity(capacity)
        }
    }

    @usableFromInline
    internal mutating func allocateNode(key: Key, value: Value) -> Int {
        let node = LRUCacheNode(
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

    @usableFromInline
    internal mutating func moveToMostRecent(_ index: Int) {
        guard mostRecentIndex != index else {
            return
        }

        unlinkNode(at: index)
        appendAsMostRecent(index)
    }

    @usableFromInline
    internal mutating func appendAsMostRecent(_ index: Int) {
        nodes[index]!.previous = mostRecentIndex
        nodes[index]!.next = nil

        if let mostRecentIndex {
            nodes[mostRecentIndex]!.next = index
        } else {
            leastRecentIndex = index
        }

        mostRecentIndex = index
    }

    @usableFromInline
    internal mutating func removeNode(at index: Int) -> LRUCacheNode<Key, Value> {
        unlinkNode(at: index)

        let node = nodes[index]!
        nodes[index] = nil
        freeList.append(index)
        return node
    }

    @usableFromInline
    internal mutating func unlinkNode(at index: Int) {
        let previous = nodes[index]!.previous
        let next = nodes[index]!.next

        if let previous {
            nodes[previous]!.next = next
        } else {
            leastRecentIndex = next
        }

        if let next {
            nodes[next]!.previous = previous
        } else {
            mostRecentIndex = previous
        }

        nodes[index]!.previous = nil
        nodes[index]!.next = nil
    }
}

@usableFromInline
internal struct LRUCacheNode<Key: Hashable, Value> {
    @usableFromInline
    internal var key: Key

    @usableFromInline
    internal var value: Value

    @usableFromInline
    internal var previous: Int?

    @usableFromInline
    internal var next: Int?
}

extension LRUCacheNode: Sendable where Key: Sendable, Value: Sendable {}

extension LRUCache: Sendable where Key: Sendable, Value: Sendable {}

extension LRUCache: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.capacity == rhs.capacity,
              lhs.count == rhs.count
        else {
            return false
        }

        let lhsElements = lhs.elements
        let rhsElements = rhs.elements
        for index in lhsElements.indices {
            let lhsElement = lhsElements[index]
            let rhsElement = rhsElements[index]

            guard lhsElement.key == rhsElement.key,
                  lhsElement.value == rhsElement.value
            else {
                return false
            }
        }

        return true
    }
}

extension LRUCache: Hashable where Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(capacity)
        hasher.combine(count)

        for element in elements {
            hasher.combine(element.key)
            hasher.combine(element.value)
        }
    }
}

extension LRUCache: CustomStringConvertible {
    /// A textual representation listing entries from least to most recently
    /// used.
    public var description: String {
        let members = elements.map { "\($0.key): \($0.value)" }
        return "[\(members.joined(separator: ", "))]"
    }
}

extension LRUCache: CustomDebugStringConvertible {
    public var debugDescription: String {
        let members = elements.map {
            "\(String(reflecting: $0.key)): \(String(reflecting: $0.value))"
        }
        return "LRUCache(capacity: \(capacity), [\(members.joined(separator: ", "))])"
    }
}
