// Created by weixi on 2026/11/05.
import Foundation
import Testing
@testable import Bedrock

@Suite("JSON number original text")
struct JSONOriginalTextTests {
    private func decode<T: Decodable>(_ type: T.Type, _ text: String, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        try decoder.decodePreservingNumberText(type, from: Data(text.utf8))
    }

    @Test func nestedPagerKeepsNumberSpellings() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decode(Response.self, #"{"data":[{"items":[{"id":42}],"next_cursor":{"id":18446744073709551615,"score":19.9900,"parts":[1e0,-0.0]}}]}"#, using: decoder)
        #expect(response.data[0].items[0].id == 42)
        let cursor = response.data[0].nextCursor
        #expect(try number(field(cursor, "id")).originalText == "18446744073709551615")
        #expect(try number(field(cursor, "score")).originalText == "19.9900")
        guard case .array(let parts) = try field(cursor, "parts") else { Issue.record("Expected array"); return }
        #expect(try parts.map { try number($0).originalText } == ["1e0", "-0.0"])
    }

    @Test func originalPrecisionDoesNotChangeNumericBehavior() throws {
        let text = "0.1234567890123456789012345678901234567890123456789"
        let preserved = try decode(JSONNumber.self, text)
        let native = try JSONDecoder().decode(JSONNumber.self, from: Data(text.utf8))
        #expect(preserved.originalText == text)
        #expect(preserved == native)
        #expect(preserved.decimalValue == native.decimalValue)
        #expect(preserved.doubleValue == native.doubleValue)
        #expect(preserved.int64Value == native.int64Value)
        #expect(try JSONEncoder().encode(preserved) == JSONEncoder().encode(native))
    }

    @Test(arguments: ["1e400", "1e-400", "1e" + String(repeating: "9", count: 1000)])
    func unsupportedNumbersKeepText(_ text: String) throws {
        let value = try decode(JSONNumber.self, text)
        #expect(value.originalText == text)
        #expect(!value.isCodableNumber)
        #expect(throws: EncodingError.self) { try JSONEncoder().encode(value) }
    }
    @Test func collisionsDoNotAttachAnotherFieldsText() throws {
        struct Model: Decodable { let someKey: JSONNumber }
        for text in [#"{"some_key":1.00,"someKey":2.00}"#, #"{"someKey":2.00,"some_key":1.00}"#] {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let model = try decode(Model.self, text, using: decoder)
            let native = try decoder.decode(Model.self, from: Data(text.utf8))
            let dictionary = try decode([String: JSONNumber].self, text, using: decoder)
            #expect(model.someKey == native.someKey)
            #expect(model.someKey.originalText == nil)
            #expect(dictionary["someKey"]?.int64Value == 2)
            #expect(dictionary["someKey"]?.originalText == nil)
            #expect(dictionary["some_key"]?.originalText == "1.00")
        }
    }

    @Test(arguments: [#"{"n":1.00,"n":2.00}"#, #"{"é":1.00,"e\u0301":2.00}"#])
    func duplicateKeysDeclineOriginalText(_ text: String) throws {
        let values = try decode([String: JSONNumber].self, text)
        #expect(values.values.allSatisfy { $0.originalText == nil })
    }

    @Test func specialKeysAndSkippedStringsKeepTheirBoundaries() throws {
        let text = #"{"ignored":{"text":"brackets } ] { [ and escaped quote \" and slash \\","nested":[1,2,3]},"cursor":{"a/b":{"0":1.2300},"escaped\"key":2e0,"\uD83D\uDE00":-0.0}}"#
        struct Root: Decodable { let cursor: JSONValue }
        let result = try decode(Root.self, text)
        #expect(try number(field(field(result.cursor, "a/b"), "0")).originalText == "1.2300")
        #expect(try number(field(result.cursor, "escaped\"key")).originalText == "2e0")
        #expect(try number(field(result.cursor, "😀")).originalText == "-0.0")
    }

    @Test func wrapperAndExplicitCodingKeysPropagateOriginals() throws {
        struct Wrapped: Decodable {
            @WrappedNumber var cursor: JSONNumber
            enum CodingKeys: String, CodingKey { case cursor = "next_cursor" }
        }
        let model = try decode(Wrapped.self, #"{"next_cursor":19.9900}"#)
        #expect(model.cursor.originalText == "19.9900")
    }

    @Test func businessErrorCanCaptureAnUnsupportedNumber() throws {
        struct BusinessError: Error { let body: JSONValue }
        struct Response: Decodable {
            init(from decoder: any Decoder) throws {
                let values = try decoder.container(keyedBy: Key.self)
                if try values.decode(Int.self, forKey: .code) != 0 {
                    throw BusinessError(body: try JSONValue(from: decoder))
                }
            }
            enum Key: String, CodingKey { case code }
        }
        do {
            _ = try decode(Response.self, #"{"code":409,"data":{"huge":1e400}}"#)
            Issue.record("Expected business error")
        } catch let error as BusinessError {
            #expect(try number(field(field(error.body, "data"), "huge")).originalText == "1e400")
        }
    }

    @Test func nativeAndUnsupportedPathsKeepNormalDecoding() throws {
        let decoder = JSONDecoder()
        let plain = try decoder.decode(JSONNumber.self, from: Data("1.2300".utf8))
        #expect(plain.originalText == nil)
        let utf16 = try decoder.decodePreservingNumberText(JSONNumber.self, from: #require("1.2300".data(using: .utf16LittleEndian)))
        #expect(utf16.originalText == nil)
        #expect(utf16 == plain)
        let bom = Data([0xEF, 0xBB, 0xBF]) + Data("1.2300".utf8)
        #expect(try decoder.decodePreservingNumberText(JSONNumber.self, from: bom).originalText == "1.2300")

        struct Model: Decodable { let value: JSONNumber }
        decoder.keyDecodingStrategy = .custom { _ in TestKey("value") }
        let custom = try decode(Model.self, #"{"remote_key":1.2300}"#, using: decoder)
        #expect(custom.value.originalText == nil)
        #expect(custom.value == plain)
    }

    @Test func decoderStrategiesAndUserInfoArePreservedWithoutMutation() throws {
        let marker = CodingUserInfoKey(rawValue: "caller-marker")!
        let decoder = JSONDecoder()
        decoder.userInfo[marker] = "unchanged"
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.dataDecodingStrategy = .base64
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NAN")
        struct Model: Decodable {
            let date: Date
            let blob: Data
            let infinity: Double
            let value: JSONNumber
        }
        let value = try decode(Model.self, #"{"date":0,"blob":"aGk=","infinity":"INF","value":1.00}"#, using: decoder)
        #expect(value.date == Date(timeIntervalSince1970: 0))
        #expect(value.blob == Data("hi".utf8))
        #expect(value.infinity == .infinity)
        #expect(value.value.originalText == "1.00")
        #expect(decoder.userInfo.count == 1)
        #expect(decoder.userInfo[marker] as? String == "unchanged")
        #expect(throws: DecodingError.self) { try decode(JSONNumber.self, "\"not a number\"", using: decoder) }
        #expect(decoder.userInfo.count == 1)
    }

    @Test func sharedConfiguredDecoderHasIsolatedConcurrentCalls() async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        struct Model: Decodable { let nextCursor: JSONNumber }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    let text = "\(index).000"
                    let input = Data("{\"next_cursor\":\(text)}".utf8)
                    let model = try decoder.decodePreservingNumberText(Model.self, from: input)
                    #expect(model.nextCursor.originalText == text)
                }
            }
            try await group.waitForAll()
        }
        #expect(decoder.userInfo.isEmpty)
    }

    @Test func generatedNestedPagerTokensRemainExact() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        for index in 0..<200 {
            let token = "\(index + 1).00123456789012345678901234567890123456789e\(index - 100)"
            let input = "{\"data\":[{\"items\":[{\"id\":\(index)}],\"next_cursor\":{\"value\":\(token)}}]}"
            let result = try decode(Response.self, input, using: decoder)
            #expect(result.data[0].items[0].id == index)
            #expect(try number(field(result.data[0].nextCursor, "value")).originalText == token)
        }
    }

    @Test func snakeKeysMatchFoundationAcrossSpellings() throws {
        struct Model: Decodable {
            let values: [JSONNumber]
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: TestKey.self)
                values = try container.allKeys.map { try container.decode(JSONNumber.self, forKey: $0) }
            }
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        for key in ["", "_", "___", "some_key", "someKey", "URL_value", "_URL__value_", "é_COLE", "straße_ID", "你好_世界", "foo_İD", "foo_ß", "__a___b__"] {
            let keyData = try JSONEncoder().encode(key)
            let input = "{" + String(decoding: keyData, as: UTF8.self) + ":1.2300}"
            let model = try decode(Model.self, input, using: decoder)
            #expect(model.values.count == 1)
            #expect(model.values.first?.originalText == "1.2300")
        }
    }

    @Test func encoderErrorsRetainNestedPath() throws {
        let value = try decode(JSONValue.self, #"{"cursor":[1e400]}"#)
        do {
            _ = try JSONEncoder().encode(value)
            Issue.record("Expected unsupported-number error")
        } catch EncodingError.invalidValue(_, let context) {
            #expect(context.codingPath.map(\.stringValue) == ["cursor", "Index 0"])
        }
    }

    @Test(arguments: ["01", "+1", "1.", "1e", "NaN", "[1 2]", "{\"a\":}", "\"\\x\""])
    func malformedJSONRemainsRejected(_ text: String) {
        #expect(throws: DecodingError.self) { try decode(JSONValue.self, text) }
    }

    @Test func nativeTrailingNULToleranceDoesNotInventOriginalText() throws {
        let input = Data("1\u{0000}".utf8)
        let decoder = JSONDecoder()
        // Foundation versions differ here; preserve its decision, not our own policy.
        do {
            let expected = try decoder.decode(JSONNumber.self, from: input)
            let actual = try decoder.decodePreservingNumberText(JSONNumber.self, from: input)
            #expect(actual == expected)
            #expect(actual.originalText == nil)
        } catch {
            #expect(throws: DecodingError.self) { try decoder.decodePreservingNumberText(JSONNumber.self, from: input) }
        }
    }

    @Test func subclassOverridesAreNotBypassed() throws {
        final class ReplacingDecoder: JSONDecoder, @unchecked Sendable {
            override func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
                try super.decode(type, from: Data("2".utf8))
            }
        }
        let value = try ReplacingDecoder().decodePreservingNumberText(JSONNumber.self, from: Data("1.00".utf8))
        #expect(value.int64Value == 2)
        #expect(value.originalText == nil)
    }

    @Test func deepPathsFallBackWithoutAffectingNumericDecoding() throws {
        let text = String(repeating: "[", count: 140) + "1.2300" + String(repeating: "]", count: 140)
        var value = try decode(JSONValue.self, text)
        for _ in 0..<140 {
            guard case .array(let elements) = value else { Issue.record("Expected array"); return }
            value = try #require(elements.first)
        }
        #expect(try number(value).originalText == nil)
        #expect(try number(value).decimalValue == Decimal(string: "1.23"))
    }

    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    @Test func nonstandardJSONOptionsUseTheNativePath() throws {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let values = try decode([String: JSONNumber].self, "{value: 1.23}", using: decoder)
        #expect(values["value"]?.originalText == nil)
        #expect(values["value"]?.decimalValue == Decimal(string: "1.23"))
        decoder.allowsJSON5 = false
        decoder.assumesTopLevelDictionary = true
        let unwrapped = try decode([String: JSONNumber].self, #""value":1.23"#, using: decoder)
        #expect(unwrapped["value"]?.originalText == nil)
    }

}

private extension JSONOriginalTextTests {
    @propertyWrapper struct WrappedNumber: Decodable {
        let wrappedValue: JSONNumber
        init(from decoder: any Decoder) throws { wrappedValue = try JSONNumber(from: decoder) }
    }
    struct TestKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.init(stringValue) }
        init?(intValue: Int) { return nil }
    }
    struct Item: Decodable { let id: Int }
    struct Pager: Decodable { let items: [Item]; let nextCursor: JSONValue }
    struct Response: Decodable { let data: [Pager] }

    func field(_ value: JSONValue, _ key: String) throws -> JSONValue {
        guard case .object(let fields) = value else { throw SampleError.expectedObject }
        return try #require(fields[key])
    }
    func number(_ value: JSONValue) throws -> JSONNumber {
        guard case .number(let number) = value else { throw SampleError.expectedNumber }
        return number
    }
    enum SampleError: Error { case expectedObject, expectedNumber }
}
