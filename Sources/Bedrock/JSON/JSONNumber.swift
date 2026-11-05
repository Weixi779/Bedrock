// Created by weixi on 2026/11/04.
import Foundation

/// A JSON number with a practical numeric representation and an optional original spelling.
///
/// Foundation Codable uses Decimal first, then finite Double. The supplemental
/// `decodePreservingNumberText` entry point can retain input tokens alongside those
/// values. `init(rawValue:)` also accepts explicit numeric text. Text-only values
/// outside the supported numeric representations require a custom encoder.
public struct JSONNumber: Sendable {
    private enum Storage: Sendable {
        case decimal(Decimal)
        case double(Double)
        case textOnly(String)
    }

    private let storage: Storage

    /// Explicit input text or text captured by `decodePreservingNumberText`.
    /// Nil when the input spelling is unavailable or cannot be located unambiguously.
    public let originalText: String?

    public enum ValidationError: Error, Equatable, Sendable {
        case invalidSyntax
        case nonFinite
    }

    /// Validates JSON number grammar without imposing a machine-number range limit.
    public init(rawValue: String) throws {
        guard let text = JSONNumberText(rawValue) else { throw ValidationError.invalidSyntax }
        storage = Self.representation(of: rawValue, text: text)
        originalText = rawValue
    }

    /// Constructs a signed or unsigned integer without passing through Double.
    public init<T: FixedWidthInteger>(_ value: T) {
        let text = String(value)
        // Fixed-width integers have valid JSON syntax, including types wider than UInt64.
        storage = Self.representation(of: text, text: JSONNumberText(text)!)
        originalText = nil
    }

    /// Preserves exact 64-bit integers; otherwise uses the finite Double's shortest
    /// round-trip decimal spelling, not Decimal(Double).
    public init(_ value: Double) throws {
        guard value.isFinite else { throw ValidationError.nonFinite }
        if let integer = Int64(exactly: value) {
            storage = .decimal(Decimal(integer))
        } else if let integer = UInt64(exactly: value) {
            storage = .decimal(Decimal(integer))
        } else {
            let text = String(value)
            storage = Self.representation(of: text, text: JSONNumberText(text)!)
        }
        originalText = nil
    }

    public init(_ value: Decimal) throws {
        guard !value.isNaN else { throw ValidationError.nonFinite }
        storage = .decimal(value)
        originalText = nil
    }

    /// Whether the standard Codable path can encode this value as a number.
    public var isCodableNumber: Bool {
        if case .textOnly = storage { return false }
        return true
    }

    /// An exact integer conversion, including integral decimal/exponent forms.
    public var int64Value: Int64? {
        numericText?.integerSpelling.flatMap(Int64.init)
    }

    public var uint64Value: UInt64? {
        numericText?.integerSpelling.flatMap(UInt64.init)
    }

    /// A Decimal with the same decimal identity, or nil if it cannot be represented.
    public var decimalValue: Decimal? {
        switch storage {
        case .decimal(let value): return value
        case .double(let value):
            let source = String(value)
            guard let text = JSONNumberText(source) else { return nil }
            return Self.exactDecimal(in: source, matching: text)
        case .textOnly: return nil
        }
    }

    /// Allows floating-point rounding. Returns nil for overflow or nonzero underflow.
    /// Reading a rounded Double never changes the stored value or original text.
    public var doubleValue: Double? {
        guard let result = Double(storedText), result.isFinite else { return nil }
        if result == 0, JSONNumberText(storedText)?.isZero != true { return nil }
        return result
    }

    private var numericText: JSONNumberText? {
        guard isCodableNumber else { return nil }
        return JSONNumberText(storedText)
    }

    private var storedText: String {
        switch storage {
        case .decimal(let value): return value.description
        case .double(let value): return String(value)
        case .textOnly(let text): return text
        }
    }
}

extension JSONNumber: CustomStringConvertible {
    /// Original text when available; otherwise the stored number's decimal spelling.
    public var description: String {
        if let originalText { return originalText }
        return storedText
    }
}

extension JSONNumber: Hashable {
    /// Numeric representations compare decimal identities, without conversion to Double.
    /// Text-only values compare exact spelling and never equal a numeric representation.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case (.textOnly(let leftText), .textOnly(let rightText)): return leftText == rightText
        case (.textOnly, _), (_, .textOnly): return false
        default: return lhs.numericText?.identity == rhs.numericText?.identity
        }
    }

    /// Uses the same numeric identity or text-only spelling as equality.
    /// Captured original text does not affect the hash of numeric representations.
    public func hash(into hasher: inout Hasher) {
        switch storage {
        case .textOnly(let text):
            hasher.combine(1)
            hasher.combine(text)
        default:
            hasher.combine(0)
            hasher.combine(numericText?.identity)
        }
    }
}

extension JSONNumber: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let source = decoder.userInfo[JSONNumberSource.userInfoKey] as? JSONNumberSource
        originalText = source?.number(at: decoder.codingPath)
        if let value = try? container.decode(Decimal.self), !value.isNaN {
            storage = .decimal(value)
        } else if let value = try? container.decode(Double.self), value.isFinite, value != 0 {
            // A zero after Decimal failed may be a nonzero input underflowing in Double.
            storage = .double(value)
        } else if let originalText {
            // The locator validated this token; unsupported numbers remain text-only.
            storage = Self.representation(of: originalText, text: JSONNumberText(originalText)!)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "JSON number is outside the supported numeric range. Use an explicit text input for custom handling."
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch storage {
        case .decimal(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .textOnly:
            throw EncodingError.invalidValue(self, .init(
                codingPath: encoder.codingPath,
                debugDescription: "This number requires custom encoding of originalText; it cannot be encoded through a supported numeric type."
            ))
        }
    }
}

private extension JSONNumber {
    private static func representation(of source: String, text: JSONNumberText) -> Storage {
        if let decimal = exactDecimal(in: source, matching: text) {
            return .decimal(decimal)
        }
        if let double = Double(source), double.isFinite,
           JSONNumberText(String(double))?.identity == text.identity {
            return .double(double)
        }
        return .textOnly(source)
    }

    static func exactDecimal(in source: String, matching text: JSONNumberText) -> Decimal? {
        guard let decimal = Decimal(string: source, locale: Locale(identifier: "en_US_POSIX")),
              !decimal.isNaN,
              JSONNumberText(decimal.description)?.identity == text.identity else { return nil }
        return decimal
    }
}
