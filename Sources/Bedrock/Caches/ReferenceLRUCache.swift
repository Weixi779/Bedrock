//
//  ReferenceLRUCache.swift
//  Bedrock
//
//  Created by weixi on 2026/7/25.
//

/// A reference-semantic, fixed-capacity least-recently-used cache.
///
/// `ReferenceLRUCache` keeps key/value pairs ordered from least recently used
/// to most recently used. Reading a value through `value(forKey:)` refreshes
/// that entry, moving it to the most-recent position. `peekValue(forKey:)`
/// reads without changing recency.
///
/// The cache is backed by a hash table and reference-linked nodes. Lookup,
/// refresh, insertion, update, and eviction are O(1) on average.
///
/// Unlike ``LRUCache``, this type has reference semantics. Assigning it to
/// another variable shares the same cache and mutations. The cache does not
/// provide internal synchronization.
public final class ReferenceLRUCache<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)

    @usableFromInline
    internal var nodes: [Key: ReferenceLRUCacheNode<Key, Value>]

    @usableFromInline
    internal var leastRecentNode: ReferenceLRUCacheNode<Key, Value>?

    @usableFromInline
    internal var mostRecentNode: ReferenceLRUCacheNode<Key, Value>?

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
        self.nodes = [:]
        self.leastRecentNode = nil
        self.mostRecentNode = nil
        nodes.reserveCapacity(capacity)
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
    public convenience init<S: Sequence>(
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
        nodes.count
    }

    /// A Boolean value indicating whether the cache is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        nodes.isEmpty
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
        guard let node = leastRecentNode else {
            return nil
        }

        return (key: node.key, value: node.value)
    }

    /// The most recently used key/value pair, or `nil` if the cache is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var mostRecentlyUsed: Element? {
        guard let node = mostRecentNode else {
            return nil
        }

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

    /// The key/value pairs ordered from least to most recently used.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var elements: [Element] {
        var ordered: [Element] = []
        ordered.reserveCapacity(count)

        var current = leastRecentNode
        while let node = current {
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
        nodes[key] != nil
    }

    /// Returns the value for `key` and refreshes it as most recently used.
    ///
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public func value(forKey key: Key) -> Value? {
        guard let node = nodes[key] else {
            return nil
        }

        moveToMostRecent(node)
        return node.value
    }

    /// Returns the value for `key` without changing recency.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    public func peekValue(forKey key: Key) -> Value? {
        nodes[key]?.value
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
    public func updateValue(_ value: Value, forKey key: Key) -> Value? {
        guard capacity > 0 else {
            return nil
        }

        if let node = nodes[key] {
            let oldValue = node.value
            node.value = value
            moveToMostRecent(node)
            return oldValue
        }

        if isFull {
            removeLeastRecentlyUsed()
        }

        let node = ReferenceLRUCacheNode(key: key, value: value)
        appendAsMostRecent(node)
        nodes[key] = node
        return nil
    }

    /// Removes and returns the value for `key`.
    ///
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public func removeValue(forKey key: Key) -> Value? {
        guard let node = nodes.removeValue(forKey: key) else {
            return nil
        }

        unlink(node)
        return node.value
    }

    /// Removes and returns the least recently used key/value pair.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public func removeLeastRecentlyUsed() -> Element? {
        guard let node = leastRecentNode else {
            return nil
        }

        unlink(node)
        nodes.removeValue(forKey: node.key)
        return (key: node.key, value: node.value)
    }

    /// Removes and returns the most recently used key/value pair.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public func removeMostRecentlyUsed() -> Element? {
        guard let node = mostRecentNode else {
            return nil
        }

        unlink(node)
        nodes.removeValue(forKey: node.key)
        return (key: node.key, value: node.value)
    }

    /// Removes all key/value pairs.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public func removeAll(keepingCapacity keepCapacity: Bool = false) {
        nodes.removeAll(keepingCapacity: keepCapacity)
        leastRecentNode = nil
        mostRecentNode = nil

        if keepCapacity {
            nodes.reserveCapacity(capacity)
        }
    }

    @usableFromInline
    internal func moveToMostRecent(
        _ node: ReferenceLRUCacheNode<Key, Value>
    ) {
        guard mostRecentNode !== node else {
            return
        }

        unlink(node)
        appendAsMostRecent(node)
    }

    @usableFromInline
    internal func appendAsMostRecent(
        _ node: ReferenceLRUCacheNode<Key, Value>
    ) {
        node.previous = mostRecentNode
        node.next = nil

        if let mostRecentNode {
            mostRecentNode.next = node
        } else {
            leastRecentNode = node
        }

        mostRecentNode = node
    }

    @usableFromInline
    internal func unlink(_ node: ReferenceLRUCacheNode<Key, Value>) {
        let previous = node.previous
        let next = node.next

        if let previous {
            previous.next = next
        } else {
            leastRecentNode = next
        }

        if let next {
            next.previous = previous
        } else {
            mostRecentNode = previous
        }

        node.previous = nil
        node.next = nil
    }
}

@usableFromInline
internal final class ReferenceLRUCacheNode<Key: Hashable, Value> {
    @usableFromInline
    internal let key: Key

    @usableFromInline
    internal var value: Value

    @usableFromInline
    internal weak var previous: ReferenceLRUCacheNode?

    @usableFromInline
    internal var next: ReferenceLRUCacheNode?

    @usableFromInline
    internal init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

extension ReferenceLRUCache: CustomStringConvertible {
    /// A textual representation listing entries from least to most recently
    /// used.
    public var description: String {
        let members = elements.map { "\($0.key): \($0.value)" }
        return "[\(members.joined(separator: ", "))]"
    }
}

extension ReferenceLRUCache: CustomDebugStringConvertible {
    public var debugDescription: String {
        let members = elements.map {
            "\(String(reflecting: $0.key)): \(String(reflecting: $0.value))"
        }
        return "ReferenceLRUCache(" +
            "capacity: \(capacity), [\(members.joined(separator: ", "))])"
    }
}
