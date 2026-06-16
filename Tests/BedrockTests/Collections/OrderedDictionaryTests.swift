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

        #expect(dictionary.updateValue(1, forKey: "a") == nil)
        #expect(dictionary.updateValue(2, forKey: "b") == nil)

        #expect(dictionary.count == 2)
        #expect(dictionary["a"] == 1)
        #expect(dictionary["b"] == 2)
        #expect(dictionary[0].key == "a")
        #expect(dictionary[1].key == "b")
    }

    @Test("Update replaces existing value without moving key")
    func updateReplacesExistingValueWithoutMovingKey() throws {
        var dictionary = OrderedDictionary<String, Int>()
        dictionary.updateValue(1, forKey: "a")
        dictionary.updateValue(2, forKey: "b")

        let updatedValue = dictionary.updateValue(3, forKey: "a")
        let oldValue = try #require(updatedValue)

        #expect(oldValue == 1)
        #expect(dictionary["a"] == 3)
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
        #expect(dictionary["b"] == nil)
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
        dictionary["a"] = 1
        dictionary["a"] = nil

        #expect(dictionary.isEmpty)
        #expect(dictionary["a"] == nil)
    }
}
