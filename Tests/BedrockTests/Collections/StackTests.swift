//
//  StackTests.swift
//  BedrockTests
//
//  Created by weixi on 2026/6/18.
//

import Testing
@testable import Bedrock

@Suite("Stack")
struct StackTests {
    @Test("Initializes as empty")
    func initializesAsEmpty() {
        let stack = Stack<String>()

        #expect(stack.isEmpty)
        #expect(stack.count == 0)
        #expect(stack.top == nil)
    }

    @Test("Initializes from sequence")
    func initializesFromSequence() {
        let stack = Stack([1, 2, 3])

        #expect(stack.count == 3)
        #expect(stack.top == 3)
    }

    @Test("Push appends to the top")
    func pushAppendsToTop() {
        var stack = Stack<String>()

        stack.push("a")
        stack.push("b")

        #expect(stack.count == 2)
        #expect(stack.top == "b")
    }

    @Test("Pop removes from the top")
    func popRemovesFromTop() {
        var stack = Stack(["a", "b", "c"])

        #expect(stack.pop() == "c")
        #expect(stack.pop() == "b")
        #expect(stack.top == "a")
        #expect(stack.count == 1)
    }

    @Test("Pop on empty stack returns nil")
    func popOnEmptyStackReturnsNil() {
        var stack = Stack<String>()

        #expect(stack.pop() == nil)
        #expect(stack.isEmpty)
    }

    @Test("Remove all clears storage")
    func removeAllClearsStorage() {
        var stack = Stack([1, 2, 3])

        stack.removeAll()

        #expect(stack.isEmpty)
        #expect(stack.top == nil)
    }

    @Test("Array literal builds bottom to top")
    func arrayLiteralBuildsBottomToTop() {
        let stack: Stack<Int> = [1, 2, 3]

        #expect(stack.count == 3)
        #expect(stack.top == 3)
    }

    @Test("Equatable compares elements in order")
    func equatableComparesElementsInOrder() {
        #expect(Stack([1, 2, 3]) == Stack([1, 2, 3]))
        #expect(Stack([1, 2, 3]) != Stack([3, 2, 1]))
    }

    @Test("Description lists elements from bottom to top")
    func descriptionListsElementsBottomToTop() {
        #expect(Stack([1, 2, 3]).description == "[1, 2, 3]")
    }
}
