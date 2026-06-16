import Bedrock
import Foundation

@main
struct OrderedDictionaryBenchmark {
    static func main() {
        let size = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 10_000
        let removalCount = max(1, size / 5)
        let lookupKeys = makePermutation(count: size, seed: 0xBED0_0C4)
        let removalKeys = Array(lookupKeys.prefix(removalCount))

        print("OrderedDictionary storage benchmark")
        print("size: \(size)")
        print("removals: \(removalCount)")
        print("")

        benchmarkCreate(size: size)
        benchmarkRead(size: size, keys: lookupKeys)
        benchmarkUpdate(size: size, keys: lookupKeys)
        benchmarkRemove(size: size, keys: removalKeys)
        benchmarkInsertAtFront(size: size)
    }

    private static func benchmarkCreate(size: Int) {
        print("Create by appending unique keys")
        measure("element storage") {
            var dictionary = ElementStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.updateValue(key, forKey: key)
            }
            return dictionary.count
        }
        measure("split storage") {
            var dictionary = SplitStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.updateValue(key, forKey: key)
            }
            return dictionary.count
        }
        print("")
    }

    private static func benchmarkRead(size: Int, keys: [Int]) {
        print("Read existing keys")

        var elementDictionary = ElementStorageOrderedDictionary<Int, Int>()
        var splitDictionary = SplitStorageOrderedDictionary<Int, Int>()
        for key in 0..<size {
            elementDictionary.updateValue(key, forKey: key)
            splitDictionary.updateValue(key, forKey: key)
        }

        measure("element storage") {
            keys.reduce(into: 0) { sum, key in
                sum &+= elementDictionary.value(forKey: key) ?? 0
            }
        }
        measure("split storage") {
            keys.reduce(into: 0) { sum, key in
                sum &+= splitDictionary.value(forKey: key) ?? 0
            }
        }
        print("")
    }

    private static func benchmarkUpdate(size: Int, keys: [Int]) {
        print("Update existing keys")
        measure("element storage") {
            var dictionary = ElementStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.updateValue(key, forKey: key)
            }
            for key in keys {
                dictionary.updateValue(key &* 2, forKey: key)
            }
            return dictionary.count
        }
        measure("split storage") {
            var dictionary = SplitStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.updateValue(key, forKey: key)
            }
            for key in keys {
                dictionary.updateValue(key &* 2, forKey: key)
            }
            return dictionary.count
        }
        print("")
    }

    private static func benchmarkRemove(size: Int, keys: [Int]) {
        print("Remove by key, preserving order")
        measure("element storage") {
            var dictionary = ElementStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.updateValue(key, forKey: key)
            }
            var checksum = 0
            for key in keys {
                checksum &+= dictionary.removeValue(forKey: key) ?? 0
            }
            return checksum &+ dictionary.count
        }
        measure("split storage") {
            var dictionary = SplitStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.updateValue(key, forKey: key)
            }
            var checksum = 0
            for key in keys {
                checksum &+= dictionary.removeValue(forKey: key) ?? 0
            }
            return checksum &+ dictionary.count
        }
        print("")
    }

    private static func benchmarkInsertAtFront(size: Int) {
        print("Insert unique keys at front")
        measure("element storage") {
            var dictionary = ElementStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.insert(key, forKey: key, at: 0)
            }
            return dictionary.count
        }
        measure("split storage") {
            var dictionary = SplitStorageOrderedDictionary<Int, Int>()
            for key in 0..<size {
                dictionary.insert(key, forKey: key, at: 0)
            }
            return dictionary.count
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

private struct ElementStorageOrderedDictionary<Key: Hashable, Value> {
    private typealias Element = (key: Key, value: Value)

    private var elements: [Element] = []
    private var indices: [Key: Int] = [:]

    var count: Int {
        elements.count
    }

    func value(forKey key: Key) -> Value? {
        guard let index = indices[key] else {
            return nil
        }

        return elements[index].value
    }

    mutating func updateValue(_ value: Value, forKey key: Key) {
        if let index = indices[key] {
            elements[index].value = value
            return
        }

        indices[key] = elements.count
        elements.append((key: key, value: value))
    }

    mutating func insert(_ value: Value, forKey key: Key, at index: Int) {
        elements.insert((key: key, value: value), at: index)
        rebuildIndices(startingAt: index)
    }

    mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = indices.removeValue(forKey: key) else {
            return nil
        }

        let element = elements.remove(at: index)
        rebuildIndices(startingAt: index)
        return element.value
    }

    private mutating func rebuildIndices(startingAt startIndex: Int) {
        guard startIndex < elements.count else {
            return
        }

        for index in startIndex..<elements.count {
            indices[elements[index].key] = index
        }
    }
}

private struct SplitStorageOrderedDictionary<Key: Hashable, Value> {
    private var keys: [Key] = []
    private var values: [Value] = []
    private var indices: [Key: Int] = [:]

    var count: Int {
        keys.count
    }

    func value(forKey key: Key) -> Value? {
        guard let index = indices[key] else {
            return nil
        }

        return values[index]
    }

    mutating func updateValue(_ value: Value, forKey key: Key) {
        if let index = indices[key] {
            values[index] = value
            return
        }

        indices[key] = keys.count
        keys.append(key)
        values.append(value)
    }

    mutating func insert(_ value: Value, forKey key: Key, at index: Int) {
        keys.insert(key, at: index)
        values.insert(value, at: index)
        rebuildIndices(startingAt: index)
    }

    mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = indices.removeValue(forKey: key) else {
            return nil
        }

        keys.remove(at: index)
        let value = values.remove(at: index)
        rebuildIndices(startingAt: index)
        return value
    }

    private mutating func rebuildIndices(startingAt startIndex: Int) {
        guard startIndex < keys.count else {
            return
        }

        for index in startIndex..<keys.count {
            indices[keys[index]] = index
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
