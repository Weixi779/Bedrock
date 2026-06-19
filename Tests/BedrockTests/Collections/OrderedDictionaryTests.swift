//
//  OrderedDictionaryTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/6/18.
//

import Testing
@testable import Bedrock

@Suite("OrderedDictionary")
struct OrderedDictionaryTests {
    @Test("Initializes as empty")
    func initializesAsEmpty() {
        let dictionary = OrderedDictionary<String, Int>()

        #expect(dictionary.isEmpty)
        #expect(dictionary.count == 0)
    }

    @Test("Initializes from sequence and updates duplicate keys in place")
    func initializesFromSequence() {
        let dictionary = OrderedDictionary([
            (key: "a", value: 1),
            (key: "b", value: 2),
            (key: "a", value: 3),
        ])

        #expect(dictionary.count == 2)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[0].value == 3)
        #expect(dictionary[1].key == "b")
        #expect(dictionary[1].value == 2)
    }

    @Test("Initializes from dictionary literal")
    func initializesFromDictionaryLiteral() {
        let dictionary: OrderedDictionary<String, Int> = [
            "a": 1,
            "b": 2,
        ]

        #expect(dictionary.count == 2)
        #expect(dictionary.keys == ["a", "b"])
        #expect(dictionary.values == [1, 2])
    }

    @Test("Equatable compares key value pairs in order")
    func equatableComparesKeyValuePairsInOrder() {
        let dictionary: OrderedDictionary<String, Int> = [
            "a": 1,
            "b": 2,
        ]
        let same = OrderedDictionary([
            (key: "a", value: 1),
            (key: "b", value: 2),
        ])
        let reordered = OrderedDictionary([
            (key: "b", value: 2),
            (key: "a", value: 1),
        ])

        #expect(dictionary == same)
        #expect(dictionary != reordered)
    }

    @Test("Hashable preserves ordered equality")
    func hashablePreservesOrderedEquality() {
        let dictionary: OrderedDictionary<String, Int> = [
            "a": 1,
            "b": 2,
        ]
        let same = OrderedDictionary([
            (key: "a", value: 1),
            (key: "b", value: 2),
        ])
        let reordered = OrderedDictionary([
            (key: "b", value: 2),
            (key: "a", value: 1),
        ])
        let set: Set<OrderedDictionary<String, Int>> = [dictionary]

        #expect(set.contains(same))
        #expect(!set.contains(reordered))
    }

    @Test("Update inserts new keys in order")
    func updateInsertsNewKeysInOrder() {
        var dictionary = OrderedDictionary<String, Int>()

        #expect(dictionary.updateValue(1, forKey: "a") == nil)
        #expect(dictionary.updateValue(2, forKey: "b") == nil)

        #expect(dictionary.count == 2)
        #expect(dictionary.contains(key: "a"))
        #expect(dictionary[key: "a"] == 1)
        #expect(dictionary[key: "b"] == 2)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "b")
    }

    @Test("Key subscript disambiguates integer keys from positions")
    func keySubscriptDisambiguatesIntegerKeysFromPositions() {
        var dictionary = OrderedDictionary<Int, String>()
        dictionary.updateValue("zero-key", forKey: 0)
        dictionary.updateValue("one-key", forKey: 1)

        #expect(dictionary[key: 0] == "zero-key")
        #expect(dictionary[0].key == 0)
        #expect(dictionary[0].value == "zero-key")
    }

    @Test("Update replaces existing value without moving key")
    func updateReplacesExistingValueWithoutMovingKey() throws {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, forKey: "a")
        dictionary.updateValue(2, forKey: "b")

        let updatedValue = dictionary.updateValue(3, forKey: "a")
        let oldValue = try #require(updatedValue)

        #expect(oldValue == 1)
        #expect(dictionary[key: "a"] == 3)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "b")
    }

    @Test("Insert adds new key at position")
    func insertAddsNewKeyAtPosition() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, forKey: "a")
        dictionary.updateValue(3, forKey: "c")

        dictionary.insert(2, forKey: "b", at: 1)

        #expect(dictionary.count == 3)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "b")
        #expect(dictionary[2].key == "c")
        #expect(dictionary.index(forKey: "c") == 2)
    }

    @Test("Remove by key deletes value and keeps remaining indices valid")
    func removeByKeyKeepsRemainingIndicesValid() throws {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, forKey: "a")
        dictionary.updateValue(2, forKey: "b")
        dictionary.updateValue(3, forKey: "c")

        let removedValue = dictionary.removeValue(forKey: "b")
        let removed = try #require(removedValue)

        #expect(removed == 2)
        #expect(dictionary.count == 2)
        #expect(dictionary[key: "b"] == nil)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "c")
        #expect(dictionary.index(forKey: "c") == 1)
    }

    @Test("Remove at position returns removed element")
    func removeAtPositionReturnsRemovedElement() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, forKey: "a")
        dictionary.updateValue(2, forKey: "b")

        let removed = dictionary.remove(at: 0)

        #expect(removed.key == "a")
        #expect(removed.value == 1)
        #expect(dictionary.count == 1)
        #expect(dictionary[0].key == "b")
        #expect(dictionary.index(forKey: "b") == 0)
    }

    @Test("Assigning nil through key subscript deletes value")
    func assigningNilThroughKeySubscriptDeletesValue() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary[key: "a"] = 1
        dictionary[key: "a"] = nil

        #expect(dictionary.isEmpty)
        #expect(dictionary[key: "a"] == nil)
    }

    @Test("Iterates in key order")
    func iteratesInKeyOrder() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, forKey: "a")
        dictionary.updateValue(2, forKey: "b")
        dictionary.updateValue(3, forKey: "c")

        let keys = dictionary.map(\.key)
        let values = dictionary.map(\.value)

        #expect(keys == ["a", "b", "c"])
        #expect(values == [1, 2, 3])
    }

    @Test("Keys and values expose ordered arrays")
    func keysAndValuesExposeOrderedArrays() {
        let dictionary: OrderedDictionary<String, Int> = [
            "a": 1,
            "b": 2,
            "c": 3,
        ]

        #expect(dictionary.keys == ["a", "b", "c"])
        #expect(dictionary.values == [1, 2, 3])
    }

    @Test("Remove all clears storage")
    func removeAllClearsStorage() {
        var dictionary: OrderedDictionary<String, Int> = [
            "a": 1,
            "b": 2,
        ]

        dictionary.reserveCapacity(8)
        dictionary.removeAll(keepingCapacity: true)
        dictionary.updateValue(3, forKey: "c")

        #expect(dictionary.count == 1)
        #expect(dictionary[key: "c"] == 3)
        #expect(dictionary.keys == ["c"])
    }

    @Test("Description lists key value pairs in order")
    func descriptionListsPairsInOrder() {
        let dictionary: OrderedDictionary<String, Int> = [
            "a": 1,
            "b": 2,
        ]

        #expect(dictionary.description == "[a: 1, b: 2]")
    }

    @Test("Supports random access collection operations")
    func supportsRandomAccessCollectionOperations() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, forKey: "a")
        dictionary.updateValue(2, forKey: "b")
        dictionary.updateValue(3, forKey: "c")

        #expect(dictionary.first?.key == "a")
        #expect(dictionary.last?.key == "c")
        #expect(dictionary[dictionary.index(after: dictionary.startIndex)].key == "b")
        #expect(dictionary[dictionary.index(before: dictionary.endIndex)].key == "c")
        #expect(dictionary.prefix(2).map(\.key) == ["a", "b"])
    }
}
