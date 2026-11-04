// Created by weixi on 2026/11/04.
import Foundation
import Testing
import Bedrock

@Suite("JSON values in API responses")
struct APIResponseTests {
    @Test func successDecodesTypedPayloadAndRoundTripsNestedCursor() throws {
        let input = #"""
        {
            "code": 0,
            "data": {
                "items": [{"id": 42, "title": "Hello"}],
                "nextCursor": {
                    "position": {"id": 18446744073709551615, "score": 19.99},
                    "filters": [true, null, "1", {"enabled": false}]
                }
            }
        }
        """#
        let page = try decodeResponse(Page.self, from: input)
        #expect(page.items == [Item(id: 42, title: "Hello")])
        let expectedCursor = JSONValue.object([
            "position": .object([
                "id": .number(JSONNumber(UInt64.max)),
                "score": .number(try JSONNumber(rawValue: "19.99"))
            ]),
            "filters": .array([.bool(true), .null, .string("1"), .object(["enabled": .bool(false)])])
        ])
        #expect(page.nextCursor == expectedCursor)

        // Send the cursor back inside the next request, then inspect its JSON value.
        let request = CursorRequest(cursor: page.nextCursor)
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: encoded)
        #expect(decoded == .object(["cursor": expectedCursor]))
    }

    @Test func businessFailureCapturesResponseWithoutDecodingSuccessPayload() throws {
        // This data deliberately cannot decode as Page.
        let input = #"""
        {
            "code": 409,
            "message": "Cursor expired",
            "data": [null, {"retry": true, "last_id": 9007199254740993}],
            "details": {"reasons": ["expired", "replaced"]}
        }
        """#
        do {
            _ = try decodeResponse(Page.self, from: input)
            Issue.record("Expected business error")
        } catch let error as BusinessError {
            #expect(error.code == 409)
            #expect(error.response == .object([
                "code": .number(JSONNumber(409)),
                "message": .string("Cursor expired"),
                "data": .array([.null, .object([
                    "retry": .bool(true),
                    "last_id": .number(JSONNumber(Int64(9007199254740993)))
                ])]),
                "details": .object(["reasons": .array([.string("expired"), .string("replaced")])])
            ]))
        }
    }

    @Test func malformedSuccessPayloadRetainsNestedErrorPath() throws {
        let input = #"{"code":0,"data":{"items":[{"id":"42","title":"Hello"}],"nextCursor":null}}"#
        do {
            _ = try decodeResponse(Page.self, from: input)
            Issue.record("Expected a type mismatch, not a business error")
        } catch DecodingError.typeMismatch(let type, let context) {
            let expectsInteger = type == Int.self
            #expect(expectsInteger)
            #expect(context.codingPath.map(\.stringValue) == ["data", "items", "Index 0", "id"])
        }
    }
}

private extension APIResponseTests {
    struct Item: Decodable, Equatable {
        let id: Int
        let title: String
    }

    struct Page: Decodable {
        let items: [Item]
        let nextCursor: JSONValue
    }

    struct CursorRequest: Encodable {
        let cursor: JSONValue
    }

    struct BusinessError: Error {
        let code: Int
        let response: JSONValue
    }

    struct APIResponse<Payload: Decodable>: Decodable {
        let payload: Payload

        private enum CodingKeys: String, CodingKey {
            case code, data
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let code = try container.decode(Int.self, forKey: .code)
            guard code == 0 else {
                throw BusinessError(code: code, response: try JSONValue(from: decoder))
            }
            payload = try container.decode(Payload.self, forKey: .data)
        }
    }

    func decodeResponse<Payload: Decodable>(_ type: Payload.Type, from text: String) throws -> Payload {
        try JSONDecoder().decode(APIResponse<Payload>.self, from: Data(text.utf8)).payload
    }
}
