import Testing
@testable import Bedrock

@Suite("OrderedSet")
struct OrderedSetTests {
    @Test("Initializes as empty")
    func initializesAsEmpty() {
        let set = OrderedSet<String>()

        #expect(set.isEmpty)
        #expect(set.count == 0)
    }

    @Test("Initializes from sequence and preserves first occurrence order")
    func initializesFromSequence() {
        let set = OrderedSet(["a", "b", "a", "c", "b"])

        #expect(set.count == 3)
        #expect(set.map { $0 } == ["a", "b", "c"])
    }

    @Test("Insert adds new elements in order")
    func insertAddsNewElementsInOrder() {
        var set = OrderedSet<String>()
        let insertedA = set.insert("a")
        let insertedB = set.insert("b")

        #expect(insertedA)
        #expect(insertedB)

        #expect(set.count == 2)
        #expect(set.contains("a"))
        #expect(set.contains("b"))
        #expect(set[0] == "a")
        #expect(set[1] == "b")
    }

    @Test("Insert rejects duplicates")
    func insertRejectsDuplicates() {
        var set = OrderedSet<String>()
        let inserted = set.insert("a")
        let duplicateInserted = set.insert("a")

        #expect(inserted)
        #expect(!duplicateInserted)

        #expect(set.count == 1)
        #expect(set[0] == "a")
    }

    @Test("Update replaces existing element without moving it")
    func updateReplacesExistingElementWithoutMovingIt() throws {
        struct Item: Hashable {
            var id: Int
            var name: String

            static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.id == rhs.id
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(id)
            }
        }

        var set = OrderedSet<Item>()
        set.insert(Item(id: 1, name: "old"))
        set.insert(Item(id: 2, name: "second"))

        let updatedItem = set.update(with: Item(id: 1, name: "new"))
        let oldItem = try #require(updatedItem)

        #expect(oldItem.name == "old")
        #expect(set[0].name == "new")
        #expect(set[1].name == "second")
        #expect(set.index(for: Item(id: 1, name: "ignored")) == 0)
    }

    @Test("Update inserts missing element")
    func updateInsertsMissingElement() {
        var set = OrderedSet<String>()

        #expect(set.update(with: "a") == nil)

        #expect(set.count == 1)
        #expect(set[0] == "a")
    }

    @Test("Remove by element deletes value and keeps remaining indices valid")
    func removeByElementKeepsRemainingIndicesValid() throws {
        var set = OrderedSet(["a", "b", "c"])

        let removedElement = set.remove("b")
        let removed = try #require(removedElement)

        #expect(removed == "b")
        #expect(set.count == 2)
        #expect(!set.contains("b"))
        #expect(set[0] == "a")
        #expect(set[1] == "c")
        #expect(set.index(for: "c") == 1)
    }

    @Test("Remove at position returns removed element")
    func removeAtPositionReturnsRemovedElement() {
        var set = OrderedSet(["a", "b"])

        let removed = set.remove(at: 0)

        #expect(removed == "a")
        #expect(set.count == 1)
        #expect(set[0] == "b")
        #expect(set.index(for: "b") == 0)
    }

    @Test("Supports random access collection operations")
    func supportsRandomAccessCollectionOperations() {
        let set = OrderedSet(["a", "b", "c"])

        #expect(set.first == "a")
        #expect(set.last == "c")
        #expect(set[set.index(after: set.startIndex)] == "b")
        #expect(set[set.index(before: set.endIndex)] == "c")
        #expect(set.prefix(2).map { $0 } == ["a", "b"])
    }
}
