// Created by weixi on 2026/11/05.
import Foundation

/// Locates numeric tokens alongside Foundation's validating JSON parser.
/// Only containers on requested paths are indexed; unrelated values are skipped.
/// Access is serialized by JSONNumberSource. This is not a standalone JSON parser.
internal final class JSONNumberLocator {
    private enum Container {
        case object(exact: [String: [Range<Int>]], converted: [String: [Range<Int>]])
        case array([Range<Int>])
        case unavailable
    }

    private let bytes: [UInt8]
    private let snakeCase: Bool
    private var containers: [Int: Container] = [:]

    init(data: Data, snakeCase: Bool) {
        bytes = Array(data)
        self.snakeCase = snakeCase
    }

    func number(at path: [any CodingKey]) -> String? {
        guard path.count <= 128 else { return nil }
        var start = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? 3 : 0
        skipWhitespace(at: &start)
        var region = start..<bytes.count

        for component in path {
            switch container(in: region) {
            case .object(let exact, let converted):
                // A coding path does not identify model vs. dictionary parents.
                // Dictionaries bypass key conversion. Both interpretations must
                // point to the same single source member before claiming an origin.
                var matches = exact[component.stringValue] ?? []
                for candidate in converted[component.stringValue] ?? [] where !matches.contains(candidate) {
                    matches.append(candidate)
                }
                guard matches.count == 1 else { return nil }
                region = matches[0]
            case .array(let elements):
                guard let index = component.intValue, elements.indices.contains(index) else { return nil }
                region = elements[index]
            case .unavailable: return nil
            }
        }

        guard region.lowerBound < bytes.count,
              Self.isNumberStart(bytes[region.lowerBound]),
              let end = endOfValue(from: region.lowerBound), end <= region.upperBound else { return nil }
        let text = String(decoding: bytes[region.lowerBound..<end], as: UTF8.self)
        return JSONNumberText(text) == nil ? nil : text
    }
}

private extension JSONNumberLocator {
    private func container(in region: Range<Int>) -> Container {
        if let cached = containers[region.lowerBound] { return cached }
        let result = indexContainer(in: region)
        containers[region.lowerBound] = result
        return result
    }

    private func indexContainer(in region: Range<Int>) -> Container {
        var position = region.lowerBound
        guard position < bytes.count else { return .unavailable }
        let isObject = bytes[position] == UInt8(ascii: "{")
        guard isObject || bytes[position] == UInt8(ascii: "[") else { return .unavailable }
        let closingByte = isObject ? UInt8(ascii: "}") : UInt8(ascii: "]")
        position += 1
        skipWhitespace(at: &position)

        var exact: [String: [Range<Int>]] = [:]
        var converted: [String: [Range<Int>]] = [:]
        var elements: [Range<Int>] = []
        if position < region.upperBound, bytes[position] == closingByte {
            return isObject ? .object(exact: exact, converted: converted) : .array(elements)
        }

        while position < region.upperBound {
            var memberKey: String?
            if isObject {
                guard let end = endOfString(from: position), end <= region.upperBound,
                      let key = try? JSONDecoder().decode(String.self, from: Data(bytes[position..<end])) else { return .unavailable }
                memberKey = key
                position = end
                skipWhitespace(at: &position)
                guard position < region.upperBound, bytes[position] == UInt8(ascii: ":") else { return .unavailable }
                position += 1
                skipWhitespace(at: &position)
            }

            guard let end = endOfValue(from: position), end <= region.upperBound else { return .unavailable }
            let childRegion = position..<end
            if let memberKey {
                exact[memberKey, default: []].append(childRegion)
                if snakeCase { converted[Self.convertSnakeCase(memberKey), default: []].append(childRegion) }
            } else {
                elements.append(childRegion)
            }
            position = end
            skipWhitespace(at: &position)
            guard position < region.upperBound else { return .unavailable }
            if bytes[position] == closingByte {
                return isObject ? .object(exact: exact, converted: converted) : .array(elements)
            }
            guard bytes[position] == UInt8(ascii: ",") else { return .unavailable }
            position += 1
            skipWhitespace(at: &position)
        }
        return .unavailable
    }

    func skipWhitespace(at position: inout Int) {
        while position < bytes.count, Self.isWhitespace(bytes[position]) { position += 1 }
    }

    func endOfString(from start: Int) -> Int? {
        guard start < bytes.count, bytes[start] == UInt8(ascii: "\"") else { return nil }
        var position = start + 1
        while position < bytes.count {
            switch bytes[position] {
            case UInt8(ascii: "\""): return position + 1
            case UInt8(ascii: "\\"): position += 2
            default: position += 1
            }
        }
        return nil
    }

    func endOfValue(from start: Int) -> Int? {
        guard start < bytes.count else { return nil }
        if bytes[start] == UInt8(ascii: "\"") { return endOfString(from: start) }
        if bytes[start] == UInt8(ascii: "{") || bytes[start] == UInt8(ascii: "[") {
            var depth = 1
            var position = start + 1
            while position < bytes.count {
                switch bytes[position] {
                case UInt8(ascii: "\""):
                    guard let end = endOfString(from: position) else { return nil }
                    position = end
                case UInt8(ascii: "{"), UInt8(ascii: "["):
                    depth += 1
                    position += 1
                case UInt8(ascii: "}"), UInt8(ascii: "]"):
                    depth -= 1
                    position += 1
                    if depth == 0 { return position }
                default: position += 1
                }
            }
            return nil
        }
        var position = start
        while position < bytes.count, !Self.isValueTerminator(bytes[position]) { position += 1 }
        return position > start ? position : nil
    }

    static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 9 || byte == 10 || byte == 13 || byte == UInt8(ascii: " ")
    }

    static func isValueTerminator(_ byte: UInt8) -> Bool {
        isWhitespace(byte) || byte == UInt8(ascii: ",") || byte == UInt8(ascii: "]") || byte == UInt8(ascii: "}")
    }

    static func isNumberStart(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "-") || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
    }

    static func convertSnakeCase(_ key: String) -> String {
        guard let first = key.firstIndex(where: { $0 != "_" }),
              let last = key.lastIndex(where: { $0 != "_" }) else { return key }
        let words = key[first...last].split(separator: "_")
        let middle = words.count == 1 ? String(key[first...last])
            : words[0].lowercased() + words.dropFirst().map { $0.capitalized }.joined()
        return String(key[..<first]) + middle + String(key[key.index(after: last)...])
    }
}
