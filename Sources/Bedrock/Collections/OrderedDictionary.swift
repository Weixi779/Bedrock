public struct OrderedDictionary<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)

    private var elements: [Element]
    private var indices: [Key: Int]

    public init() {
        self.elements = []
        self.indices = [:]
    }

    public var count: Int {
        elements.count
    }

    public var isEmpty: Bool {
        elements.isEmpty
    }

    public subscript(key: Key) -> Value? {
        get {
            guard let index = indices[key] else {
                return nil
            }

            return elements[index].value
        }
        set {
            guard let newValue else {
                removeValue(forKey: key)
                return
            }

            updateValue(newValue, forKey: key)
        }
    }

    public subscript(position: Int) -> Element {
        elements[position]
    }

    public func index(forKey key: Key) -> Int? {
        indices[key]
    }

    public func containsKey(_ key: Key) -> Bool {
        indices[key] != nil
    }

    @discardableResult
    public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        if let index = indices[key] {
            let oldValue = elements[index].value
            elements[index].value = value
            return oldValue
        }

        indices[key] = elements.count
        elements.append((key: key, value: value))
        return nil
    }

    public mutating func insert(_ value: Value, forKey key: Key, at index: Int) {
        precondition(indices[key] == nil, "Duplicate key: \(key)")
        precondition(index >= 0 && index <= elements.count, "Index out of range")

        elements.insert((key: key, value: value), at: index)
        rebuildIndices(startingAt: index)
    }

    @discardableResult
    public mutating func removeValue(forKey key: Key) -> Value? {
        guard let index = indices.removeValue(forKey: key) else {
            return nil
        }

        let element = elements.remove(at: index)
        rebuildIndices(startingAt: index)
        return element.value
    }

    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        let element = elements.remove(at: index)
        indices.removeValue(forKey: element.key)
        rebuildIndices(startingAt: index)
        return element
    }

    private mutating func rebuildIndices(startingAt startIndex: Int = 0) {
        guard startIndex < elements.count else {
            return
        }

        for index in startIndex..<elements.count {
            indices[elements[index].key] = index
        }
    }
}

extension OrderedDictionary: Sendable where Key: Sendable, Value: Sendable {}
