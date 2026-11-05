// Created by weixi on 2026/11/05.
import Foundation
import Testing
import Bedrock

@Suite("JSON hashing")
struct JSONHashableTests {
    @Test func numericSpellingsDeduplicateByValue() throws {
        let values = try ["1", "1.0", "1e0", "0", "-0.0", "2", "2.00"].map { try JSONNumber(rawValue: $0) }
        #expect(Set(values).count == 3)
        for left in values {
            for right in values where left == right {
                #expect(left.hashValue == right.hashValue)
                #expect(Set([left]).contains(right))
            }
        }
        #expect(Set([JSONNumber(1), try JSONNumber(1.0), try JSONNumber(Decimal(1))]).count == 1)
    }

    @Test func capturedPrecisionDoesNotChangeHashing() throws {
        let input = Data("0.1234567890123456789012345678901234567890123456789".utf8)
        let decoder = JSONDecoder()
        let captured = try decoder.decodePreservingNumberText(JSONNumber.self, from: input)
        let native = try decoder.decode(JSONNumber.self, from: input)
        #expect(captured.originalText != nil)
        #expect(native.originalText == nil)
        #expect(captured == native)
        #expect(captured.hashValue == native.hashValue)
        #expect(Set([captured, native]).count == 1)
        #expect([captured: "found"][native] == "found")
    }

    @Test func textOnlyNumbersKeepExactSpellingSemantics() throws {
        let first = try JSONNumber(rawValue: "1e400")
        let same = try JSONNumber(rawValue: "1e400")
        let different = try JSONNumber(rawValue: "10e399")
        let precise = try JSONNumber(rawValue: "1.00000000000000000000000000000000000000000001")
        #expect(first.hashValue == same.hashValue)
        #expect(Set([first, same, different, precise, JSONNumber(1)]).count == 4)
        #expect([first: "opaque"][same] == "opaque")
    }

    @Test func objectOrderAndUnicodeEquivalenceDoNotAffectHashing() throws {
        let first = try decode(#"{"a":1,"b":[null,true,"é"]}"#)
        let second = try decode(#"{"b":[null,true,"e\u0301"],"a":1.0}"#)
        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect([first: "value"][second] == "value")
        let keyA = try decode(#"{"é":1}"#)
        let keyB = try decode(#"{"e\u0301":1e0}"#)
        #expect(Set([keyA, keyB]).count == 1)
    }

    @Test func kindsArrayOrderAndLargeIntegersRemainDistinctKeys() throws {
        let values = try ["null", "true", "1", "\"1\"", "[1,2]", "[2,1]", "{}", "{\"a\":null}", "9007199254740992", "9007199254740993"].map(decode)
        #expect(Set(values).count == values.count)
        for (index, value) in values.enumerated() {
            #expect(Dictionary(uniqueKeysWithValues: values.enumerated().map { ($0.element, $0.offset) })[value] == index)
        }
    }

    @Test func pagerSynthesizesHashableForRequestDeduplication() throws {
        struct Pager: Codable, Hashable {
            let category: String
            let cursor: JSONValue
        }
        let first = Pager(category: "feed", cursor: try decode(#"{"id":42,"parts":[1,2]}"#))
        let repeated = Pager(category: "feed", cursor: try decode(#"{"parts":[1.0,2e0],"id":42.0}"#))
        let anotherCategory = Pager(category: "search", cursor: first.cursor)
        var requests: Set<Pager> = []
        #expect(requests.insert(first).inserted)
        #expect(!requests.insert(repeated).inserted)
        #expect(requests.insert(anotherCategory).inserted)
        #expect(requests.count == 2)
        let roundTripped = try JSONDecoder().decode(Pager.self, from: JSONEncoder().encode(first))
        #expect(requests.contains(roundTripped))
    }

    @Test func generatedNumericRoundTripsRemainHashCompatible() throws {
        var state: UInt64 = 0x729DAE31942B17C5
        for index in 0..<200 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let decimal = try JSONNumber(rawValue: "\(state % 1000000000000000000 + 1)e\(index % 81 - 40)")
            for number in [JSONNumber(state), JSONNumber(Int64(bitPattern: state)), decimal] {
                let encoded = try JSONEncoder().encode(number)
                let decoded = try JSONDecoder().decode(JSONNumber.self, from: encoded)
                #expect(number == decoded)
                #expect(number.hashValue == decoded.hashValue)
                #expect(Set([number]).contains(decoded))
            }
        }
    }

    private func decode(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }
}
