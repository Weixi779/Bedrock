//
//  Queue.swift
//  Bedrock
//
//  Created by weixi on 2026/6/18.
//

/// A first-in, first-out (FIFO) collection.
///
/// `Queue` uses the two-stack technique: elements are appended to an `inbox`
/// and transferred in bulk to an `outbox` when the front is needed. This gives
/// O(1) `enqueue` and amortized O(1) `dequeue`, though an individual `dequeue`
/// that triggers a transfer is O(*n*).
///
/// The split between `inbox` and `outbox` is an internal detail: equality,
/// hashing, and `description` all reflect the logical front-to-back order, so
/// two queues holding the same elements in the same order compare equal
/// regardless of how those elements are distributed internally.
public struct Queue<Element> {
    @usableFromInline
    internal var inbox: [Element]

    @usableFromInline
    internal var outbox: [Element]

    /// Creates an empty queue.
    @inlinable
    public init() {
        self.inbox = []
        self.outbox = []
    }

    /// Creates a queue from a sequence.
    ///
    /// The sequence's first element becomes the front of the queue and its last
    /// element becomes the back.
    ///
    /// - Complexity: O(*n*), where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.inbox = Array(elements)
        self.outbox = []
    }

    /// The number of elements in the queue.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var count: Int {
        inbox.count + outbox.count
    }

    /// A Boolean value indicating whether the queue is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        inbox.isEmpty && outbox.isEmpty
    }

    /// The element at the front of the queue, or `nil` if the queue is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var front: Element? {
        outbox.last ?? inbox.first
    }

    /// The element at the back of the queue, or `nil` if the queue is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var back: Element? {
        inbox.last ?? outbox.first
    }

    /// The elements of the queue in front-to-back order.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var elements: [Element] {
        var ordered = outbox
        ordered.reverse()
        ordered.append(contentsOf: inbox)
        return ordered
    }

    /// Adds an element to the back of the queue.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    public mutating func enqueue(_ element: Element) {
        inbox.append(element)
    }

    /// Removes and returns the front element, or `nil` if the queue is empty.
    ///
    /// - Complexity: Amortized O(1). A call that transfers the `inbox` to the
    ///   `outbox` is O(*n*).
    @discardableResult
    @inlinable
    public mutating func dequeue() -> Element? {
        if outbox.isEmpty {
            refillOutbox()
        }

        return outbox.popLast()
    }

    /// Reserves enough storage to hold the requested number of elements.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        inbox.reserveCapacity(minimumCapacity)
    }

    /// Removes all elements.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        inbox.removeAll(keepingCapacity: keepCapacity)
        outbox.removeAll(keepingCapacity: keepCapacity)
    }

    @usableFromInline
    internal mutating func refillOutbox() {
        outbox = inbox.reversed()
        inbox.removeAll(keepingCapacity: true)
    }
}

extension Queue: Sendable where Element: Sendable {}

extension Queue: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.count == rhs.count && lhs.elements == rhs.elements
    }
}

extension Queue: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements)
    }
}

extension Queue: CustomStringConvertible {
    /// A textual representation listing elements from front to back.
    public var description: String {
        let ordered = elements.map { "\($0)" }
        return "[\(ordered.joined(separator: ", "))]"
    }
}

extension Queue: CustomDebugStringConvertible {
    public var debugDescription: String {
        let ordered = elements.map { String(reflecting: $0) }
        return "Queue([\(ordered.joined(separator: ", "))])"
    }
}

extension Queue: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
