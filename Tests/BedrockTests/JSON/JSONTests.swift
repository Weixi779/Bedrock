// Created by weixi on 2026/11/04.
import Foundation
import Testing
@testable import Bedrock

@Suite("JSON values")
struct JSONTests {
    private func decode(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    @Test(arguments: ["-9223372036854775808", "9223372036854775807", "18446744073709551615", "9007199254740993", "19.99", "1.0000000000000001", "0.123456789012345678", "1e200", "1e-200"])
    func roundTrip(_ text: String) throws {
        let value = try decode(text)
        #expect(try decode(String(decoding: JSONEncoder().encode(value), as: UTF8.self)) == value)
        #expect(value == .number(try JSONNumber(rawValue: text)))
    }

    @Test func equality() throws {
        #expect(try decode("1") == decode("1.0"))
        #expect(try decode("1") == decode("1e0"))
        #expect(try decode("-0.0") == decode("0"))
        #expect(try decode("true") != decode("1"))
        #expect(try decode("\"1\"") != decode("1"))
        #expect(try decode("0.3") != decode("0.30000000000000004"))
        #expect(try decode("9007199254740992") != decode("9007199254740993"))
        #expect(try decode("{}") != decode("{\"a\":null}"))
        #expect(try decode("[1,2]") != decode("[2,1]"))
        #expect(try decode("{\"b\":2,\"a\":1}") == decode("{\"a\":1.0,\"b\":2}"))
    }

    @Test func numberConstructionAndReading() throws {
        let max = JSONNumber(UInt64.max)
        #expect(max.uint64Value == UInt64.max)
        #expect(max.int64Value == nil)
        #expect(JSONNumber(Int64.min).int64Value == Int64.min)
        #expect(try JSONNumber(rawValue: "1.0").int64Value == 1)
        #expect(try JSONNumber(rawValue: "1.5").int64Value == nil)
        #expect(try JSONNumber(19.99) == JSONNumber(rawValue: "19.99"))
        #expect(throws: (any Error).self) { try JSONNumber(Double.nan) }
        #expect(throws: (any Error).self) { try JSONNumber(Double.infinity) }
        #expect(throws: (any Error).self) { try JSONNumber(Decimal.nan) }
    }

    @Test(arguments: ["", " 1", "1 ", "+1", "01", "-01", ".1", "1.", "1e", "1e+", "NaN", "Infinity", "١", "1\n", "1,2"])
    func invalidNumber(_ text: String) {
        #expect(throws: (any Error).self) { try JSONNumber(rawValue: text) }
    }

    @Test(arguments: ["1e400", "1e-400", "1e9999999999999999999999", "1.00000000000000000000000000000000000000000001"])
    func textOnlyEscapeHatch(_ text: String) throws {
        let number = try JSONNumber(rawValue: text)
        #expect(number.originalText == text)
        #expect(number.decimalValue == nil)
        #expect(number == (try JSONNumber(rawValue: text)))
        #expect(throws: EncodingError.self) { try JSONEncoder().encode(number) }
    }

    @Test func originalTextIsNotInvented() throws {
        let a = try JSONNumber(rawValue: "1.00")
        let b = try JSONDecoder().decode(JSONNumber.self, from: Data("1.00".utf8))
        #expect(a.originalText == "1.00")
        #expect(b.originalText == nil)
        #expect(a == b)
        #expect(JSONNumber(1).originalText == nil)
    }

    @Test func cursorInsideModelAndKeyStrategies() throws {
        struct Page: Codable, Equatable { let nextCursor: JSONValue }
        let input = #"{"next_cursor":{"some_key":18446744073709551615,"someKey":1.0000000000000001,"items":[null,true,"x",[],{}]}}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(Page.self, from: Data(input.utf8))
        guard case .object(let object) = page.nextCursor else { Issue.record("Expected object"); return }
        #expect(object["some_key"] == .number(JSONNumber(UInt64.max)))
        #expect(object["someKey"] == .number(try JSONNumber(rawValue: "1.0000000000000001")))
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        #expect(try decoder.decode(Page.self, from: encoder.encode(page)) == page)
    }

    @Test func unsupportedNumberRetainsErrorPath() {
        do {
            _ = try decode(#"{"nested":[1e400]}"#)
            Issue.record("Expected rejection")
        } catch DecodingError.dataCorrupted(let context) {
            #expect(context.codingPath.map(\.stringValue) == ["nested", "Index 0"])
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func foundationValuesAreValidatedWithoutBooleanCoercion() throws {
        let source: [String: Any] = [
            "one": NSNumber(value: 1), "zero": NSNumber(value: 0),
            "bool": NSNumber(value: true), "max": NSNumber(value: UInt64.max),
            "decimal": NSDecimalNumber(string: "19.99"),
            "nested": [NSNull(), "value"]
        ]
        let value = try JSONValue(validating: source)
        #expect(try value == decode(#"{"one":1,"zero":0,"bool":true,"max":18446744073709551615,"decimal":19.99,"nested":[null,"value"]}"#))
        #expect(try JSONValue(validating: ["bool": true, "number": 1] as [String: Any]) == decode(#"{"bool":true,"number":1}"#))
        #expect(throws: (any Error).self) { try JSONValue(validating: ["bad": Date()]) }
        #expect(throws: (any Error).self) { try JSONValue(validating: NSNumber(value: Double.infinity)) }
        #expect(throws: (any Error).self) { try JSONValue(validating: NSDecimalNumber.notANumber) }
    }

    @Test func generatedIntegerAndDecimalRoundTrips() throws {
        var state: UInt64 = 0x729DAE31942B17C5
        for index in 0..<1000 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            for number in [JSONNumber(state), JSONNumber(Int64(bitPattern: state))] {
                let encoded = try JSONEncoder().encode(number)
                #expect(String(decoding: encoded, as: UTF8.self) == number.description)
                #expect(try JSONDecoder().decode(JSONNumber.self, from: encoded) == number)
            }
            let text = "\(state % 1000000000000000000 + 1)e\(index % 81 - 40)"
            let number = try JSONNumber(rawValue: text)
            #expect(number.isCodableNumber)
            #expect(try JSONDecoder().decode(JSONNumber.self, from: JSONEncoder().encode(number)) == number)
        }
    }

    @Test func equalityIsAnEquivalenceRelation() throws {
        let inputs = ["0", "-0.0", "1", "1.00", "1e0", "0.3", "0.30000000000000004", "9007199254740992", "9007199254740993", "1e128", "10e127", "1e200", "10e199", "1e400", "10e399", "1.00000000000000000000000000000000000000000001"]
        var values = try inputs.map { try JSONNumber(rawValue: $0) }
        for value in values where value.isCodableNumber {
            values.append(try JSONDecoder().decode(JSONNumber.self, from: JSONEncoder().encode(value)))
        }
        for a in values {
            #expect(a == a)
            for b in values {
                #expect((a == b) == (b == a))
                for c in values where a == b && b == c { #expect(a == c) }
            }
        }
    }

    @Test func numericReadBoundaries() throws {
        #expect(try JSONNumber(rawValue: "9223372036854775808").int64Value == nil)
        #expect(try JSONNumber(rawValue: "18446744073709551616").uint64Value == nil)
        #expect(try JSONNumber(rawValue: "-1").uint64Value == nil)
        #expect(try JSONNumber(rawValue: "1e2").int64Value == 100)
        #expect(try JSONNumber(rawValue: "0e9999999999999999999999").int64Value == 0)
        #expect(try JSONNumber(rawValue: "1e400").doubleValue == nil)
        #expect(try JSONNumber(rawValue: "1e-400").doubleValue == nil)
        #expect(try JSONNumber(rawValue: "9007199254740993").doubleValue == 9007199254740992)
        for value in [Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude, -Double.zero] {
            let number = try JSONNumber(value)
            #expect(number.doubleValue == value)
            #expect(try JSONDecoder().decode(JSONNumber.self, from: JSONEncoder().encode(number)) == number)
        }
    }

    @Test func syntaxAndOpaqueTextRemainBounded() throws {
        let text = "1e" + String(repeating: "9", count: 10000)
        let number = try JSONNumber(rawValue: text)
        #expect(number.originalText == text)
        #expect(!number.isCodableNumber)
        #expect(number.int64Value == nil)
        #expect(try JSONNumber(rawValue: "1e400") != JSONNumber(rawValue: "10e399"))
    }

    @Test func integralDoubleConstructionUsesItsActualInteger() throws {
        for value in [Double(Int64.min), Double(Int64.max).nextDown, Double(UInt64.max).nextDown] {
            if let integer = Int64(exactly: value) {
                #expect(try JSONNumber(value) == JSONNumber(integer))
                #expect(try JSONNumber(value).int64Value == integer)
            } else if let integer = UInt64(exactly: value) {
                #expect(try JSONNumber(value) == JSONNumber(integer))
                #expect(try JSONNumber(value).uint64Value == integer)
            } else { Issue.record("Expected exact integer sample") }
        }
    }

    @Test func specialValuesFailAtTheirNestedLocation() throws {
        let value = JSONValue.object(["cursor": .array([.number(try JSONNumber(rawValue: "1e400"))])])
        do {
            _ = try JSONEncoder().encode(value)
            Issue.record("Expected encoding error")
        } catch EncodingError.invalidValue(_, let context) {
            #expect(context.codingPath.map(\.stringValue) == ["cursor", "Index 0"])
        }
        #expect(throws: JSONValue.ConversionError.unsupportedValue(path: ["cursor", "0"])) {
            try JSONValue(validating: ["cursor": [Date()]])
        }
    }
}
