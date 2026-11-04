// Created by weixi on 2026/11/05.
import Foundation

extension JSONDecoder {
    /// Decodes using Foundation while retaining original JSONNumber text when it
    /// can be located unambiguously. Numeric conversion and encoding stay unchanged.
    ///
    /// Capture is lazy and supports UTF-8 JSON with default or snake-case keys.
    /// Unsupported formats, custom key strategies, and ambiguous paths use normal
    /// decoding without original text. This method copies standard decoder settings
    /// into a per-call decoder; it does not mutate this decoder's userInfo.
    /// Subclasses retain their overridden decode behavior, without text capture.
    public func decodePreservingNumberText<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard Swift.type(of: self) == JSONDecoder.self else { return try decode(type, from: data) }

        let snakeCase: Bool
        switch keyDecodingStrategy {
        case .useDefaultKeys: snakeCase = false
        case .convertFromSnakeCase: snakeCase = true
        default: return try decode(type, from: data)
        }
        if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
            guard !allowsJSON5, !assumesTopLevelDictionary else { return try decode(type, from: data) }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        decoder.userInfo = userInfo
        decoder.userInfo[JSONNumberSource.userInfoKey] = JSONNumberSource(data: data, snakeCase: snakeCase)
        return try decoder.decode(type, from: data)
    }
}

/// Owns one decode's input and lazy locator. Mutable state never escapes the lock.
internal final class JSONNumberSource: @unchecked Sendable {
    static let userInfoKey = CodingUserInfoKey(rawValue: "Bedrock.JSONNumber.originalText")!

    private let lock = NSLock()
    private let snakeCase: Bool
    private var source: Data?
    private var locator: JSONNumberLocator?

    init(data: Data, snakeCase: Bool) {
        source = data
        self.snakeCase = snakeCase
    }

    func number(at path: [any CodingKey]) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let source {
            locator = JSONNumberLocator(data: source, snakeCase: snakeCase)
            self.source = nil
        }
        return locator?.number(at: path)
    }
}
