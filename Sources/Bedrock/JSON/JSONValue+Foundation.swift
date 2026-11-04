// Created by weixi on 2026/11/04.
import Foundation
import CoreFoundation

extension JSONValue {
    public enum ConversionError: Error, Equatable, Sendable {
        case unsupportedValue(path: [String])
        case invalidNumber(path: [String])
    }

    /// Validates a JSONSerialization-style value tree. Does not coerce Date, URL,
    /// Data, or other custom objects. Any precision already lost upstream cannot
    /// be recovered, and NSNumber inputs do not carry original JSON text.
    public init(validating value: Any) throws {
        self = try Self.convert(value, path: [])
    }

    private static func convert(_ value: Any, path: [String]) throws -> Self {
        if value is NSNull { return .null }
        if let number = value as? NSNumber {
            return try convertNumber(number, path: path)
        }
        if let string = value as? String { return .string(string) }
        if let array = value as? [Any] {
            return .array(try array.enumerated().map { index, element in
                try convert(element, path: path + [String(index)])
            })
        }
        if let object = value as? [String: Any] {
            var values: [String: JSONValue] = [:]
            values.reserveCapacity(object.count)
            for (key, element) in object {
                values[key] = try convert(element, path: path + [key])
            }
            return .object(values)
        }
        throw ConversionError.unsupportedValue(path: path)
    }

    private static func convertNumber(_ number: NSNumber, path: [String]) throws -> Self {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return .bool(number.boolValue)
        }
        do {
            if let decimal = number as? NSDecimalNumber {
                return .number(try JSONNumber(decimal.decimalValue))
            }
            // NSNumber's Objective-C type encoding distinguishes signed, unsigned,
            // and floating-point storage. Boolean identity was handled above.
            switch String(cString: number.objCType) {
            case "c", "s", "i", "l", "q": return .number(JSONNumber(number.int64Value))
            case "C", "S", "I", "L", "Q": return .number(JSONNumber(number.uint64Value))
            case "f", "d": return .number(try JSONNumber(number.doubleValue))
            default: throw ConversionError.invalidNumber(path: path)
            }
        } catch {
            throw ConversionError.invalidNumber(path: path)
        }
    }
}
