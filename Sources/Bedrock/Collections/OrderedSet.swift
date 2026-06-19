//
//  OrderedSet.swift
//  Bedrock
//
//  Created by weixi on 2026/6/18.
//

/// A hash-backed set that remembers the insertion order of its members.
///
/// `OrderedSet` stores its members contiguously in insertion order and keeps a
/// `[Element: Int]` side table for O(1) membership tests. Iteration always
/// reflects insertion order, and integer subscripting gives random access into
/// that order.
///
/// Equality and hashing are **order-sensitive**: two sets are equal only if
/// they contain the same members in the same order. As a result
/// `OrderedSet([1, 2])` is *not* equal to `OrderedSet([2, 1])`, which differs
/// from the standard `Set`.
public struct OrderedSet<Element: Hashable> {
    @usableFromInline
    internal var elements: [Element]

    @usableFromInline
    internal var indices: [Element: Int]

    /// Creates an empty set.
    @inlinable
    public init() {
        self.elements = []
        self.indices = [:]
    }

    /// Creates a set from a sequence, keeping the first occurrence of each
    /// member and discarding later duplicates.
    ///
    /// - Complexity: O(*n*) on average, where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.init()
        reserveCapacity(elements.underestimatedCount)

        for element in elements {
            insert(element)
        }
    }

    /// The number of members in the set.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var count: Int {
        elements.count
    }

    /// A Boolean value indicating whether the set is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        elements.isEmpty
    }

    /// Accesses the member at the given position.
    ///
    /// - Complexity: O(1).
    @inlinable
    public subscript(position: Int) -> Element {
        elements[position]
    }

    /// Returns a Boolean value indicating whether the set contains the member.
    ///
    /// - Complexity: O(1).
    @inlinable
    public func contains(_ element: Element) -> Bool {
        indices[element] != nil
    }

    /// Returns the position of the given member, or `nil` if it is not present.
    ///
    /// - Complexity: O(1).
    @inlinable
    public func index(for element: Element) -> Int? {
        indices[element]
    }

    /// Inserts a member, appending it if it is new.
    ///
    /// - Returns: `true` if the member was inserted, `false` if it was already
    ///   present.
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public mutating func insert(_ element: Element) -> Bool {
        guard indices[element] == nil else {
            return false
        }

        indices[element] = elements.count
        elements.append(element)
        return true
    }

    /// Inserts a new member at the given position.
    ///
    /// If the member is already present the set is left unchanged.
    ///
    /// - Returns: `true` if the member was inserted, `false` if it was already
    ///   present.
    /// - Precondition: `index` is within `0...count`.
    /// - Complexity: O(*n*) because following indices are rebuilt.
    @discardableResult
    @inlinable
    public mutating func insert(_ element: Element, at index: Int) -> Bool {
        precondition(index >= 0 && index <= elements.count, "Index out of range")

        guard indices[element] == nil else {
            return false
        }

        elements.insert(element, at: index)
        rebuildIndices(startingAt: index)
        return true
    }

    /// Reserves enough storage to hold the requested number of members.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
        indices.reserveCapacity(minimumCapacity)
    }

    /// Inserts a member, or replaces an existing equal member in place.
    ///
    /// - Returns: The member that was replaced, or `nil` if the member is new.
    /// - Complexity: O(1) on average.
    @discardableResult
    @inlinable
    public mutating func update(with element: Element) -> Element? {
        guard let index = indices[element] else {
            indices[element] = elements.count
            elements.append(element)
            return nil
        }

        let oldElement = elements[index]
        elements[index] = element
        indices.removeValue(forKey: oldElement)
        indices[element] = index
        return oldElement
    }

    /// Removes the given member, preserving the order of the rest.
    ///
    /// - Returns: The removed member, or `nil` if it was not present.
    /// - Complexity: O(*n*) because following indices are rebuilt.
    @discardableResult
    @inlinable
    public mutating func remove(_ element: Element) -> Element? {
        guard let index = indices.removeValue(forKey: element) else {
            return nil
        }

        let oldElement = elements.remove(at: index)
        rebuildIndices(startingAt: index)
        return oldElement
    }

    /// Removes and returns the member at the given position.
    ///
    /// - Complexity: O(*n*) because following indices are rebuilt.
    @discardableResult
    @inlinable
    public mutating func remove(at index: Int) -> Element {
        let element = elements.remove(at: index)
        indices.removeValue(forKey: element)
        rebuildIndices(startingAt: index)
        return element
    }

    /// Removes all members.
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
            indices[elements[index]] = index
        }
    }
}

// MARK: - Set algebra

extension OrderedSet {
    /// Returns a new set with the members of both this set and the given
    /// sequence.
    ///
    /// Members of this set come first in their existing order, followed by new
    /// members from `other` in the order they are first encountered.
    ///
    /// - Complexity: O(*n* + *m*) on average.
    @inlinable
    public func union<S: Sequence>(_ other: S) -> OrderedSet where S.Element == Element {
        var result = self
        result.formUnion(other)
        return result
    }

    /// Inserts the members of the given sequence that are not already present.
    ///
    /// - Complexity: O(*m*) on average, where *m* is the length of `other`.
    @inlinable
    public mutating func formUnion<S: Sequence>(_ other: S) where S.Element == Element {
        for element in other {
            insert(element)
        }
    }

    /// Returns a new set with the members that are also in the given sequence,
    /// keeping this set's order.
    ///
    /// - Complexity: O(*n* + *m*) on average.
    @inlinable
    public func intersection<S: Sequence>(_ other: S) -> OrderedSet where S.Element == Element {
        let otherMembers = Set(other)
        var result = OrderedSet()
        for element in elements where otherMembers.contains(element) {
            result.insert(element)
        }
        return result
    }

    /// Removes the members that are not also in the given sequence.
    ///
    /// - Complexity: O(*n* + *m*) on average.
    @inlinable
    public mutating func formIntersection<S: Sequence>(_ other: S) where S.Element == Element {
        self = intersection(other)
    }

    /// Returns a new set with the members that are not in the given sequence,
    /// keeping this set's order.
    ///
    /// - Complexity: O(*n* + *m*) on average.
    @inlinable
    public func subtracting<S: Sequence>(_ other: S) -> OrderedSet where S.Element == Element {
        let otherMembers = Set(other)
        var result = OrderedSet()
        for element in elements where !otherMembers.contains(element) {
            result.insert(element)
        }
        return result
    }

    /// Removes the members that are also in the given sequence.
    ///
    /// - Complexity: O(*n* + *m*) on average.
    @inlinable
    public mutating func subtract<S: Sequence>(_ other: S) where S.Element == Element {
        self = subtracting(other)
    }

    /// Returns a new set with the members that are in either this set or the
    /// given sequence, but not both.
    ///
    /// This set's surviving members keep their order and come first, followed
    /// by the surviving members of `other` in their encountered order.
    ///
    /// - Complexity: O(*n* + *m*) on average.
    @inlinable
    public func symmetricDifference<S: Sequence>(_ other: S) -> OrderedSet where S.Element == Element {
        let otherSet = OrderedSet(other)
        var result = OrderedSet()
        for element in elements where !otherSet.contains(element) {
            result.insert(element)
        }
        for element in otherSet where !contains(element) {
            result.insert(element)
        }
        return result
    }

    /// Replaces this set with the members that are in either this set or the
    /// given sequence, but not both.
    ///
    /// - Complexity: O(*n* + *m*) on average.
    @inlinable
    public mutating func formSymmetricDifference<S: Sequence>(_ other: S) where S.Element == Element {
        self = symmetricDifference(other)
    }
}

extension OrderedSet: Sendable where Element: Sendable {}

extension OrderedSet: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.elements == rhs.elements
    }
}

extension OrderedSet: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements)
    }
}

extension OrderedSet: CustomStringConvertible {
    public var description: String {
        let members = elements.map { "\($0)" }
        return "[\(members.joined(separator: ", "))]"
    }
}

extension OrderedSet: CustomDebugStringConvertible {
    public var debugDescription: String {
        let members = elements.map { String(reflecting: $0) }
        return "OrderedSet([\(members.joined(separator: ", "))])"
    }
}

extension OrderedSet: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension OrderedSet: RandomAccessCollection {
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
