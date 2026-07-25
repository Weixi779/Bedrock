//
//  main.swift
//  HeapBenchmark
//
//  Created by weixi on 2026/7/10.
//

import Bedrock
import Foundation

@main
struct HeapBenchmark {
    static func main() {
        let size = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 10_000
        precondition(size >= 0, "Size must not be negative")

        let values = makeValues(count: size, seed: 0x0EA9_0001)
        let windowSize = min(max(size, 1), 1_024)
        let windowValues = makeValues(count: windowSize, seed: 0x0EA9_0002)
        let topK = max(1, min(size, 128))

        verifyCandidates()

        print("Priority queue design benchmark")
        print("size: \(size)")
        print("scheduler window: \(windowSize)")
        print("top K: \(topK)")
        print("")

        benchmarkIndividualInsertions(values: values)
        benchmarkBulkConstruction(values: values)
        benchmarkDraining(values: values)
        benchmarkSteadyStateScheduling(values: values, initialValues: windowValues)
        benchmarkTopK(values: values, limit: topK)
    }

    private static func benchmarkIndividualInsertions(values: [Int]) {
        print("Build by individual insertions")
        runIndividualInsertions("public Heap", as: PublicHeapMinQueue.self, values: values)
        runIndividualInsertions("4-ary heap", as: FourAryMinHeap.self, values: values)
        runIndividualInsertions("sorted array", as: SortedArrayMinQueue.self, values: values)
        runIndividualInsertions("unsorted array", as: UnsortedArrayMinQueue.self, values: values)
        print("")
    }

    private static func benchmarkBulkConstruction(values: [Int]) {
        print("Build from an unordered sequence")
        runBulkConstruction("public Heap", as: PublicHeapMinQueue.self, values: values)
        runBulkConstruction("4-ary heap", as: FourAryMinHeap.self, values: values)
        runBulkConstruction("sorted array", as: SortedArrayMinQueue.self, values: values)
        runBulkConstruction("unsorted array", as: UnsortedArrayMinQueue.self, values: values)
        print("")
    }

    private static func benchmarkDraining(values: [Int]) {
        print("Remove every task by priority")
        runDraining("public Heap", as: PublicHeapMinQueue.self, values: values)
        runDraining("4-ary heap", as: FourAryMinHeap.self, values: values)
        runDraining("sorted array", as: SortedArrayMinQueue.self, values: values)
        runDraining("unsorted array", as: UnsortedArrayMinQueue.self, values: values)
        print("")
    }

    private static func benchmarkSteadyStateScheduling(
        values: [Int],
        initialValues: [Int]
    ) {
        print("Steady-state scheduler: remove next, enqueue next")
        runSteadyState(
            "public Heap",
            as: PublicHeapMinQueue.self,
            values: values,
            initialValues: initialValues
        )
        runSteadyState(
            "4-ary heap",
            as: FourAryMinHeap.self,
            values: values,
            initialValues: initialValues
        )
        runSteadyState(
            "sorted array",
            as: SortedArrayMinQueue.self,
            values: values,
            initialValues: initialValues
        )
        runSteadyState(
            "unsorted array",
            as: UnsortedArrayMinQueue.self,
            values: values,
            initialValues: initialValues
        )
        print("")
    }

    private static func benchmarkTopK(values: [Int], limit: Int) {
        print("Keep the \(limit) highest priorities from a stream")
        runTopK("public Heap", as: PublicHeapMinQueue.self, values: values, limit: limit)
        runTopK("4-ary heap", as: FourAryMinHeap.self, values: values, limit: limit)
        runTopK("sorted array", as: SortedArrayMinQueue.self, values: values, limit: limit)
        runTopK("unsorted array", as: UnsortedArrayMinQueue.self, values: values, limit: limit)
        print("")
    }

    private static func runIndividualInsertions<Queue: MinPriorityQueue>(
        _ label: String,
        as _: Queue.Type,
        values: [Int]
    ) {
        measure(label, workItems: values.count, unit: "insert") {
            var queue = Queue()
            for value in values {
                queue.insert(value)
            }
            return (queue.min ?? 0) &+ queue.count
        }
    }

    private static func runBulkConstruction<Queue: MinPriorityQueue>(
        _ label: String,
        as _: Queue.Type,
        values: [Int]
    ) {
        measure(label, workItems: values.count, unit: "element") {
            let queue = Queue(unordered: values)
            return (queue.min ?? 0) &+ queue.count
        }
    }

    private static func runDraining<Queue: MinPriorityQueue>(
        _ label: String,
        as _: Queue.Type,
        values: [Int]
    ) {
        measure(label, workItems: values.count, unit: "remove", setup: {
            Queue(unordered: values)
        }) { queue in
            var checksum = 0
            while let value = queue.removeMin() {
                checksum &+= value
            }
            return checksum
        }
    }

    private static func runSteadyState<Queue: MinPriorityQueue>(
        _ label: String,
        as _: Queue.Type,
        values: [Int],
        initialValues: [Int]
    ) {
        measure(label, workItems: values.count, unit: "schedule round", setup: {
            Queue(unordered: initialValues)
        }) { queue in
            var checksum = 0
            for value in values {
                checksum &+= queue.removeMin() ?? 0
                queue.insert(value)
            }
            return checksum &+ queue.count
        }
    }

    private static func runTopK<Queue: MinPriorityQueue>(
        _ label: String,
        as _: Queue.Type,
        values: [Int],
        limit: Int
    ) {
        measure(label, workItems: values.count, unit: "stream item") {
            var queue = Queue()
            var checksum = 0

            for value in values {
                if queue.count < limit {
                    queue.insert(value)
                } else if let minimum = queue.min, minimum < value {
                    checksum &+= queue.removeMin() ?? 0
                    queue.insert(value)
                }
            }

            while let value = queue.removeMin() {
                checksum &+= value
            }
            return checksum
        }
    }

    private static func verifyCandidates() {
        let values = [7, 2, 9, 2, 5, 1, 8, 3]
        verify(PublicHeapMinQueue.self, values: values)
        verify(FourAryMinHeap.self, values: values)
        verify(SortedArrayMinQueue.self, values: values)
        verify(UnsortedArrayMinQueue.self, values: values)
    }

    private static func verify<Queue: MinPriorityQueue>(
        _: Queue.Type,
        values: [Int]
    ) {
        var queue = Queue(unordered: values)
        var output: [Int] = []

        while let value = queue.removeMin() {
            output.append(value)
        }

        precondition(output == values.sorted(), "Candidate did not remove values in priority order")

        for value in values.reversed() {
            queue.insert(value)
        }

        output.removeAll(keepingCapacity: true)
        while let value = queue.removeMin() {
            output.append(value)
        }

        precondition(output == values.sorted(), "Candidate did not restore heap order after insertion")
        precondition(queue.isEmpty && queue.min == nil, "Candidate did not empty correctly")
    }

    private static func measure(
        _ label: String,
        workItems: Int,
        unit: String,
        iterations: Int = 3,
        _ body: () -> Int
    ) {
        var best = UInt64.max
        var checksum = 0

        for _ in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= body()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            best = min(best, elapsed)
        }

        printMeasurement(
            label: label,
            nanoseconds: best,
            workItems: workItems,
            unit: unit,
            iterations: iterations,
            checksum: checksum
        )
    }

    private static func measure<State>(
        _ label: String,
        workItems: Int,
        unit: String,
        iterations: Int = 3,
        setup: () -> State,
        _ body: (inout State) -> Int
    ) {
        var best = UInt64.max
        var checksum = 0

        for _ in 0..<iterations {
            var state = setup()
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= body(&state)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            best = min(best, elapsed)
        }

        printMeasurement(
            label: label,
            nanoseconds: best,
            workItems: workItems,
            unit: unit,
            iterations: iterations,
            checksum: checksum
        )
    }

    private static func printMeasurement(
        label: String,
        nanoseconds: UInt64,
        workItems: Int,
        unit: String,
        iterations: Int,
        checksum: Int
    ) {
        let nanosecondsPerItem = workItems == 0 ? 0 : Double(nanoseconds) / Double(workItems)
        let formattedNanoseconds = String(format: "%.1f", nanosecondsPerItem)
        print(
            "  \(label): \(milliseconds(nanoseconds)) best of \(iterations), " +
            "\(formattedNanoseconds) ns/\(unit) (checksum: \(checksum))"
        )
    }

    private static func milliseconds(_ nanoseconds: UInt64) -> String {
        let whole = nanoseconds / 1_000_000
        let fraction = (nanoseconds % 1_000_000) / 1_000
        let fractionText = String(fraction)
        let padding = String(repeating: "0", count: max(0, 3 - fractionText.count))
        return "\(whole).\(padding)\(fractionText) ms"
    }

    private static func makeValues(count: Int, seed: UInt64) -> [Int] {
        var generator = SeededGenerator(seed: seed)
        return (0..<count).map { _ in
            Int(generator.next() % 1_000_000)
        }
    }
}

private protocol MinPriorityQueue {
    init()
    init(unordered elements: [Int])

    var count: Int { get }
    var isEmpty: Bool { get }
    var min: Int? { get }

    mutating func insert(_ element: Int)
    mutating func removeMin() -> Int?
}

private extension MinPriorityQueue {
    var isEmpty: Bool {
        count == 0
    }
}

/// Adapts the public min-heap API to the benchmark's common candidate shape.
private struct PublicHeapMinQueue: MinPriorityQueue {
    private var heap: Heap<Int>

    init() {
        heap = Heap()
    }

    init(unordered elements: [Int]) {
        heap = Heap(elements)
    }

    var count: Int {
        heap.count
    }

    var min: Int? {
        heap.peek
    }

    mutating func insert(_ element: Int) {
        heap.insert(element)
    }

    mutating func removeMin() -> Int? {
        heap.pop()
    }
}

/// An array-backed four-ary min-heap. It reduces tree height but compares up
/// to four children at each level.
private struct FourAryMinHeap: MinPriorityQueue {
    private static let arity = 4

    private var storage: [Int]

    init() {
        storage = []
    }

    init(unordered elements: [Int]) {
        storage = elements.map { $0 }
        heapify()
    }

    var count: Int {
        storage.count
    }

    var min: Int? {
        storage.first
    }

    mutating func insert(_ element: Int) {
        storage.append(element)
        siftUp(from: storage.endIndex - 1)
    }

    mutating func removeMin() -> Int? {
        guard let minimum = storage.first else {
            return nil
        }

        if storage.count == 1 {
            return storage.removeLast()
        }

        storage[0] = storage.removeLast()
        siftDown(from: 0)
        return minimum
    }

    private mutating func heapify() {
        guard storage.count > 1 else {
            return
        }

        for index in stride(
            from: (storage.count - 2) / Self.arity,
            through: 0,
            by: -1
        ) {
            siftDown(from: index)
        }
    }

    private mutating func siftUp(from startIndex: Int) {
        var child = startIndex

        while child > 0 {
            let parent = (child - 1) / Self.arity
            guard storage[child] < storage[parent] else {
                return
            }

            storage.swapAt(child, parent)
            child = parent
        }
    }

    private mutating func siftDown(from startIndex: Int) {
        var parent = startIndex

        while true {
            let firstChild = parent * Self.arity + 1
            guard firstChild < storage.count else {
                return
            }

            let childEnd = Swift.min(firstChild + Self.arity, storage.count)
            var smallestChild = firstChild
            for child in (firstChild + 1)..<childEnd where storage[child] < storage[smallestChild] {
                smallestChild = child
            }

            guard storage[smallestChild] < storage[parent] else {
                return
            }

            storage.swapAt(parent, smallestChild)
            parent = smallestChild
        }
    }
}

/// A descending sorted array: reads and removals of the minimum are O(1),
/// while insertion is O(n).
private struct SortedArrayMinQueue: MinPriorityQueue {
    private var storage: [Int]

    init() {
        storage = []
    }

    init(unordered elements: [Int]) {
        storage = elements.sorted(by: >)
    }

    var count: Int {
        storage.count
    }

    var min: Int? {
        storage.last
    }

    mutating func insert(_ element: Int) {
        storage.insert(element, at: insertionIndex(for: element))
    }

    mutating func removeMin() -> Int? {
        storage.popLast()
    }

    private func insertionIndex(for element: Int) -> Int {
        var lowerBound = 0
        var upperBound = storage.count

        while lowerBound < upperBound {
            let middle = lowerBound + (upperBound - lowerBound) / 2
            if storage[middle] > element {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        return lowerBound
    }
}

/// An unsorted array: insertion is O(1), while finding or removing the
/// minimum is O(n).
private struct UnsortedArrayMinQueue: MinPriorityQueue {
    private var storage: [Int]

    init() {
        storage = []
    }

    init(unordered elements: [Int]) {
        storage = elements.map { $0 }
    }

    var count: Int {
        storage.count
    }

    var min: Int? {
        storage.min()
    }

    mutating func insert(_ element: Int) {
        storage.append(element)
    }

    mutating func removeMin() -> Int? {
        guard let minimumIndex = minimumIndex() else {
            return nil
        }

        let minimum = storage[minimumIndex]
        storage.swapAt(minimumIndex, storage.endIndex - 1)
        storage.removeLast()
        return minimum
    }

    private func minimumIndex() -> Int? {
        guard !storage.isEmpty else {
            return nil
        }

        var minimumIndex = 0
        for index in storage.indices.dropFirst() where storage[index] < storage[minimumIndex] {
            minimumIndex = index
        }
        return minimumIndex
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
