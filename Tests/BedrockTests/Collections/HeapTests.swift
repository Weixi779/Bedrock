//
//  HeapTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/7/10.
//

import Testing
@testable import Bedrock

@Suite("Heap")
struct HeapTests {
    @Test("Initializes as an empty min-heap")
    func initializesAsEmpty() {
        let heap = Heap<Int>()

        #expect(heap.isEmpty)
        #expect(heap.count == 0)
        #expect(heap.peek == nil)
    }

    @Test("Pop on an empty heap returns nil")
    func popOnEmptyHeapReturnsNil() {
        var heap = Heap<Int>()

        #expect(heap.pop() == nil)
        #expect(heap.isEmpty)
    }

    @Test("Bulk heapify removes values in min-priority order", arguments: [
        HeapOrderCase(elements: [3, 1, 2], expected: [1, 2, 3]),
        HeapOrderCase(elements: [4, 1, 4, 2], expected: [1, 2, 4, 4]),
    ])
    func bulkHeapifyRemovesValuesInMinPriorityOrder(_ testCase: HeapOrderCase) {
        var heap = Heap(testCase.elements)
        var output: [Int] = []

        while let element = heap.pop() {
            output.append(element)
        }

        #expect(output == testCase.expected)
        #expect(heap.isEmpty)
    }

    @Test("Insert updates the next highest-priority element")
    func insertUpdatesPeek() {
        var heap = Heap<Int>()

        heap.insert(5)
        heap.insert(2)
        heap.insert(3)
        heap.insert(1)

        #expect(heap.count == 4)
        #expect(heap.peek == 1)
        #expect(heap.pop() == 1)
        #expect(heap.pop() == 2)
        #expect(heap.peek == 3)
    }

    @Test("Peek does not remove the highest-priority element")
    func peekDoesNotRemoveElement() {
        var heap = Heap([3, 1, 2])

        #expect(heap.peek == 1)
        #expect(heap.count == 3)
        #expect(heap.pop() == 1)
    }

    @Test("Custom priority predicate creates a max-heap")
    func customPriorityPredicateCreatesMaxHeap() {
        var heap = Heap([3, 1, 2], isHigherPriority: >)

        #expect(heap.peek == 3)
        #expect(heap.pop() == 3)
        #expect(heap.pop() == 2)
        #expect(heap.pop() == 1)
    }

    @Test("Custom priority supports non-Comparable elements")
    func customPrioritySupportsNonComparableElements() throws {
        var heap = Heap([
            Job(id: "background", priority: 10),
            Job(id: "visible", priority: 50),
            Job(id: "user", priority: 100),
        ], isHigherPriority: { $0.priority > $1.priority })

        let firstValue = heap.pop()
        let secondValue = heap.pop()
        let thirdValue = heap.pop()
        let first = try #require(firstValue)
        let second = try #require(secondValue)
        let third = try #require(thirdValue)

        #expect(first.id == "user")
        #expect(second.id == "visible")
        #expect(third.id == "background")
    }

    @Test("Remove all clears the heap and allows later insertion")
    func removeAllClearsHeapAndAllowsLaterInsertion() {
        var heap = Heap([3, 1, 2])
        heap.reserveCapacity(32)

        heap.removeAll(keepingCapacity: true)

        #expect(heap.isEmpty)
        #expect(heap.count == 0)
        #expect(heap.peek == nil)

        heap.insert(4)
        #expect(heap.peek == 4)
    }
}

struct HeapOrderCase: Sendable, CustomTestStringConvertible {
    let elements: [Int]
    let expected: [Int]

    var testDescription: String {
        "HeapOrderCase(elements: \(elements), expected: \(expected))"
    }
}

private struct Job {
    let id: String
    let priority: Int
}
