//
//  ReferenceLRUCacheTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/7/25.
//

import Testing
@testable import Bedrock

@Suite("ReferenceLRUCache")
struct ReferenceLRUCacheTests {
    @Test("Maintains exact LRU order across reads, updates, and removals")
    func maintainsExactLRUOrder() {
        let cache = ReferenceLRUCache<String, Int>(capacity: 3)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")
        cache.updateValue(3, forKey: "c")

        #expect(cache.value(forKey: "a") == 1)
        #expect(cache.updateValue(4, forKey: "b") == 2)
        #expect(cache.removeValue(forKey: "a") == 1)

        #expect(cache.keys == ["c", "b"])
        #expect(cache.values == [3, 4])
        #expect(cache.leastRecentlyUsed?.key == "c")
        #expect(cache.mostRecentlyUsed?.key == "b")
    }

    @Test("Evicts the least recent entry and supports end removals")
    func evictsAndRemovesEnds() throws {
        let cache = ReferenceLRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
                (key: "c", value: 3),
            ],
            capacity: 3
        )
        cache.value(forKey: "a")
        cache.updateValue(4, forKey: "d")

        #expect(cache.keys == ["c", "a", "d"])
        #expect(cache.peekValue(forKey: "b") == nil)

        let least = try #require(cache.removeLeastRecentlyUsed())
        let most = try #require(cache.removeMostRecentlyUsed())
        #expect(least.key == "c")
        #expect(most.key == "d")
        #expect(cache.keys == ["a"])
    }

    @Test("Zero capacity discards values")
    func zeroCapacityDiscardsValues() {
        let cache = ReferenceLRUCache<String, Int>(capacity: 0)

        #expect(cache.isFull)
        #expect(cache.updateValue(1, forKey: "a") == nil)
        #expect(cache.value(forKey: "a") == nil)
        #expect(cache.isEmpty)
    }

    @Test("Assignments share cache mutations")
    func assignmentsShareMutations() {
        let cache = ReferenceLRUCache<String, Int>(capacity: 2)
        let alias = cache

        cache.updateValue(1, forKey: "a")
        alias.updateValue(2, forKey: "b")
        alias.value(forKey: "a")

        #expect(cache.keys == ["b", "a"])
        #expect(alias.elements.map(\.key) == cache.elements.map(\.key))
    }

    @Test("Remove all resets links and permits reuse")
    func removeAllResetsLinks() {
        let cache = ReferenceLRUCache<String, Int>(capacity: 3)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")

        cache.removeAll(keepingCapacity: true)
        cache.updateValue(3, forKey: "c")

        #expect(cache.count == 1)
        #expect(cache.keys == ["c"])
        #expect(cache.leastRecentlyUsed?.key == "c")
        #expect(cache.mostRecentlyUsed?.key == "c")
    }

    @Test("Matches index-backed LRU across a seeded operation trace")
    func matchesIndexBackedLRUAcrossSeededTrace() {
        let capacity = 37
        var indexed = LRUCache<Int, Int>(capacity: capacity)
        let reference = ReferenceLRUCache<Int, Int>(capacity: capacity)
        var generator = LRUTraceGenerator(seed: 0xBED0_CAC4)

        for _ in 0..<50_000 {
            let key = Int(generator.next() % 101)
            let value = Int(truncatingIfNeeded: generator.next())

            switch generator.next() % 7 {
            case 0, 1:
                #expect(indexed.value(forKey: key) == reference.value(forKey: key))
            case 2, 3, 4:
                #expect(
                    indexed.updateValue(value, forKey: key) ==
                        reference.updateValue(value, forKey: key)
                )
            case 5:
                #expect(
                    indexed.removeValue(forKey: key) ==
                        reference.removeValue(forKey: key)
                )
            default:
                let indexedElement = indexed.removeLeastRecentlyUsed()
                let referenceElement = reference.removeLeastRecentlyUsed()
                #expect(indexedElement?.key == referenceElement?.key)
                #expect(indexedElement?.value == referenceElement?.value)
            }

            #expect(indexed.elements.map(\.key) == reference.elements.map(\.key))
            #expect(indexed.elements.map(\.value) == reference.elements.map(\.value))
        }
    }

    @Test("Descriptions expose reference cache identity")
    func descriptionsExposeReferenceCacheIdentity() {
        let cache = ReferenceLRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
            ],
            capacity: 3
        )

        #expect(cache.description == "[a: 1, b: 2]")
        #expect(
            cache.debugDescription ==
                #"ReferenceLRUCache(capacity: 3, ["a": 1, "b": 2])"#
        )
    }
}

private struct LRUTraceGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
