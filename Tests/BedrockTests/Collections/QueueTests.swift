//
//  QueueTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/6/18.
//

import Testing
@testable import Bedrock

@Suite("Queue")
struct QueueTests {
    @Test("Initializes as empty")
    func initializesAsEmpty() {
        let queue = Queue<String>()

        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.front == nil)
        #expect(queue.back == nil)
    }

    @Test("Initializes from sequence")
    func initializesFromSequence() {
        let queue = Queue([1, 2, 3])

        #expect(queue.count == 3)
        #expect(queue.front == 1)
        #expect(queue.back == 3)
    }

    @Test("Enqueue appends to the back")
    func enqueueAppendsToBack() {
        var queue = Queue<String>()

        queue.enqueue("a")
        queue.enqueue("b")

        #expect(queue.count == 2)
        #expect(queue.front == "a")
        #expect(queue.back == "b")
    }

    @Test("Dequeue removes from the front")
    func dequeueRemovesFromFront() {
        var queue = Queue(["a", "b", "c"])

        #expect(queue.dequeue() == "a")
        #expect(queue.dequeue() == "b")
        #expect(queue.front == "c")
        #expect(queue.back == "c")
        #expect(queue.count == 1)
    }

    @Test("Preserves order across interleaved enqueue and dequeue")
    func preservesOrderAcrossInterleavedOperations() {
        var queue = Queue(["a", "b"])

        #expect(queue.dequeue() == "a")

        queue.enqueue("c")
        queue.enqueue("d")

        #expect(queue.front == "b")
        #expect(queue.back == "d")
        #expect(queue.dequeue() == "b")
        #expect(queue.dequeue() == "c")
        #expect(queue.dequeue() == "d")
        #expect(queue.isEmpty)
    }

    @Test("Dequeue on empty queue returns nil")
    func dequeueOnEmptyQueueReturnsNil() {
        var queue = Queue<String>()

        #expect(queue.dequeue() == nil)
        #expect(queue.isEmpty)
    }

    @Test("Remove all clears storage")
    func removeAllClearsStorage() {
        var queue = Queue([1, 2, 3])

        queue.removeAll()

        #expect(queue.isEmpty)
        #expect(queue.front == nil)
        #expect(queue.back == nil)
    }

    @Test("Array literal builds front to back")
    func arrayLiteralBuildsFrontToBack() {
        let queue: Queue<Int> = [1, 2, 3]

        #expect(queue.front == 1)
        #expect(queue.back == 3)
    }

    @Test("Elements expose front-to-back order")
    func elementsExposeFrontToBackOrder() {
        var queue = Queue([1, 2, 3])
        queue.dequeue()
        queue.enqueue(4)

        #expect(queue.elements == [2, 3, 4])
    }

    @Test("Equatable ignores internal inbox and outbox split")
    func equatableIgnoresInternalSplit() {
        let direct = Queue([2, 3])

        var transferred = Queue([1, 2, 3])
        transferred.dequeue()

        #expect(direct == transferred)
        #expect(direct != Queue([3, 2]))
    }

    @Test("Description lists elements from front to back")
    func descriptionListsElementsFrontToBack() {
        #expect(Queue([1, 2, 3]).description == "[1, 2, 3]")
    }
}
