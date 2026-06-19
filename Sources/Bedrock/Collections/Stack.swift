//
//  Stack.swift
//  Bedrock
//
//  Created by weixi on 2026/6/18.
//

/// A last-in, first-out (LIFO) collection.
///
/// `Stack` is backed by an array whose end is the top, so `push` and `pop`
/// operate on the most recently added element in amortized O(1) time.
///
/// Equality and hashing are order-sensitive: two stacks are equal only if they
/// contain the same elements in the same bottom-to-top order.
public struct Stack<Element> {
    private var storage: [Element]

    /// Creates an empty stack.
    public init() {
        self.storage = []
    }

    /// Creates a stack from a sequence.
    ///
    /// The sequence's first element becomes the bottom of the stack and its
    /// last element becomes the top.
    ///
    /// - Complexity: O(*n*), where *n* is the length of `elements`.
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.storage = Array(elements)
    }

    /// The number of elements in the stack.
    ///
    /// - Complexity: O(1).
    public var count: Int {
        storage.count
    }

    /// A Boolean value indicating whether the stack is empty.
    ///
    /// - Complexity: O(1).
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// The element at the top of the stack, or `nil` if the stack is empty.
    ///
    /// - Complexity: O(1).
    public var top: Element? {
        storage.last
    }

    /// Pushes an element onto the top of the stack.
    ///
    /// - Complexity: O(1) on average.
    public mutating func push(_ element: Element) {
        storage.append(element)
    }

    /// Removes and returns the top element, or `nil` if the stack is empty.
    ///
    /// - Complexity: O(1).
    @discardableResult
    public mutating func pop() -> Element? {
        storage.popLast()
    }

    /// Reserves enough storage to hold the requested number of elements.
    ///
    /// - Complexity: O(*n*).
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        storage.reserveCapacity(minimumCapacity)
    }

    /// Removes all elements.
    ///
    /// - Complexity: O(*n*).
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepCapacity)
    }
}

extension Stack: Sendable where Element: Sendable {}

extension Stack: Equatable where Element: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage == rhs.storage
    }
}

extension Stack: Hashable where Element: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }
}

extension Stack: CustomStringConvertible {
    /// A textual representation listing elements from bottom to top.
    public var description: String {
        let elements = storage.map { "\($0)" }
        return "[\(elements.joined(separator: ", "))]"
    }
}

extension Stack: CustomDebugStringConvertible {
    public var debugDescription: String {
        let elements = storage.map { String(reflecting: $0) }
        return "Stack([\(elements.joined(separator: ", "))])"
    }
}

extension Stack: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
