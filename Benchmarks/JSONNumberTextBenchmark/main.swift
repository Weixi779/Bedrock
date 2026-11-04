// Created by weixi on 2026/11/05.
import Foundation
import Bedrock

private struct Row: Decodable { let id: Int; let title: String; let summary: String }
private struct Page: Decodable { let items: [Row]; let nextCursor: JSONValue }
private struct Response: Decodable { let code: Int; let data: Page }
private enum Mode: CaseIterable { case native, preserving }

@inline(never)
private func decode<T: Decodable>(_ type: T.Type, data: Data, mode: Mode) throws -> T {
    let decoder = JSONDecoder()
    switch mode {
    case .native: return try decoder.decode(type, from: data)
    case .preserving: return try decoder.decodePreservingNumberText(type, from: data)
    }
}

private func pageData(rows: Int, numericCursor: Bool) -> Data {
    let items = (0..<rows).map {
        "{\"id\":\($0),\"title\":\"Item \($0)\",\"summary\":\"A typical item with a short description and ordinary typed fields.\"}"
    }.joined(separator: ",")
    let cursor = numericCursor
        ? #"{"id":9007199254740993,"score":19.9900,"offset":20}"#
        : #"{"token":"next-page-token","hasMore":true}"#
    return Data("{\"code\":0,\"data\":{\"items\":[\(items)],\"nextCursor\":\(cursor)}}".utf8)
}

private func measure<T: Decodable>(
    _ type: T.Type, name: String, data: Data, iterations: Int, consume: (T) -> Int
) throws {
    for mode in Mode.allCases {
        for _ in 0..<3 { _ = try decode(type, data: data, mode: mode) }
    }
    var samples: [Mode: [Double]] = [:]
    var checksum = 0
    for round in 0..<7 {
        let modes = round.isMultiple(of: 2) ? Mode.allCases : Mode.allCases.reversed().map { $0 }
        for mode in modes {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<iterations { checksum += try consume(decode(type, data: data, mode: mode)) }
            let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            samples[mode, default: []].append(milliseconds / Double(iterations))
        }
    }
    let native = samples[.native]!.sorted()[3]
    let preserving = samples[.preserving]!.sorted()[3]
    print(String(format: "%@ | %d bytes | native %.4f ms | preserving %.4f ms | delta %+.4f ms | checksum %d",
                 name, data.count, native, preserving, preserving - native, checksum))
}

print("7 batches per mode; median batch mean per decode; includes setup, capture and decoding; excludes I/O")
for (name, rows, numeric, iterations) in [
    ("20 rows, no dynamic number", 20, false, 500),
    ("20 rows, 3 cursor numbers", 20, true, 500),
    ("200 rows, 3 cursor numbers", 200, true, 100),
    ("2000 rows, 3 cursor numbers", 2000, true, 20),
    ("10000 rows, 3 cursor numbers", 10000, true, 4)
] {
    try measure(Response.self, name: name, data: pageData(rows: rows, numericCursor: numeric), iterations: iterations) {
        $0.data.items.count + ($0.data.items.last?.id ?? 0)
    }
}
let numbers = Data(("[" + (0..<1000).map { "\($0).000" }.joined(separator: ",") + "]").utf8)
try measure([JSONNumber].self, name: "1000 dynamic numbers", data: numbers, iterations: 30) { $0.count }
