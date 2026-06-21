//
//  LRUCacheTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/6/21.
//

import Testing
@testable import Bedrock

@Suite("LRUCache")
struct LRUCacheTests {
    @Test("Initializes as empty with fixed capacity")
    func initializesAsEmptyWithFixedCapacity() {
        let cache = LRUCache<String, Int>(capacity: 3)

        #expect(cache.capacity == 3)
        #expect(cache.count == 0)
        #expect(cache.isEmpty)
        #expect(!cache.isFull)
        #expect(cache.leastRecentlyUsed == nil)
        #expect(cache.mostRecentlyUsed == nil)
        #expect(cache.elements.isEmpty)
    }

    @Test("Initializes from sequence and evicts older entries")
    func initializesFromSequenceAndEvictsOlderEntries() {
        let cache = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
                (key: "c", value: 3),
                (key: "d", value: 4),
            ],
            capacity: 3
        )

        #expect(cache.count == 3)
        #expect(cache.isFull)
        #expect(cache.keys == ["b", "c", "d"])
        #expect(cache.values == [2, 3, 4])
        #expect(cache.leastRecentlyUsed?.key == "b")
        #expect(cache.mostRecentlyUsed?.key == "d")
    }

    @Test("Duplicate keys update value and recency")
    func duplicateKeysUpdateValueAndRecency() {
        let cache = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
                (key: "a", value: 3),
                (key: "c", value: 4),
            ],
            capacity: 2
        )

        #expect(cache.keys == ["a", "c"])
        #expect(cache.values == [3, 4])
    }

    @Test("Value access refreshes recency")
    func valueAccessRefreshesRecency() {
        var cache = LRUCache<String, Int>(capacity: 3)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")
        cache.updateValue(3, forKey: "c")

        #expect(cache.value(forKey: "a") == 1)

        #expect(cache.keys == ["b", "c", "a"])
        #expect(cache.leastRecentlyUsed?.key == "b")
        #expect(cache.mostRecentlyUsed?.key == "a")
    }

    @Test("Peek does not refresh recency")
    func peekDoesNotRefreshRecency() {
        var cache = LRUCache<String, Int>(capacity: 3)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")
        cache.updateValue(3, forKey: "c")

        #expect(cache.peekValue(forKey: "a") == 1)
        cache.updateValue(4, forKey: "d")

        #expect(cache.keys == ["b", "c", "d"])
        #expect(!cache.contains(key: "a"))
    }

    @Test("Update returns old value and moves key to most recent")
    func updateReturnsOldValueAndMovesKeyToMostRecent() throws {
        var cache = LRUCache<String, Int>(capacity: 3)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")

        let updatedValue = cache.updateValue(3, forKey: "a")
        let oldValue = try #require(updatedValue)

        #expect(oldValue == 1)
        #expect(cache.peekValue(forKey: "a") == 3)
        #expect(cache.keys == ["b", "a"])
    }

    @Test("Insertion evicts least recently used entry when full")
    func insertionEvictsLeastRecentlyUsedEntryWhenFull() {
        var cache = LRUCache<String, Int>(capacity: 2)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")
        cache.value(forKey: "a")
        cache.updateValue(3, forKey: "c")

        #expect(cache.keys == ["a", "c"])
        #expect(cache.peekValue(forKey: "b") == nil)
    }

    @Test("Remove by key deletes value and preserves order")
    func removeByKeyDeletesValueAndPreservesOrder() throws {
        var cache = LRUCache<String, Int>(capacity: 3)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")
        cache.updateValue(3, forKey: "c")

        let removedValue = cache.removeValue(forKey: "b")
        let removed = try #require(removedValue)

        #expect(removed == 2)
        #expect(cache.keys == ["a", "c"])
        #expect(cache.removeValue(forKey: "b") == nil)
    }

    @Test("Remove least and most recently used entries")
    func removeLeastAndMostRecentlyUsedEntries() throws {
        var cache = LRUCache<String, Int>(capacity: 3)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")
        cache.updateValue(3, forKey: "c")

        let removedLeast = cache.removeLeastRecentlyUsed()
        let least = try #require(removedLeast)
        let removedMost = cache.removeMostRecentlyUsed()
        let most = try #require(removedMost)

        #expect(least.key == "a")
        #expect(least.value == 1)
        #expect(most.key == "c")
        #expect(most.value == 3)
        #expect(cache.keys == ["b"])
    }

    @Test("Zero capacity discards inserted values")
    func zeroCapacityDiscardsInsertedValues() {
        var cache = LRUCache<String, Int>(capacity: 0)

        #expect(cache.isFull)
        #expect(cache.updateValue(1, forKey: "a") == nil)
        #expect(cache.value(forKey: "a") == nil)
        #expect(cache.isEmpty)
        #expect(cache.elements.isEmpty)
    }

    @Test("Remove all clears storage and keeps capacity")
    func removeAllClearsStorageAndKeepsCapacity() {
        var cache = LRUCache<String, Int>(capacity: 2)
        cache.updateValue(1, forKey: "a")
        cache.updateValue(2, forKey: "b")

        cache.removeAll(keepingCapacity: true)
        cache.updateValue(3, forKey: "c")

        #expect(cache.capacity == 2)
        #expect(cache.keys == ["c"])
    }

    @Test("Equatable includes capacity and recency order")
    func equatableIncludesCapacityAndRecencyOrder() {
        let cache = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
            ],
            capacity: 2
        )
        let same = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
            ],
            capacity: 2
        )
        let larger = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
            ],
            capacity: 3
        )
        let reordered = LRUCache(
            [
                (key: "b", value: 2),
                (key: "a", value: 1),
            ],
            capacity: 2
        )

        #expect(cache == same)
        #expect(cache != larger)
        #expect(cache != reordered)
    }

    @Test("Hashable includes capacity and recency order")
    func hashableIncludesCapacityAndRecencyOrder() {
        let cache = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
            ],
            capacity: 2
        )
        let same = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
            ],
            capacity: 2
        )
        let reordered = LRUCache(
            [
                (key: "b", value: 2),
                (key: "a", value: 1),
            ],
            capacity: 2
        )

        #expect(Set([cache]).contains(same))
        #expect(!Set([cache]).contains(reordered))
    }

    @Test("Description lists entries from least to most recent")
    func descriptionListsEntriesFromLeastToMostRecent() {
        let cache = LRUCache(
            [
                (key: "a", value: 1),
                (key: "b", value: 2),
            ],
            capacity: 3
        )

        #expect(cache.description == "[a: 1, b: 2]")
        #expect(cache.debugDescription == #"LRUCache(capacity: 3, ["a": 1, "b": 2])"#)
    }
}
