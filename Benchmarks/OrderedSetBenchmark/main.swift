import Bedrock
import Foundation

@main
struct OrderedSetBenchmark {
    static func main() {
        let size = CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 10_000
        let removalCount = max(1, size / 5)
        let lookupKeys = makePermutation(count: size, seed: 0x05E7_0001)
        let removalKeys = Array(lookupKeys.prefix(removalCount))
        let duplicateKeys = makeDuplicateInput(uniqueCount: size, repeats: 2)

        print("OrderedSet storage benchmark")
        print("size: \(size)")
        print("duplicate input: \(duplicateKeys.count)")
        print("removals: \(removalCount)")
        print("")

        benchmarkCreateUnique(size: size)
        benchmarkCreateWithDuplicates(keys: duplicateKeys)
        benchmarkUpdateExisting(size: size, keys: lookupKeys)
        benchmarkContains(size: size, keys: lookupKeys)
        benchmarkIndexLookup(size: size, keys: lookupKeys)
        benchmarkRemove(size: size, keys: removalKeys)
        benchmarkRandomAccess(size: size, indices: lookupKeys)
    }

    private static func benchmarkCreateUnique(size: Int) {
        print("Create by inserting unique elements")
        measure("public OrderedSet") {
            var set = OrderedSet<Int>()
            for key in 0..<size {
                set.insert(key)
            }
            return set.count
        }
        measure("elements + indices") {
            var set = ArrayDictionaryOrderedSet<Int>()
            for key in 0..<size {
                set.insert(key)
            }
            return set.count
        }
        measure("array + set") {
            var set = ArraySetOrderedSet<Int>()
            for key in 0..<size {
                set.insert(key)
            }
            return set.count
        }
        measure("dictionary + void") {
            var set = DictionaryVoidOrderedSet<Int>()
            for key in 0..<size {
                set.insert(key)
            }
            return set.count
        }
        print("")
    }

    private static func benchmarkCreateWithDuplicates(keys: [Int]) {
        print("Create from duplicate-heavy input")
        measure("public OrderedSet") {
            var set = OrderedSet<Int>()
            for key in keys {
                set.insert(key)
            }
            return set.count
        }
        measure("elements + indices") {
            var set = ArrayDictionaryOrderedSet<Int>()
            for key in keys {
                set.insert(key)
            }
            return set.count
        }
        measure("array + set") {
            var set = ArraySetOrderedSet<Int>()
            for key in keys {
                set.insert(key)
            }
            return set.count
        }
        measure("dictionary + void") {
            var set = DictionaryVoidOrderedSet<Int>()
            for key in keys {
                set.insert(key)
            }
            return set.count
        }
        print("")
    }

    private static func benchmarkContains(size: Int, keys: [Int]) {
        print("Contains existing elements")
        let currentSet = makeCurrentSet(size: size)
        let arrayDictionarySet = makeArrayDictionarySet(size: size)
        let arraySet = makeArraySet(size: size)
        let dictionaryVoidSet = makeDictionaryVoidSet(size: size)

        measure("public OrderedSet") {
            keys.reduce(into: 0) { sum, key in
                sum &+= currentSet.contains(key) ? 1 : 0
            }
        }
        measure("elements + indices") {
            keys.reduce(into: 0) { sum, key in
                sum &+= arrayDictionarySet.contains(key) ? 1 : 0
            }
        }
        measure("array + set") {
            keys.reduce(into: 0) { sum, key in
                sum &+= arraySet.contains(key) ? 1 : 0
            }
        }
        measure("dictionary + void") {
            keys.reduce(into: 0) { sum, key in
                sum &+= dictionaryVoidSet.contains(key) ? 1 : 0
            }
        }
        print("")
    }

    private static func benchmarkUpdateExisting(size: Int, keys: [Int]) {
        print("Update existing elements")
        measure("public OrderedSet") {
            var set = makeCurrentSet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.update(with: key) ?? 0
            }
            return checksum &+ set.count
        }
        measure("elements + indices") {
            var set = makeArrayDictionarySet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.update(with: key) ?? 0
            }
            return checksum &+ set.count
        }
        measure("array + set") {
            var set = makeArraySet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.update(with: key) ?? 0
            }
            return checksum &+ set.count
        }
        measure("dictionary + void") {
            var set = makeDictionaryVoidSet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.update(with: key) ?? 0
            }
            return checksum &+ set.count
        }
        print("")
    }


    private static func benchmarkIndexLookup(size: Int, keys: [Int]) {
        print("Index lookup for existing elements")
        let currentSet = makeCurrentSet(size: size)
        let arrayDictionarySet = makeArrayDictionarySet(size: size)
        let arraySet = makeArraySet(size: size)
        let dictionaryVoidSet = makeDictionaryVoidSet(size: size)

        measure("public OrderedSet") {
            keys.reduce(into: 0) { sum, key in
                sum &+= currentSet.index(for: key) ?? 0
            }
        }
        measure("elements + indices") {
            keys.reduce(into: 0) { sum, key in
                sum &+= arrayDictionarySet.index(for: key) ?? 0
            }
        }
        measure("array + set") {
            keys.reduce(into: 0) { sum, key in
                sum &+= arraySet.index(for: key) ?? 0
            }
        }
        measure("dictionary + void") {
            keys.reduce(into: 0) { sum, key in
                sum &+= dictionaryVoidSet.index(for: key) ?? 0
            }
        }
        print("")
    }

    private static func benchmarkRemove(size: Int, keys: [Int]) {
        print("Remove by element, preserving order")
        measure("public OrderedSet") {
            var set = makeCurrentSet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.remove(key) ?? 0
            }
            return checksum &+ set.count
        }
        measure("elements + indices") {
            var set = makeArrayDictionarySet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.remove(key) ?? 0
            }
            return checksum &+ set.count
        }
        measure("array + set") {
            var set = makeArraySet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.remove(key) ?? 0
            }
            return checksum &+ set.count
        }
        measure("dictionary + void") {
            var set = makeDictionaryVoidSet(size: size)
            var checksum = 0
            for key in keys {
                checksum &+= set.remove(key) ?? 0
            }
            return checksum &+ set.count
        }
        print("")
    }

    private static func benchmarkRandomAccess(size: Int, indices: [Int]) {
        print("Random access by shuffled indices")
        let currentSet = makeCurrentSet(size: size)
        let arrayDictionarySet = makeArrayDictionarySet(size: size)
        let arraySet = makeArraySet(size: size)
        let dictionaryVoidSet = makeDictionaryVoidSet(size: size)
        let rounds = max(1, 1_000_000 / max(size, 1))

        measure("public OrderedSet") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= currentSet[index]
                }
            }
            return checksum
        }
        measure("elements + indices") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= arrayDictionarySet[index]
                }
            }
            return checksum
        }
        measure("array + set") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= arraySet[index]
                }
            }
            return checksum
        }
        measure("dictionary + void") {
            var checksum = 0
            for _ in 0..<rounds {
                for index in indices {
                    checksum &+= dictionaryVoidSet[index]
                }
            }
            return checksum
        }
        print("")
    }

    private static func makeCurrentSet(size: Int) -> OrderedSet<Int> {
        var set = OrderedSet<Int>()
        for key in 0..<size {
            set.insert(key)
        }
        return set
    }

    private static func makeArrayDictionarySet(size: Int) -> ArrayDictionaryOrderedSet<Int> {
        var set = ArrayDictionaryOrderedSet<Int>()
        for key in 0..<size {
            set.insert(key)
        }
        return set
    }

    private static func makeArraySet(size: Int) -> ArraySetOrderedSet<Int> {
        var set = ArraySetOrderedSet<Int>()
        for key in 0..<size {
            set.insert(key)
        }
        return set
    }

    private static func makeDictionaryVoidSet(size: Int) -> DictionaryVoidOrderedSet<Int> {
        var set = DictionaryVoidOrderedSet<Int>()
        for key in 0..<size {
            set.insert(key)
        }
        return set
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

    private static func makeDuplicateInput(uniqueCount: Int, repeats: Int) -> [Int] {
        let values = makePermutation(count: uniqueCount, seed: 0x05E7_D00D)
        var result: [Int] = []
        result.reserveCapacity(uniqueCount * repeats)

        for _ in 0..<repeats {
            result.append(contentsOf: values)
        }

        return result
    }
}

private struct ArrayDictionaryOrderedSet<Element: Hashable> {
    private var elements: [Element] = []
    private var indices: [Element: Int] = [:]

    var count: Int {
        elements.count
    }

    subscript(position: Int) -> Element {
        elements[position]
    }

    func contains(_ element: Element) -> Bool {
        indices[element] != nil
    }

    func index(for element: Element) -> Int? {
        indices[element]
    }

    @discardableResult
    mutating func insert(_ element: Element) -> Bool {
        guard indices[element] == nil else {
            return false
        }

        indices[element] = elements.count
        elements.append(element)
        return true
    }

    mutating func update(with element: Element) -> Element? {
        guard let index = indices[element] else {
            indices[element] = elements.count
            elements.append(element)
            return nil
        }

        let oldElement = elements[index]
        elements[index] = element
        indices.removeValue(forKey: oldElement)
        indices[element] = index
        return oldElement
    }

    mutating func remove(_ element: Element) -> Element? {
        guard let index = indices.removeValue(forKey: element) else {
            return nil
        }

        let oldElement = elements.remove(at: index)
        rebuildIndices(startingAt: index)
        return oldElement
    }

    private mutating func rebuildIndices(startingAt startIndex: Int) {
        guard startIndex < elements.count else {
            return
        }

        for index in startIndex..<elements.count {
            indices[elements[index]] = index
        }
    }
}

private struct ArraySetOrderedSet<Element: Hashable> {
    private var elements: [Element] = []
    private var members: Set<Element> = []

    var count: Int {
        elements.count
    }

    subscript(position: Int) -> Element {
        elements[position]
    }

    func contains(_ element: Element) -> Bool {
        members.contains(element)
    }

    func index(for element: Element) -> Int? {
        elements.firstIndex(of: element)
    }

    @discardableResult
    mutating func insert(_ element: Element) -> Bool {
        let result = members.insert(element)
        guard result.inserted else {
            return false
        }

        elements.append(element)
        return true
    }

    mutating func update(with element: Element) -> Element? {
        guard let oldElement = members.update(with: element) else {
            elements.append(element)
            return nil
        }

        guard let index = elements.firstIndex(of: oldElement) else {
            return oldElement
        }

        elements[index] = element
        return oldElement
    }

    mutating func remove(_ element: Element) -> Element? {
        guard let oldElement = members.remove(element) else {
            return nil
        }

        guard let index = elements.firstIndex(of: element) else {
            return oldElement
        }

        elements.remove(at: index)
        return oldElement
    }
}

private struct DictionaryVoidOrderedSet<Element: Hashable> {
    private var storage = OrderedDictionary<Element, Void>()

    var count: Int {
        storage.count
    }

    subscript(position: Int) -> Element {
        storage[position].key
    }

    func contains(_ element: Element) -> Bool {
        storage.contains(for: element)
    }

    func index(for element: Element) -> Int? {
        storage.index(for: element)
    }

    @discardableResult
    mutating func insert(_ element: Element) -> Bool {
        guard !storage.contains(for: element) else {
            return false
        }

        storage.updateValue((), for: element)
        return true
    }

    mutating func update(with element: Element) -> Element? {
        guard let index = storage.index(for: element) else {
            storage.updateValue((), for: element)
            return nil
        }

        let oldElement = storage[index].key
        storage.remove(at: index)
        storage.insert((), for: element, at: index)
        return oldElement
    }

    mutating func remove(_ element: Element) -> Element? {
        guard storage.removeValue(for: element) != nil else {
            return nil
        }

        return element
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
