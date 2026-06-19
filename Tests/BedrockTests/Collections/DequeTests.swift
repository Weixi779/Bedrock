//
//  DequeTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/6/19.
//

import Testing
@testable import Bedrock

@Suite("Deque")
struct DequeTests {
    @Test("Initializes as empty")
    func initializesAsEmpty() {
        let deque = Deque<String>()

        #expect(deque.isEmpty)
        #expect(deque.count == 0)
        #expect(deque.front == nil)
        #expect(deque.back == nil)
        #expect(deque.startIndex == 0)
        #expect(deque.endIndex == 0)
    }

    @Test("Initializes from sequence")
    func initializesFromSequence() {
        let deque = Deque([1, 2, 3])

        #expect(deque.count == 3)
        #expect(deque.front == 1)
        #expect(deque.back == 3)
        #expect(deque.elements == [1, 2, 3])
    }

    @Test("Append and prepend add elements at opposite ends")
    func appendAndPrependAddElementsAtOppositeEnds() {
        var deque = Deque<String>()

        deque.append("b")
        deque.append("c")
        deque.prepend("a")

        #expect(deque.elements == ["a", "b", "c"])
        #expect(deque.front == "a")
        #expect(deque.back == "c")
    }

    @Test("Pop removes from both ends")
    func popRemovesFromBothEnds() {
        var deque = Deque(["a", "b", "c", "d"])

        #expect(deque.popFirst() == "a")
        #expect(deque.popLast() == "d")
        #expect(deque.popFirst() == "b")
        #expect(deque.popLast() == "c")
        #expect(deque.popFirst() == nil)
        #expect(deque.popLast() == nil)
        #expect(deque.isEmpty)
    }

    @Test("Remove first and last return elements")
    func removeFirstAndLastReturnElements() {
        var deque = Deque([1, 2, 3])

        #expect(deque.removeFirst() == 1)
        #expect(deque.removeLast() == 3)
        #expect(deque.elements == [2])
    }

    @Test("Preserves order after storage wraps")
    func preservesOrderAfterStorageWraps() {
        var deque = Deque(0..<8)

        #expect(deque.popFirst() == 0)
        #expect(deque.popFirst() == 1)
        #expect(deque.popFirst() == 2)

        deque.append(8)
        deque.append(9)
        deque.append(10)

        #expect(deque.elements == [3, 4, 5, 6, 7, 8, 9, 10])
        #expect(deque[0] == 3)
        #expect(deque[7] == 10)
    }

    @Test("Grows after wrapped storage fills")
    func growsAfterWrappedStorageFills() {
        var deque = Deque(0..<8)

        for _ in 0..<3 {
            deque.popFirst()
        }

        deque.append(8)
        deque.append(9)
        deque.append(10)
        deque.append(11)

        #expect(deque.elements == [3, 4, 5, 6, 7, 8, 9, 10, 11])
        #expect(deque.front == 3)
        #expect(deque.back == 11)
    }

    @Test("Mutable subscript updates logical positions")
    func mutableSubscriptUpdatesLogicalPositions() {
        var deque = Deque(0..<8)

        for _ in 0..<3 {
            deque.popFirst()
        }
        deque.append(8)
        deque.append(9)

        deque[0] = 30
        deque[deque.count - 1] = 90

        #expect(deque.elements == [30, 4, 5, 6, 7, 8, 90])
    }

    @Test("Collection operations use logical order")
    func collectionOperationsUseLogicalOrder() {
        var deque = Deque(0..<8)
        deque.popFirst()
        deque.append(8)

        #expect(Array(deque) == [1, 2, 3, 4, 5, 6, 7, 8])
        #expect(deque[deque.index(after: deque.startIndex)] == 2)
        #expect(deque[deque.index(before: deque.endIndex)] == 8)
        #expect(deque.index(deque.startIndex, offsetBy: 3) == 3)
    }

    @Test("Append and prepend contents preserve order")
    func appendAndPrependContentsPreserveOrder() {
        var deque = Deque([3, 4])

        deque.prepend(contentsOf: [1, 2])
        deque.append(contentsOf: [5, 6])

        #expect(deque.elements == [1, 2, 3, 4, 5, 6])
    }

    @Test("Replace subrange supports range replaceable collection")
    func replaceSubrangeSupportsRangeReplaceableCollection() {
        var deque = Deque([1, 2, 3, 4])

        deque.replaceSubrange(1..<3, with: [20, 30, 40])

        #expect(deque.elements == [1, 20, 30, 40, 4])
    }

    @Test("Insert and remove subrange use range replaceable collection")
    func insertAndRemoveSubrangeUseRangeReplaceableCollection() {
        var deque = Deque([2, 3, 4])

        deque.insert(1, at: 0)
        deque.insert(5, at: deque.endIndex)
        deque.removeSubrange(1..<3)

        #expect(deque.elements == [1, 4, 5])
    }

    @Test("Remove all clears storage")
    func removeAllClearsStorage() {
        var deque = Deque([1, 2, 3])

        deque.removeAll()

        #expect(deque.isEmpty)
        #expect(deque.front == nil)
        #expect(deque.back == nil)
        #expect(deque.elements == [])
    }

    @Test("Remove all can keep capacity for reuse")
    func removeAllCanKeepCapacityForReuse() {
        var deque = Deque(0..<8)

        deque.removeAll(keepingCapacity: true)
        deque.prepend(2)
        deque.append(3)
        deque.prepend(1)

        #expect(deque.elements == [1, 2, 3])
    }

    @Test("Array literal builds front to back")
    func arrayLiteralBuildsFrontToBack() {
        let deque: Deque<Int> = [1, 2, 3]

        #expect(deque.elements == [1, 2, 3])
        #expect(deque.front == 1)
        #expect(deque.back == 3)
    }

    @Test("Equatable ignores physical layout")
    func equatableIgnoresPhysicalLayout() {
        let direct = Deque([3, 4, 5, 6, 7, 8, 9, 10])

        var wrapped = Deque(0..<8)
        wrapped.popFirst()
        wrapped.popFirst()
        wrapped.popFirst()
        wrapped.append(8)
        wrapped.append(9)
        wrapped.append(10)

        #expect(direct == wrapped)
        #expect(direct != Deque([10, 9, 8, 7, 6, 5, 4, 3]))
    }

    @Test("Hashable follows logical order")
    func hashableFollowsLogicalOrder() {
        let direct = Deque([3, 4, 5, 6, 7, 8, 9, 10])

        var wrapped = Deque(0..<8)
        wrapped.popFirst()
        wrapped.popFirst()
        wrapped.popFirst()
        wrapped.append(8)
        wrapped.append(9)
        wrapped.append(10)

        #expect(Set([direct]).contains(wrapped))
    }

    @Test("Description lists elements from front to back")
    func descriptionListsElementsFrontToBack() {
        #expect(Deque([1, 2, 3]).description == "[1, 2, 3]")
        #expect(Deque(["a", "b"]).debugDescription == #"Deque(["a", "b"])"#)
    }
}
