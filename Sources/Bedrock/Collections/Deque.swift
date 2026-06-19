//
//  Deque.swift
//  Bedrock
//
//  Created by weixi on 2026/6/19.
//

/// A double-ended queue backed by a circular buffer.
///
/// `Deque` supports efficient insertion and removal at both ends. Logical
/// indices are always zero-based and ordered from front to back, while storage
/// may wrap around internally.
///
/// Like Swift's standard collections, `Deque` has value semantics. Its
/// array-backed storage uses Swift's copy-on-write behavior, so copies share
/// storage until one of them is mutated.
public struct Deque<Element> {
    @usableFromInline
    internal var storage: [Element?]

    @usableFromInline
    internal var head: Int

    @usableFromInline
    internal var elementCount: Int

    /// The number of elements in the deque.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var count: Int {
        elementCount
    }

    /// Creates an empty deque.
    @inlinable
    public init() {
        self.storage = []
        self.head = 0
        self.elementCount = 0
    }

    /// Creates an empty deque with storage for at least the requested number
    /// of elements.
    ///
    /// - Complexity: O(*n*) where *n* is `minimumCapacity`.
    @inlinable
    public init(minimumCapacity: Int) {
        precondition(minimumCapacity >= 0, "Capacity must not be negative")

        self.storage = Array(
            repeating: nil,
            count: Self.capacity(for: minimumCapacity)
        )
        self.head = 0
        self.elementCount = 0
    }

    /// Creates a deque from a sequence.
    ///
    /// The sequence's first element becomes the front of the deque and its last
    /// element becomes the back.
    ///
    /// - Complexity: O(*n*), where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        let values = Array(elements)
        let capacity = Self.capacity(for: values.count)

        self.storage = Array(repeating: nil, count: capacity)
        self.head = 0
        self.elementCount = values.count

        for (index, value) in values.enumerated() {
            storage[index] = value
        }
    }

    /// A Boolean value indicating whether the deque is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        count == 0
    }

    /// The element at the front of the deque, or `nil` if the deque is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var front: Element? {
        guard count > 0 else {
            return nil
        }

        return storage[head]!
    }

    /// The element at the back of the deque, or `nil` if the deque is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var back: Element? {
        guard count > 0 else {
            return nil
        }

        return storage[physicalIndex(forLogicalIndex: count - 1)]!
    }

    /// The elements in front-to-back order.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var elements: [Element] {
        var result: [Element] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            result.append(self[index])
        }

        return result
    }

    /// Reserves enough storage to hold the requested number of elements.
    ///
    /// - Complexity: O(*n*) if storage needs to grow; otherwise O(1).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        precondition(minimumCapacity >= 0, "Capacity must not be negative")

        guard minimumCapacity > storage.count else {
            return
        }

        moveStorage(toCapacity: Self.capacity(for: minimumCapacity))
    }

    /// Adds an element to the back of the deque.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    public mutating func append(_ element: Element) {
        ensureCapacity(count + 1)
        storage[physicalIndex(forLogicalIndex: count)] = element
        elementCount += 1
    }

    /// Adds the elements of a sequence to the back of the deque.
    ///
    /// - Complexity: O(*n*) on average, where *n* is the length of
    ///   `newElements`.
    @inlinable
    public mutating func append<S: Sequence>(
        contentsOf newElements: S
    ) where S.Element == Element {
        reserveCapacity(count + newElements.underestimatedCount)

        for element in newElements {
            append(element)
        }
    }

    /// Adds an element to the front of the deque.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    public mutating func prepend(_ element: Element) {
        ensureCapacity(count + 1)
        head = (head &- 1) & mask
        storage[head] = element
        elementCount += 1
    }

    /// Adds the elements of a sequence to the front of the deque, preserving
    /// their order.
    ///
    /// - Complexity: O(*n*) on average, where *n* is the length of
    ///   `newElements`.
    @inlinable
    public mutating func prepend<S: Sequence>(
        contentsOf newElements: S
    ) where S.Element == Element {
        let values = Array(newElements)
        reserveCapacity(count + values.count)

        for element in values.reversed() {
            prepend(element)
        }
    }

    /// Removes and returns the front element, or `nil` if the deque is empty.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func popFirst() -> Element? {
        guard count > 0 else {
            return nil
        }

        let index = head
        let element = storage[index]
        storage[index] = nil
        elementCount -= 1

        if count == 0 {
            head = 0
        } else {
            head = (head &+ 1) & mask
        }

        return element
    }

    /// Removes and returns the back element, or `nil` if the deque is empty.
    ///
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func popLast() -> Element? {
        guard count > 0 else {
            return nil
        }

        let index = physicalIndex(forLogicalIndex: count - 1)
        let element = storage[index]
        storage[index] = nil
        elementCount -= 1

        if count == 0 {
            head = 0
        }

        return element
    }

    /// Removes and returns the front element.
    ///
    /// - Precondition: The deque is not empty.
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func removeFirst() -> Element {
        guard let element = popFirst() else {
            preconditionFailure("Can't remove first element from an empty deque")
        }

        return element
    }

    /// Removes and returns the back element.
    ///
    /// - Precondition: The deque is not empty.
    /// - Complexity: O(1).
    @discardableResult
    @inlinable
    public mutating func removeLast() -> Element {
        guard let element = popLast() else {
            preconditionFailure("Can't remove last element from an empty deque")
        }

        return element
    }

    /// Removes all elements.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        guard keepCapacity else {
            storage.removeAll(keepingCapacity: false)
            head = 0
            elementCount = 0
            return
        }

        for index in 0..<count {
            storage[physicalIndex(forLogicalIndex: index)] = nil
        }

        head = 0
        elementCount = 0
    }

    @inlinable
    @inline(__always)
    internal var mask: Int {
        storage.count - 1
    }

    @inlinable
    @inline(__always)
    internal func physicalIndex(forLogicalIndex logicalIndex: Int) -> Int {
        (head &+ logicalIndex) & mask
    }

    @inlinable
    @inline(__always)
    internal mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard storage.count < minimumCapacity else {
            return
        }

        moveStorage(toCapacity: Self.capacity(for: minimumCapacity))
    }

    @inlinable
    internal mutating func moveStorage(toCapacity newCapacity: Int) {
        var newStorage = Array<Element?>(repeating: nil, count: newCapacity)

        for index in 0..<count {
            newStorage[index] = self[index]
        }

        storage = newStorage
        head = 0
    }

    @inlinable
    internal static func capacity(for minimumCapacity: Int) -> Int {
        guard minimumCapacity > 0 else {
            return 0
        }

        var capacity = 8
        while capacity < minimumCapacity {
            capacity *= 2
        }

        return capacity
    }
}

extension Deque: Sendable where Element: Sendable {}

extension Deque: RandomAccessCollection {
    /// The position of the first element.
    ///
    /// For `Deque`, this is always zero.
    @inlinable
    public var startIndex: Int {
        0
    }

    /// The position one past the last element.
    ///
    /// For `Deque`, this is always equal to `count`.
    @inlinable
    public var endIndex: Int {
        count
    }

    /// Accesses the element at the given logical position.
    ///
    /// - Complexity: O(1).
    @inlinable
    public subscript(position: Int) -> Element {
        get {
            precondition(position >= 0 && position < count, "Index out of range")
            return storage[physicalIndex(forLogicalIndex: position)]!
        }
        set {
            precondition(position >= 0 && position < count, "Index out of range")
            storage[physicalIndex(forLogicalIndex: position)] = newValue
        }
    }
}

extension Deque: MutableCollection {}

extension Deque: RangeReplaceableCollection {
    /// Replaces the elements in the specified range with the given elements.
    ///
    /// - Complexity: O(*n* + *m*), where *n* is the current count and *m* is
    ///   the length of `newElements`.
    public mutating func replaceSubrange<C: Collection>(
        _ subrange: Range<Int>,
        with newElements: C
    ) where C.Element == Element {
        precondition(
            subrange.lowerBound >= 0 && subrange.upperBound <= count,
            "Range out of bounds"
        )

        var values = elements
        values.replaceSubrange(subrange, with: newElements)
        self = Deque(values)
    }
}

extension Deque: Equatable where Element: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.count == rhs.count && lhs.elements == rhs.elements
    }
}

extension Deque: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements)
    }
}

extension Deque: CustomStringConvertible {
    /// A textual representation listing elements from front to back.
    public var description: String {
        let ordered = elements.map { "\($0)" }
        return "[\(ordered.joined(separator: ", "))]"
    }
}

extension Deque: CustomDebugStringConvertible {
    public var debugDescription: String {
        let ordered = elements.map { String(reflecting: $0) }
        return "Deque([\(ordered.joined(separator: ", "))])"
    }
}

extension Deque: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
