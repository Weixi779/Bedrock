//
//  OrderedDictionary.swift
//  Bedrock
//
//  Created by weixi on 2026/6/18.
//

/// A hash-backed dictionary that remembers the insertion order of its keys.
///
/// `OrderedDictionary` stores its elements contiguously in insertion order and
/// keeps a `[Key: Int]` side table for O(1) key lookups. Iteration always
/// reflects insertion order, and integer subscripting gives random access into
/// that order.
///
/// Equality and hashing are **order-sensitive**: two dictionaries are equal
/// only if they contain the same key/value pairs in the same order. As a
/// result `["a": 1, "b": 2]` is *not* equal to `["b": 2, "a": 1]`, which
/// differs from the standard `Dictionary`.
public struct OrderedDictionary<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)

    @usableFromInline
    internal var elements: [Element]

    @usableFromInline
    internal var indices: [Key: Int]

    /// Creates an empty dictionary.
    @inlinable
    public init() {
        self.elements = []
        self.indices = [:]
    }

    /// Creates a dictionary from a sequence of key/value pairs.
    ///
    /// Pairs are inserted in order. If the same key appears more than once, the
    /// later value overwrites the earlier one while keeping the key's original
    /// position.
    ///
    /// - Complexity: O(*n*) on average, where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.init()
        reserveCapacity(elements.underestimatedCount)

        for element in elements {
            updateValue(element.value, forKey: element.key)
        }
    }

    /// The number of key/value pairs in the dictionary.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var count: Int {
        elements.count
    }

    /// A Boolean value indicating whether the dictionary is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        elements.isEmpty
    }

    /// The keys of the dictionary, in order.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var keys: [Key] {
        elements.map(\.key)
    }

    /// The values of the dictionary, in order.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var values: [Value] {
        elements.map(\.value)
    }

    /// Accesses the value associated with the given key.
    ///
    /// Reading returns `nil` for a missing key. Writing a value updates or
    /// inserts the key; writing `nil` removes it.
    ///
    /// - Complexity: O(1) for reads and updates. Removing or inserting through
    ///   this subscript is O(*n*) because following indices are rebuilt.
    @inlinable
    public subscript(key key: Key) -> Value? {
        get {
            guard let index = indices[key] else {
                return nil
            }

            return elements[index].value
        }
        set {
            guard let newValue else {
                removeValue(forKey: key)
                return
            }

            updateValue(newValue, forKey: key)
        }
    }

    /// Accesses the key/value pair at the given position.
    ///
    /// - Complexity: O(1).
    @inlinable
    public subscript(position: Int) -> Element {
        elements[position]
    }

    /// Returns the position of the given key, or `nil` if it is not present.
    ///
    /// - Complexity: O(1).
    @inlinable
    public func index(forKey key: Key) -> Int? {
        indices[key]
    }

    /// Returns a Boolean value indicating whether the dictionary contains the
    /// given key.
    ///
    /// - Complexity: O(1).
    @inlinable
    public func contains(key: Key) -> Bool {
        indices[key] != nil
    }

    /// Updates the value for the given key, appending the key if it is new.
    ///
    /// - Returns: The value previously associated with the key, or `nil` if the
    ///   key was newly inserted.
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        if let index = indices[key] {
            let oldValue = elements[index].value
            elements[index].value = value
            return oldValue
        }

        indices[key] = elements.count
        elements.append((key: key, value: value))
        return nil
    }

    /// Inserts a value for a new key at the given position.
    ///
    /// - Precondition: `key` is not already present, and `index` is within
    ///   `0...count`.
    /// - Complexity: O(*n*) because following indices are rebuilt.
    @inlinable
    public mutating func insert(_ value: Value, forKey key: Key, at index: Int) {
        precondition(indices[key] == nil, "Duplicate key: \(key)")
        precondition(index >= 0 && index <= elements.count, "Index out of range")

        elements.insert((key: key, value: value), at: index)
        rebuildIndices(startingAt: index)
    }

    /// Reserves enough storage to hold the requested number of pairs.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
        indices.reserveCapacity(minimumCapacity)
    }

    /// Removes the value for the given key, preserving the order of the rest.
    ///
    /// - Returns: The removed value, or `nil` if the key was not present.
    /// - Complexity: O(*n*) because following indices are rebuilt.
    @discardableResult
    @inlinable
    public mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = indices.removeValue(forKey: key) else {
            return nil
        }

        let element = elements.remove(at: index)
        rebuildIndices(startingAt: index)
        return element.value
    }

    /// Removes and returns the key/value pair at the given position.
    ///
    /// - Complexity: O(*n*) because following indices are rebuilt.
    @discardableResult
    @inlinable
    public mutating func remove(at index: Int) -> Element {
        let element = elements.remove(at: index)
        indices.removeValue(forKey: element.key)
        rebuildIndices(startingAt: index)
        return element
    }

    /// Removes all key/value pairs.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        elements.removeAll(keepingCapacity: keepCapacity)
        indices.removeAll(keepingCapacity: keepCapacity)
    }

    @usableFromInline
    internal mutating func rebuildIndices(startingAt startIndex: Int = 0) {
        guard startIndex < elements.count else {
            return
        }

        for index in startIndex..<elements.count {
            indices[elements[index].key] = index
        }
    }
}

extension OrderedDictionary: Sendable where Key: Sendable, Value: Sendable {}

extension OrderedDictionary: Equatable where Value: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.elements.count == rhs.elements.count else {
            return false
        }

        for index in lhs.elements.indices {
            let lhsElement = lhs.elements[index]
            let rhsElement = rhs.elements[index]

            guard lhsElement.key == rhsElement.key,
                  lhsElement.value == rhsElement.value
            else {
                return false
            }
        }

        return true
    }
}

extension OrderedDictionary: Hashable where Value: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements.count)

        for element in elements {
            hasher.combine(element.key)
            hasher.combine(element.value)
        }
    }
}

extension OrderedDictionary: CustomStringConvertible {
    public var description: String {
        let pairs = elements.map { "\($0.key): \($0.value)" }
        return "[\(pairs.joined(separator: ", "))]"
    }
}

extension OrderedDictionary: CustomDebugStringConvertible {
    public var debugDescription: String {
        let pairs = elements.map { "\(String(reflecting: $0.key)): \(String(reflecting: $0.value))" }
        return "OrderedDictionary([\(pairs.joined(separator: ", "))])"
    }
}

extension OrderedDictionary: ExpressibleByDictionaryLiteral {
    @inlinable
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init()
        reserveCapacity(elements.count)

        for (key, value) in elements {
            updateValue(value, forKey: key)
        }
    }
}

extension OrderedDictionary: RandomAccessCollection {
    @inlinable
    public var startIndex: Int {
        elements.startIndex
    }

    @inlinable
    public var endIndex: Int {
        elements.endIndex
    }

    @inlinable
    public func index(after index: Int) -> Int {
        elements.index(after: index)
    }

    @inlinable
    public func index(before index: Int) -> Int {
        elements.index(before: index)
    }
}
