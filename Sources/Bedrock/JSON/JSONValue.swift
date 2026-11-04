// Created by weixi on 2026/11/04.
import Foundation

/// A JSON value with structural equality and Foundation Codable interoperability.
///
/// Objects ignore member order; arrays preserve order. Strings and object keys use
/// Swift String equality. Number spellings, whitespace, and escape sequences are
/// not preserved by system Codable. See JSONNumber for the explicit text escape hatch.
public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case string(String)
    case number(JSONNumber)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if var array = try? decoder.unkeyedContainer() {
            var values: [JSONValue] = []
            while !array.isAtEnd { values.append(try array.decode(JSONValue.self)) }
            self = .array(values)
        } else if (try? decoder.container(keyedBy: ObjectKey.self)) != nil {
            // Decoding a dictionary through the generic container preserves Foundation's
            // exemption from model key-conversion strategies. Propagate child errors.
            self = .object(try container.decode([String: JSONValue].self))
        } else {
            self = .number(try container.decode(JSONNumber.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    private struct ObjectKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
}
