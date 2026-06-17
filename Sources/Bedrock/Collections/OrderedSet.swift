public struct OrderedSet<Element: Hashable> {
    private var elements: [Element]
    private var indices: [Element: Int]

    public init() {
        self.elements = []
        self.indices = [:]
    }

    public init<S: Sequence>(_ elements: S) where S.Element == Element {
        self.init()

        for element in elements {
            insert(element)
        }
    }

    public var count: Int {
        elements.count
    }

    public var isEmpty: Bool {
        elements.isEmpty
    }

    public subscript(position: Int) -> Element {
        elements[position]
    }

    public func contains(_ element: Element) -> Bool {
        indices[element] != nil
    }

    public func index(for element: Element) -> Int? {
        indices[element]
    }

    @discardableResult
    public mutating func insert(_ element: Element) -> Bool {
        guard indices[element] == nil else {
            return false
        }

        indices[element] = elements.count
        elements.append(element)
        return true
    }

    @discardableResult
    public mutating func update(with element: Element) -> Element? {
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

    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        guard let index = indices.removeValue(forKey: element) else {
            return nil
        }

        let oldElement = elements.remove(at: index)
        rebuildIndices(startingAt: index)
        return oldElement
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        let element = elements.remove(at: index)
        indices.removeValue(forKey: element)
        rebuildIndices(startingAt: index)
        return element
    }

    private mutating func rebuildIndices(startingAt startIndex: Int = 0) {
        guard startIndex < elements.count else {
            return
        }

        for index in startIndex..<elements.count {
            indices[elements[index]] = index
        }
    }
}

extension OrderedSet: Sendable where Element: Sendable {}

extension OrderedSet: RandomAccessCollection {
    public var startIndex: Int {
        elements.startIndex
    }

    public var endIndex: Int {
        elements.endIndex
    }

    public func index(after index: Int) -> Int {
        elements.index(after: index)
    }

    public func index(before index: Int) -> Int {
        elements.index(before: index)
    }
}
