//
//  main.swift
//  DequeBenchmark
//
//  Created by weixi on 2026/6/19.
//

import Bedrock
import Foundation

@main
struct DequeBenchmark {
    static func main() {
        let size = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 100_000
        let windowSize = max(16, min(size, 4_096))
        let lookupKeys = makePermutation(count: size, seed: 0xDEC0_0001)
        let lookupRounds = max(1, 1_000_000 / max(size, 1))

        print("Deque storage benchmark")
        print("size: \(size)")
        print("window: \(windowSize)")
        print("random access rounds: \(lookupRounds)")
        print("")

        benchmarkAppendBackPopFront(size: size)
        benchmarkAppendFrontPopBack(size: size)
        benchmarkAlternatingPopsAfterAppendBack(size: min(size, 20_000))
        benchmarkMixedEnds(size: size)
        benchmarkSlidingWindow(size: size, windowSize: windowSize)
        benchmarkRandomAccess(size: size, indices: lookupKeys, rounds: lookupRounds)
    }

    private static func benchmarkAppendBackPopFront(size: Int) {
        print("Append back, pop front")
        measure("public Deque") {
            var deque = Deque<Int>()
            for value in 0..<size {
                deque.append(value)
            }

            var checksum = 0
            while let value = deque.popFirst() {
                checksum &+= value
            }
            return checksum
        }
        measure("ring buffer") {
            var deque = RingBufferDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            while let value = deque.popFront() {
                checksum &+= value
            }
            return checksum
        }
        measure("centered array") {
            var deque = CenteredArrayDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            while let value = deque.popFront() {
                checksum &+= value
            }
            return checksum
        }
        measure("two arrays, full move") {
            var deque = FullMoveDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            while let value = deque.popFront() {
                checksum &+= value
            }
            return checksum
        }
        measure("two arrays, half rebalance") {
            var deque = HalfRebalanceDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            while let value = deque.popFront() {
                checksum &+= value
            }
            return checksum
        }
        measure("existing Queue") {
            var queue = Queue<Int>()
            for value in 0..<size {
                queue.enqueue(value)
            }

            var checksum = 0
            while let value = queue.dequeue() {
                checksum &+= value
            }
            return checksum
        }
        measure("Array.removeFirst") {
            var array = Array(0..<size)
            var checksum = 0
            while !array.isEmpty {
                checksum &+= array.removeFirst()
            }
            return checksum
        }
        print("")
    }

    private static func benchmarkAppendFrontPopBack(size: Int) {
        print("Append front, pop back")
        measure("public Deque") {
            var deque = Deque<Int>()
            for value in 0..<size {
                deque.prepend(value)
            }

            var checksum = 0
            while let value = deque.popLast() {
                checksum &+= value
            }
            return checksum
        }
        measure("ring buffer") {
            var deque = RingBufferDeque<Int>()
            for value in 0..<size {
                deque.appendFront(value)
            }

            var checksum = 0
            while let value = deque.popBack() {
                checksum &+= value
            }
            return checksum
        }
        measure("centered array") {
            var deque = CenteredArrayDeque<Int>()
            for value in 0..<size {
                deque.appendFront(value)
            }

            var checksum = 0
            while let value = deque.popBack() {
                checksum &+= value
            }
            return checksum
        }
        measure("two arrays, full move") {
            var deque = FullMoveDeque<Int>()
            for value in 0..<size {
                deque.appendFront(value)
            }

            var checksum = 0
            while let value = deque.popBack() {
                checksum &+= value
            }
            return checksum
        }
        measure("two arrays, half rebalance") {
            var deque = HalfRebalanceDeque<Int>()
            for value in 0..<size {
                deque.appendFront(value)
            }

            var checksum = 0
            while let value = deque.popBack() {
                checksum &+= value
            }
            return checksum
        }
        measure("Array.insert at start") {
            var array: [Int] = []
            for value in 0..<size {
                array.insert(value, at: 0)
            }

            var checksum = 0
            while let value = array.popLast() {
                checksum &+= value
            }
            return checksum
        }
        print("")
    }

    private static func benchmarkAlternatingPopsAfterAppendBack(size: Int) {
        print("Append back, then alternate pop front/back")
        measure("public Deque") {
            var deque = Deque<Int>()
            for value in 0..<size {
                deque.append(value)
            }

            var checksum = 0
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFirst() ?? 0
                } else {
                    checksum &+= deque.popLast() ?? 0
                }
            }
            return checksum
        }
        measure("ring buffer") {
            var deque = RingBufferDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        measure("centered array") {
            var deque = CenteredArrayDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        measure("two arrays, full move") {
            var deque = FullMoveDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        measure("two arrays, half rebalance") {
            var deque = HalfRebalanceDeque<Int>()
            for value in 0..<size {
                deque.appendBack(value)
            }

            var checksum = 0
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        print("")
    }

    private static func benchmarkMixedEnds(size: Int) {
        print("Mixed append/pop at both ends")
        measure("public Deque") {
            var deque = Deque<Int>()
            var checksum = 0
            for value in 0..<size {
                if value.isMultiple(of: 2) {
                    deque.append(value)
                } else {
                    deque.prepend(value)
                }
            }
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFirst() ?? 0
                } else {
                    checksum &+= deque.popLast() ?? 0
                }
            }
            return checksum
        }
        measure("ring buffer") {
            var deque = RingBufferDeque<Int>()
            var checksum = 0
            for value in 0..<size {
                if value.isMultiple(of: 2) {
                    deque.appendBack(value)
                } else {
                    deque.appendFront(value)
                }
            }
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        measure("centered array") {
            var deque = CenteredArrayDeque<Int>()
            var checksum = 0
            for value in 0..<size {
                if value.isMultiple(of: 2) {
                    deque.appendBack(value)
                } else {
                    deque.appendFront(value)
                }
            }
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        measure("two arrays, full move") {
            var deque = FullMoveDeque<Int>()
            var checksum = 0
            for value in 0..<size {
                if value.isMultiple(of: 2) {
                    deque.appendBack(value)
                } else {
                    deque.appendFront(value)
                }
            }
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        measure("two arrays, half rebalance") {
            var deque = HalfRebalanceDeque<Int>()
            var checksum = 0
            for value in 0..<size {
                if value.isMultiple(of: 2) {
                    deque.appendBack(value)
                } else {
                    deque.appendFront(value)
                }
            }
            for index in 0..<size {
                if index.isMultiple(of: 2) {
                    checksum &+= deque.popFront() ?? 0
                } else {
                    checksum &+= deque.popBack() ?? 0
                }
            }
            return checksum
        }
        print("")
    }

    private static func benchmarkSlidingWindow(size: Int, windowSize: Int) {
        print("Sliding window append back, pop front")
        measure("public Deque") {
            var deque = Deque<Int>()
            for value in 0..<windowSize {
                deque.append(value)
            }

            var checksum = 0
            for value in windowSize..<(windowSize + size) {
                deque.append(value)
                checksum &+= deque.popFirst() ?? 0
            }
            return checksum &+ deque.count
        }
        measure("ring buffer") {
            var deque = RingBufferDeque<Int>()
            for value in 0..<windowSize {
                deque.appendBack(value)
            }

            var checksum = 0
            for value in windowSize..<(windowSize + size) {
                deque.appendBack(value)
                checksum &+= deque.popFront() ?? 0
            }
            return checksum &+ deque.count
        }
        measure("centered array") {
            var deque = CenteredArrayDeque<Int>()
            for value in 0..<windowSize {
                deque.appendBack(value)
            }

            var checksum = 0
            for value in windowSize..<(windowSize + size) {
                deque.appendBack(value)
                checksum &+= deque.popFront() ?? 0
            }
            return checksum &+ deque.count
        }
        measure("two arrays, full move") {
            var deque = FullMoveDeque<Int>()
            for value in 0..<windowSize {
                deque.appendBack(value)
            }

            var checksum = 0
            for value in windowSize..<(windowSize + size) {
                deque.appendBack(value)
                checksum &+= deque.popFront() ?? 0
            }
            return checksum &+ deque.count
        }
        measure("two arrays, half rebalance") {
            var deque = HalfRebalanceDeque<Int>()
            for value in 0..<windowSize {
                deque.appendBack(value)
            }

            var checksum = 0
            for value in windowSize..<(windowSize + size) {
                deque.appendBack(value)
                checksum &+= deque.popFront() ?? 0
            }
            return checksum &+ deque.count
        }
        measure("existing Queue") {
            var queue = Queue<Int>()
            for value in 0..<windowSize {
                queue.enqueue(value)
            }

            var checksum = 0
            for value in windowSize..<(windowSize + size) {
                queue.enqueue(value)
                checksum &+= queue.dequeue() ?? 0
            }
            return checksum &+ queue.count
        }
        print("")
    }

    private static func benchmarkRandomAccess(size: Int, indices: [Int], rounds: Int) {
        print("Random access by shuffled index")
        let publicDeque = Deque(0..<size)
        let ring = RingBufferDeque(0..<size)
        let centered = CenteredArrayDeque(0..<size)
        let fullMove = FullMoveDeque(0..<size)
        let halfRebalance = HalfRebalanceDeque(0..<size)
        let array = Array(0..<size)

        measure("public Deque") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= publicDeque[index]
                }
            }
            return checksum
        }
        measure("ring buffer") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= ring[index]
                }
            }
            return checksum
        }
        measure("centered array") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= centered[index]
                }
            }
            return checksum
        }
        measure("two arrays, full move") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= fullMove[index]
                }
            }
            return checksum
        }
        measure("two arrays, half rebalance") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= halfRebalance[index]
                }
            }
            return checksum
        }
        measure("Array") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= array[index]
                }
            }
            return checksum
        }
        print("")
    }

    private static func measure(_ label: String, iterations: Int = 3, _ body: () -> Int) {
        var best = UInt64.max
        var checksum = 0

        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= body()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            best = min(best, elapsed)
        }

        print("  \(label): \(milliseconds(best)) best of \(iterations) (checksum: \(checksum))")
    }

    private static func milliseconds(_ nanoseconds: UInt64) -> String {
        let whole = nanoseconds / 1_000_000
        let fraction = (nanoseconds % 1_000_000) / 1_000
        let fractionText = String(fraction)
        let padding = String(repeating: "0", count: max(0, 3 - fractionText.count))

        return "\(whole).\(padding)\(fractionText) ms"
    }

    private static func makePermutation(count: Int, seed: UInt64) -> [Int] {
        guard count > 0 else {
            return []
        }

        var generator = SeededGenerator(seed: seed)
        var values = Array(0..<count)
        values.shuffle(using: &generator)
        return values
    }
}

private struct RingBufferDeque<Element> {
    private var storage: [Element?]
    private var head: Int
    private(set) var count: Int

    init() {
        self.storage = []
        self.head = 0
        self.count = 0
    }

    init<S: Sequence>(_ elements: S) where S.Element == Element {
        let values = Array(elements)
        let capacity = Self.capacity(for: values.count)
        self.storage = Array(repeating: nil, count: capacity)
        self.head = 0
        self.count = values.count

        for (index, value) in values.enumerated() {
            storage[index] = value
        }
    }

    subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of range")
        return storage[(head &+ position) & mask]!
    }

    mutating func appendFront(_ element: Element) {
        ensureAppendCapacity()
        head = (head &- 1) & mask
        storage[head] = element
        count += 1
    }

    mutating func appendBack(_ element: Element) {
        ensureAppendCapacity()
        storage[(head &+ count) & mask] = element
        count += 1
    }

    mutating func popFront() -> Element? {
        guard count > 0 else {
            return nil
        }

        let index = head
        let element = storage[index]
        storage[index] = nil
        head = (head &+ 1) & mask
        count -= 1

        if count == 0 {
            head = 0
        }

        return element
    }

    mutating func popBack() -> Element? {
        guard count > 0 else {
            return nil
        }

        let index = (head &+ count &- 1) & mask
        let element = storage[index]
        storage[index] = nil
        count -= 1

        if count == 0 {
            head = 0
        }

        return element
    }

    private var mask: Int {
        storage.count - 1
    }

    private mutating func ensureAppendCapacity() {
        if storage.isEmpty {
            storage = Array(repeating: nil, count: 8)
            return
        }

        if count == storage.count {
            moveStorage(toCapacity: storage.count * 2)
        }
    }

    private mutating func moveStorage(toCapacity newCapacity: Int) {
        var newStorage = Array<Element?>(repeating: nil, count: newCapacity)
        for index in 0..<count {
            newStorage[index] = self[index]
        }

        storage = newStorage
        head = 0
    }

    private static func capacity(for count: Int) -> Int {
        var capacity = 8
        while capacity < count {
            capacity *= 2
        }
        return capacity
    }
}

private struct CenteredArrayDeque<Element> {
    private var storage: [Element?]
    private var start: Int
    private(set) var count: Int

    init() {
        self.storage = []
        self.start = 0
        self.count = 0
    }

    init<S: Sequence>(_ elements: S) where S.Element == Element {
        let values = Array(elements)
        let capacity = max(8, values.count * 2)
        self.storage = Array(repeating: nil, count: capacity)
        self.start = max(0, (capacity - values.count) / 2)
        self.count = values.count

        for (index, value) in values.enumerated() {
            storage[start + index] = value
        }
    }

    subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of range")
        return storage[start + position]!
    }

    mutating func appendFront(_ element: Element) {
        ensureSpaceAtFront()
        start -= 1
        storage[start] = element
        count += 1
    }

    mutating func appendBack(_ element: Element) {
        ensureSpaceAtBack()
        storage[start + count] = element
        count += 1
    }

    mutating func popFront() -> Element? {
        guard count > 0 else {
            return nil
        }

        let element = storage[start]
        storage[start] = nil
        start += 1
        count -= 1

        if count == 0 {
            start = storage.count / 2
        }

        return element
    }

    mutating func popBack() -> Element? {
        guard count > 0 else {
            return nil
        }

        let index = start + count - 1
        let element = storage[index]
        storage[index] = nil
        count -= 1

        if count == 0 {
            start = storage.count / 2
        }

        return element
    }

    private mutating func ensureSpaceAtFront() {
        if storage.isEmpty {
            storage = Array(repeating: nil, count: 8)
            start = storage.count / 2
            return
        }

        if start == 0 {
            recenterOrGrow()
        }
    }

    private mutating func ensureSpaceAtBack() {
        if storage.isEmpty {
            storage = Array(repeating: nil, count: 8)
            start = storage.count / 2
            return
        }

        if start + count == storage.count {
            recenterOrGrow()
        }
    }

    private mutating func recenterOrGrow() {
        let newCapacity = count * 2 >= storage.count ? storage.count * 2 : storage.count
        var newStorage = Array<Element?>(repeating: nil, count: max(8, newCapacity))
        let newStart = (newStorage.count - count) / 2

        for index in 0..<count {
            newStorage[newStart + index] = storage[start + index]
        }

        storage = newStorage
        start = newStart
    }
}

private struct FullMoveDeque<Element> {
    private var front: [Element]
    private var back: [Element]

    init() {
        self.front = []
        self.back = []
    }

    init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.front = []
        self.back = Array(elements)
    }

    var count: Int {
        front.count + back.count
    }

    subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of range")
        if position < front.count {
            return front[front.count - 1 - position]
        }

        return back[position - front.count]
    }

    mutating func appendFront(_ element: Element) {
        front.append(element)
    }

    mutating func appendBack(_ element: Element) {
        back.append(element)
    }

    mutating func popFront() -> Element? {
        if front.isEmpty {
            front = back.reversed()
            back.removeAll(keepingCapacity: true)
        }

        return front.popLast()
    }

    mutating func popBack() -> Element? {
        if back.isEmpty {
            back = front.reversed()
            front.removeAll(keepingCapacity: true)
        }

        return back.popLast()
    }
}

private struct HalfRebalanceDeque<Element> {
    private var front: [Element]
    private var back: [Element]

    init() {
        self.front = []
        self.back = []
    }

    init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.front = []
        self.back = Array(elements)
    }

    var count: Int {
        front.count + back.count
    }

    subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of range")
        if position < front.count {
            return front[front.count - 1 - position]
        }

        return back[position - front.count]
    }

    mutating func appendFront(_ element: Element) {
        front.append(element)
    }

    mutating func appendBack(_ element: Element) {
        back.append(element)
    }

    mutating func popFront() -> Element? {
        if front.isEmpty {
            rebalanceFromBack()
        }

        return front.popLast()
    }

    mutating func popBack() -> Element? {
        if back.isEmpty {
            rebalanceFromFront()
        }

        return back.popLast()
    }

    private mutating func rebalanceFromBack() {
        guard !back.isEmpty else {
            return
        }

        let moveCount = max(1, back.count / 2)
        front = Array(back.prefix(moveCount).reversed())
        back.removeFirst(moveCount)
    }

    private mutating func rebalanceFromFront() {
        guard !front.isEmpty else {
            return
        }

        let moveCount = max(1, front.count / 2)
        back = Array(front.prefix(moveCount).reversed())
        front.removeFirst(moveCount)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var result = state
        result = (result ^ (result >> 30)) &* 0xBF58_476D_1CE4_E5B9
        result = (result ^ (result >> 27)) &* 0x94D0_49BB_1331_11EB
        return result ^ (result >> 31)
    }
}
