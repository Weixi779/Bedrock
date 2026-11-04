// Created by weixi on 2026/11/04.

/// Grammar validation and a bounded comparison key; no arithmetic or JSON parsing.
internal struct JSONNumberText {
    enum Identity: Equatable {
        case number(negative: Bool, digits: String, exponent: Int)
        case unbounded(String)
    }

    let identity: Identity

    var isZero: Bool {
        if case .number(_, "0", _) = identity { return true }
        return false
    }

    init?(_ source: String) {
        let bytes = Array(source.utf8)
        let negative = bytes.first == UInt8(ascii: "-")
        var index = negative ? 1 : 0
        guard index < bytes.count else { return nil }

        // Integer part: a single zero or a nonzero digit followed by digits.
        let integerStart = index
        if bytes[index] == UInt8(ascii: "0") {
            index += 1
        } else {
            guard Self.isNonzeroDigit(bytes[index]) else { return nil }
            index = Self.endOfDigits(in: bytes, from: index)
        }
        var coefficientDigits = Array(bytes[integerStart..<index])

        // Fraction: a decimal point must be followed by at least one digit.
        var fractionalDigitCount = 0
        if index < bytes.count && bytes[index] == UInt8(ascii: ".") {
            index += 1
            let fractionStart = index
            index = Self.endOfDigits(in: bytes, from: index)
            fractionalDigitCount = index - fractionStart
            guard fractionalDigitCount > 0 else { return nil }
            coefficientDigits.append(contentsOf: bytes[fractionStart..<index])
        }

        // Exponent syntax can be valid even when its magnitude exceeds Int.
        var explicitExponent: Int? = 0
        if index < bytes.count && Self.isExponentMarker(bytes[index]) {
            index += 1
            let exponentStart = index
            if index < bytes.count && Self.isSign(bytes[index]) { index += 1 }
            let exponentDigitsStart = index
            index = Self.endOfDigits(in: bytes, from: index)
            guard index > exponentDigitsStart else { return nil }
            let exponentText = String(decoding: bytes[exponentStart..<index], as: UTF8.self)
            explicitExponent = Int(exponentText)
        }
        guard index == bytes.count else { return nil }

        identity = Self.normalizedIdentity(
            source: source,
            negative: negative,
            coefficientDigits: coefficientDigits,
            fractionalDigitCount: fractionalDigitCount,
            explicitExponent: explicitExponent
        )
    }

    var integerSpelling: String? {
        guard case .number(let negative, let digits, let exponent) = identity,
              exponent >= 0, exponent <= 20, digits.count <= 20 - exponent else { return nil }
        return (negative ? "-" : "") + digits + String(repeating: "0", count: exponent)
    }
}

private extension JSONNumberText {
    static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    static func isNonzeroDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "1") && byte <= UInt8(ascii: "9")
    }

    static func isSign(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-")
    }

    static func isExponentMarker(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E")
    }

    static func endOfDigits(in bytes: [UInt8], from start: Int) -> Int {
        var index = start
        while index < bytes.count && isDigit(bytes[index]) { index += 1 }
        return index
    }

    static func normalizedIdentity(
        source: String,
        negative: Bool,
        coefficientDigits: [UInt8],
        fractionalDigitCount: Int,
        explicitExponent: Int?
    ) -> Identity {
        guard let firstNonzero = coefficientDigits.firstIndex(where: { $0 != UInt8(ascii: "0") }) else {
            return .number(negative: false, digits: "0", exponent: 0)
        }
        let lastNonzero = coefficientDigits.lastIndex(where: { $0 != UInt8(ascii: "0") })!
        let trailingZeroCount = coefficientDigits.count - lastNonzero - 1
        let exponentAdjustment = trailingZeroCount - fractionalDigitCount

        // Huge exponents remain valid text, without expanding powers of ten.
        guard let explicitExponent else { return .unbounded(source) }
        let (normalizedExponent, overflow) = explicitExponent.addingReportingOverflow(exponentAdjustment)
        guard !overflow else { return .unbounded(source) }

        let significantDigits = String(decoding: coefficientDigits[firstNonzero...lastNonzero], as: UTF8.self)
        return .number(negative: negative, digits: significantDigits, exponent: normalizedExponent)
    }
}
