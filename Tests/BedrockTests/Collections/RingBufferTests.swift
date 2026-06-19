//
//  RingBufferTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/6/19.
//

import Testing
@testable import Bedrock

@Suite("RingBuffer")
struct RingBufferTests {
    @Test("Initializes as empty with fixed capacity")
    func initializesAsEmptyWithFixedCapacity() {
        let buffer = RingBuffer<String>(capacity: 3)

        #expect(buffer.capacity == 3)
        #expect(buffer.count == 0)
        #expect(buffer.isEmpty)
        #expect(!buffer.isFull)
        #expect(buffer.front == nil)
        #expect(buffer.back == nil)
        #expect(buffer.elements == [])
    }

    @Test("Initializes from sequence and keeps newest values")
    func initializesFromSequenceAndKeepsNewestValues() {
        let buffer = RingBuffer(1...5, capacity: 3)

        #expect(buffer.capacity == 3)
        #expect(buffer.count == 3)
        #expect(buffer.isFull)
        #expect(buffer.elements == [3, 4, 5])
        #expect(buffer.front == 3)
        #expect(buffer.back == 5)
    }

    @Test("Append stores values until full")
    func appendStoresValuesUntilFull() {
        var buffer = RingBuffer<Int>(capacity: 3)

        #expect(buffer.append(1) == nil)
        #expect(buffer.append(2) == nil)
        #expect(buffer.append(3) == nil)

        #expect(buffer.elements == [1, 2, 3])
        #expect(buffer.isFull)
    }

    @Test("Append overwrites oldest value when full")
    func appendOverwritesOldestValueWhenFull() {
        var buffer = RingBuffer([1, 2, 3], capacity: 3)

        #expect(buffer.append(4) == 1)
        #expect(buffer.append(5) == 2)

        #expect(buffer.elements == [3, 4, 5])
        #expect(buffer.front == 3)
        #expect(buffer.back == 5)
    }

    @Test("Append contents returns overwritten values")
    func appendContentsReturnsOverwrittenValues() {
        var buffer = RingBuffer([1, 2, 3], capacity: 3)

        let removed = buffer.append(contentsOf: [4, 5])

        #expect(removed == [1, 2])
        #expect(buffer.elements == [3, 4, 5])
    }

    @Test("Zero capacity discards appended values")
    func zeroCapacityDiscardsAppendedValues() {
        var buffer = RingBuffer<Int>(capacity: 0)

        #expect(buffer.isFull)
        #expect(buffer.append(1) == 1)
        #expect(buffer.append(contentsOf: [2, 3]) == [2, 3])
        #expect(buffer.isEmpty)
        #expect(buffer.elements == [])
    }

    @Test("Pop removes oldest and newest values")
    func popRemovesOldestAndNewestValues() {
        var buffer = RingBuffer([1, 2, 3, 4], capacity: 4)

        #expect(buffer.popFirst() == 1)
        #expect(buffer.popLast() == 4)
        #expect(buffer.popFirst() == 2)
        #expect(buffer.popLast() == 3)
        #expect(buffer.popFirst() == nil)
        #expect(buffer.popLast() == nil)
        #expect(buffer.isEmpty)
    }

    @Test("Preserves logical order after wrap around")
    func preservesLogicalOrderAfterWrapAround() {
        var buffer = RingBuffer([1, 2, 3, 4], capacity: 4)

        #expect(buffer.popFirst() == 1)
        #expect(buffer.popFirst() == 2)
        #expect(buffer.append(5) == nil)
        #expect(buffer.append(6) == nil)

        #expect(buffer.elements == [3, 4, 5, 6])
        #expect(buffer[0] == 3)
        #expect(buffer[3] == 6)
    }

    @Test("Mutable subscript updates logical positions")
    func mutableSubscriptUpdatesLogicalPositions() {
        var buffer = RingBuffer([1, 2, 3, 4], capacity: 4)

        buffer.popFirst()
        buffer.append(5)
        buffer[0] = 30
        buffer[buffer.count - 1] = 50

        #expect(buffer.elements == [30, 3, 4, 50])
    }

    @Test("Collection operations use logical order")
    func collectionOperationsUseLogicalOrder() {
        var buffer = RingBuffer([1, 2, 3, 4], capacity: 4)

        buffer.popFirst()
        buffer.append(5)

        #expect(Array(buffer) == [2, 3, 4, 5])
        #expect(buffer[buffer.index(after: buffer.startIndex)] == 3)
        #expect(buffer[buffer.index(before: buffer.endIndex)] == 5)
        #expect(buffer.index(buffer.startIndex, offsetBy: 2) == 2)
    }

    @Test("Remove all clears elements but preserves capacity")
    func removeAllClearsElementsButPreservesCapacity() {
        var buffer = RingBuffer([1, 2, 3], capacity: 3)

        buffer.removeAll()
        buffer.append(4)

        #expect(buffer.capacity == 3)
        #expect(buffer.elements == [4])
    }

    @Test("Array literal creates exact capacity buffer")
    func arrayLiteralCreatesExactCapacityBuffer() {
        let buffer: RingBuffer<Int> = [1, 2, 3]

        #expect(buffer.capacity == 3)
        #expect(buffer.elements == [1, 2, 3])
        #expect(buffer.isFull)
    }

    @Test("Equatable includes capacity and logical order")
    func equatableIncludesCapacityAndLogicalOrder() {
        #expect(RingBuffer([1, 2, 3], capacity: 3) == RingBuffer([1, 2, 3], capacity: 3))
        #expect(RingBuffer([1, 2, 3], capacity: 3) != RingBuffer([1, 2, 3], capacity: 4))
        #expect(RingBuffer([1, 2, 3], capacity: 3) != RingBuffer([3, 2, 1], capacity: 3))
    }

    @Test("Hashable includes capacity and logical order")
    func hashableIncludesCapacityAndLogicalOrder() {
        let buffer = RingBuffer([1, 2, 3], capacity: 3)
        let larger = RingBuffer([1, 2, 3], capacity: 4)

        #expect(Set([buffer]).contains(RingBuffer([1, 2, 3], capacity: 3)))
        #expect(!Set([buffer]).contains(larger))
    }

    @Test("Description lists values in logical order")
    func descriptionListsValuesInLogicalOrder() {
        let buffer = RingBuffer(["a", "b"], capacity: 3)

        #expect(buffer.description == "[a, b]")
        #expect(buffer.debugDescription == #"RingBuffer(capacity: 3, ["a", "b"])"#)
    }
}
