//
//  RingBuffer.swift
//  Bedrock
//
//  Created by weixi on 2026/6/19.
//

/// A fixed-capacity first-in, first-out circular buffer.
///
/// `RingBuffer` stores up to `capacity` elements in insertion order. Appending
/// to a full buffer overwrites and returns the oldest element. This makes the
/// type useful for bounded histories, rolling logs, and fixed-size recent-value
/// windows.
///
/// `RingBuffer` is a capacity-bounded policy layer over `Deque`: it delegates
/// storage and ordering to a backing deque and only enforces the fixed capacity
/// and overwrite-on-full behavior.
public struct RingBuffer<Element> {
    @usableFromInline
    internal var base: Deque<Element>

    /// The maximum number of elements the buffer can store.
    ///
    /// - Complexity: O(1).
    public let capacity: Int

    /// Creates an empty ring buffer with the given fixed capacity.
    ///
    /// - Precondition: `capacity` is not negative.
    /// - Complexity: O(*capacity*).
    @inlinable
    public init(capacity: Int) {
        precondition(capacity >= 0, "Capacity must not be negative")

        self.base = Deque(minimumCapacity: capacity)
        self.capacity = capacity
    }

    /// Creates a ring buffer from a sequence.
    ///
    /// If `elements` contains more values than `capacity`, the buffer keeps the
    /// newest `capacity` values and discards earlier values.
    ///
    /// - Precondition: `capacity` is not negative.
    /// - Complexity: O(*n*), where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(
        _ elements: S,
        capacity: Int
    ) where S.Element == Element {
        self.init(capacity: capacity)

        for element in elements {
            append(element)
        }
    }

    /// The number of elements currently stored in the buffer.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var count: Int {
        base.count
    }

    /// A Boolean value indicating whether the buffer is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        base.isEmpty
    }

    /// A Boolean value indicating whether the buffer is full.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isFull: Bool {
        base.count == capacity
    }

    /// The oldest element, or `nil` if the buffer is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var front: Element? {
        base.front
    }

    /// The newest element, or `nil` if the buffer is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var back: Element? {
        base.back
    }

    /// The elements in oldest-to-newest order.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var elements: [Element] {
        base.elements
    }

    /// Adds an element as the newest value.
    ///
    /// If the buffer is full, this overwrites and returns the oldest element.
    /// If `capacity` is zero, the new element is returned without being stored.
    ///
    /// - Returns: The overwritten or discarded element, or `nil` if no element
    ///   was removed.
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func append(_ element: Element) -> Element? {
        guard capacity > 0 else {
            return element
        }

        var removed: Element?
        if base.count == capacity {
            removed = base.popFirst()
        }

        base.append(element)
        return removed
    }

    /// Adds the elements of a sequence as newest values.
    ///
    /// - Returns: The overwritten or discarded elements in the order they were
    ///   removed.
    /// - Complexity: O(*n*), where *n* is the length of `newElements`.
    @discardableResult
    @inlinable
    public mutating func append<S: Sequence>(
        contentsOf newElements: S
    ) -> [Element] where S.Element == Element {
        var removed: [Element] = []

        for element in newElements {
            if let oldElement = append(element) {
                removed.append(oldElement)
            }
        }

        return removed
    }

    /// Removes and returns the oldest element, or `nil` if the buffer is empty.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func popFirst() -> Element? {
        base.popFirst()
    }

    /// Removes and returns the newest element, or `nil` if the buffer is empty.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func popLast() -> Element? {
        base.popLast()
    }

    /// Removes all elements while preserving the fixed capacity.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func removeAll() {
        base.removeAll(keepingCapacity: true)
    }
}

extension RingBuffer: Sendable where Element: Sendable {}

extension RingBuffer: RandomAccessCollection {
    /// The position of the first element.
    ///
    /// For `RingBuffer`, this is always zero.
    @inlinable
    public var startIndex: Int {
        0
    }

    /// The position one past the last element.
    ///
    /// For `RingBuffer`, this is always equal to `count`.
    @inlinable
    public var endIndex: Int {
        base.count
    }

    /// Accesses the element at the given logical position.
    ///
    /// - Complexity: O(1).
    @inlinable
    public subscript(position: Int) -> Element {
        get {
            base[position]
        }
        set {
            base[position] = newValue
        }
    }
}

extension RingBuffer: MutableCollection {}

extension RingBuffer: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.capacity == rhs.capacity && lhs.base == rhs.base
    }
}

extension RingBuffer: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(capacity)
        hasher.combine(base)
    }
}

extension RingBuffer: CustomStringConvertible {
    /// A textual representation listing elements from oldest to newest.
    public var description: String {
        let ordered = elements.map { "\($0)" }
        return "[\(ordered.joined(separator: ", "))]"
    }
}

extension RingBuffer: CustomDebugStringConvertible {
    public var debugDescription: String {
        let ordered = elements.map { String(reflecting: $0) }
        return "RingBuffer(capacity: \(capacity), [\(ordered.joined(separator: ", "))])"
    }
}

extension RingBuffer: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements, capacity: elements.count)
    }
}
