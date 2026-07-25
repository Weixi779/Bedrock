//
//  Heap.swift
//  Bedrock
//
//  Created by weixi on 2026/7/10.
//

/// A data structure that efficiently removes its highest-priority element.
///
/// `Heap` stores a complete binary tree in an array. The priority predicate
/// decides which element belongs at the root: it must return `true` when its
/// first argument should be removed before its second argument. For example,
/// use `<` for a min-heap and `>` for a max-heap.
///
/// A heap does not keep every element globally sorted. Only `peek` is
/// guaranteed to be the next element to remove.
public struct Heap<Element> {
    @usableFromInline
    internal var storage: [Element]

    @usableFromInline
    internal let isHigherPriority: (Element, Element) -> Bool

    /// Creates an empty heap using the given priority predicate.
    ///
    /// `isHigherPriority` must define a strict weak ordering. It returns `true`
    /// when its first argument should be removed before its second argument.
    ///
    /// - Complexity: O(1).
    @inlinable
    public init(
        isHigherPriority: @escaping (Element, Element) -> Bool
    ) {
        self.storage = []
        self.isHigherPriority = isHigherPriority
    }

    /// Creates a heap from an unordered sequence using the given priority
    /// predicate.
    ///
    /// The sequence is materialized once, then arranged using bottom-up
    /// heapify instead of repeated insertion.
    ///
    /// - Complexity: O(*n*), where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(
        _ elements: S,
        isHigherPriority: @escaping (Element, Element) -> Bool
    ) where S.Element == Element {
        self.storage = Array(elements)
        self.isHigherPriority = isHigherPriority
        self.heapify()
    }

    /// The number of elements in the heap.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var count: Int {
        storage.count
    }

    /// A Boolean value indicating whether the heap is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var isEmpty: Bool {
        storage.isEmpty
    }

    /// The highest-priority element, or `nil` if the heap is empty.
    ///
    /// - Complexity: O(1).
    @inlinable
    public var peek: Element? {
        storage.first
    }

    /// Inserts an element into the heap.
    ///
    /// - Complexity: O(log *n*).
    @inlinable
    public mutating func insert(_ element: Element) {
        storage.append(element)
        siftUp(from: storage.endIndex - 1)
    }

    /// Removes and returns the highest-priority element, or `nil` if the heap
    /// is empty.
    ///
    /// - Complexity: O(log *n*).
    @discardableResult
    @inlinable
    public mutating func pop() -> Element? {
        guard let highestPriority = storage.first else {
            return nil
        }

        if storage.count == 1 {
            return storage.removeLast()
        }

        storage[0] = storage.removeLast()
        siftDown(from: 0)
        return highestPriority
    }

    /// Reserves enough storage to hold the requested number of elements.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        storage.reserveCapacity(minimumCapacity)
    }

    /// Removes all elements.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepCapacity)
    }

    @inlinable
    @inline(__always)
    internal mutating func heapify() {
        guard storage.count > 1 else {
            return
        }

        for index in stride(from: (storage.count - 2) / 2, through: 0, by: -1) {
            siftDown(from: index)
        }
    }

    @inlinable
    @inline(__always)
    internal mutating func siftUp(from startIndex: Int) {
        var child = startIndex

        while child > 0 {
            let parent = (child - 1) / 2
            guard isHigherPriority(storage[child], storage[parent]) else {
                return
            }

            storage.swapAt(child, parent)
            child = parent
        }
    }

    @inlinable
    @inline(__always)
    internal mutating func siftDown(from startIndex: Int) {
        var parent = startIndex

        while true {
            let leftChild = parent * 2 + 1
            guard leftChild < storage.count else {
                return
            }

            let rightChild = leftChild + 1
            let highestPriorityChild: Int
            if rightChild < storage.count,
               isHigherPriority(storage[rightChild], storage[leftChild]) {
                highestPriorityChild = rightChild
            } else {
                highestPriorityChild = leftChild
            }

            guard isHigherPriority(storage[highestPriorityChild], storage[parent]) else {
                return
            }

            storage.swapAt(parent, highestPriorityChild)
            parent = highestPriorityChild
        }
    }
}

extension Heap where Element: Comparable {
    /// Creates an empty min-heap.
    ///
    /// - Complexity: O(1).
    @inlinable
    public init() {
        self.init(isHigherPriority: <)
    }

    /// Creates a min-heap from an unordered sequence.
    ///
    /// - Complexity: O(*n*), where *n* is the length of `elements`.
    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.init(elements, isHigherPriority: <)
    }
}
