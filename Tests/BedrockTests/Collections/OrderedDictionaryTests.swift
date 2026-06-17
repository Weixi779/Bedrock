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

    @Test("Update inserts new keys in order")
    func updateInsertsNewKeysInOrder() {
        var dictionary = OrderedDictionary<String, Int>()

        #expect(dictionary.updateValue(1, for: "a") == nil)
        #expect(dictionary.updateValue(2, for: "b") == nil)

        #expect(dictionary.count == 2)
        #expect(dictionary[for: "a"] == 1)
        #expect(dictionary[for: "b"] == 2)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "b")
    }

    @Test("Update replaces existing value without moving key")
    func updateReplacesExistingValueWithoutMovingKey() throws {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, for: "a")
        dictionary.updateValue(2, for: "b")

        let updatedValue = dictionary.updateValue(3, for: "a")
        let oldValue = try #require(updatedValue)

        #expect(oldValue == 1)
        #expect(dictionary[for: "a"] == 3)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "b")
    }

    @Test("Insert adds new key at position")
    func insertAddsNewKeyAtPosition() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, for: "a")
        dictionary.updateValue(3, for: "c")

        dictionary.insert(2, for: "b", at: 1)

        #expect(dictionary.count == 3)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "b")
        #expect(dictionary[2].key == "c")
        #expect(dictionary.index(for: "c") == 2)
    }

    @Test("Remove by key deletes value and keeps remaining indices valid")
    func removeByKeyKeepsRemainingIndicesValid() throws {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, for: "a")
        dictionary.updateValue(2, for: "b")
        dictionary.updateValue(3, for: "c")

        let removedValue = dictionary.removeValue(for: "b")
        let removed = try #require(removedValue)

        #expect(removed == 2)
        #expect(dictionary.count == 2)
        #expect(dictionary[for: "b"] == nil)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "c")
        #expect(dictionary.index(for: "c") == 1)
    }

    @Test("Remove at position returns removed element")
    func removeAtPositionReturnsRemovedElement() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, for: "a")
        dictionary.updateValue(2, for: "b")

        let removed = dictionary.remove(at: 0)

        #expect(removed.key == "a")
        #expect(removed.value == 1)
        #expect(dictionary.count == 1)
        #expect(dictionary[0].key == "b")
        #expect(dictionary.index(for: "b") == 0)
    }

    @Test("Assigning nil through key subscript deletes value")
    func assigningNilThroughKeySubscriptDeletesValue() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary[for: "a"] = 1
        dictionary[for: "a"] = nil

        #expect(dictionary.isEmpty)
        #expect(dictionary[for: "a"] == nil)
    }

    @Test("Iterates in key order")
    func iteratesInKeyOrder() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, for: "a")
        dictionary.updateValue(2, for: "b")
        dictionary.updateValue(3, for: "c")

        let keys = dictionary.map(\.key)
        let values = dictionary.map(\.value)

        #expect(keys == ["a", "b", "c"])
        #expect(values == [1, 2, 3])
    }

    @Test("Supports random access collection operations")
    func supportsRandomAccessCollectionOperations() {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, for: "a")
        dictionary.updateValue(2, for: "b")
        dictionary.updateValue(3, for: "c")

        #expect(dictionary.first?.key == "a")
        #expect(dictionary.last?.key == "c")
        #expect(dictionary[dictionary.index(after: dictionary.startIndex)].key == "b")
        #expect(dictionary[dictionary.index(before: dictionary.endIndex)].key == "c")
        #expect(dictionary.prefix(2).map(\.key) == ["a", "b"])
    }
}
