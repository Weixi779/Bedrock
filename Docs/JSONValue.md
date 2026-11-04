# JSONValue

`JSONValue` stores the six JSON kinds and supports `Equatable`, `Sendable`, and
system `Codable`. It is intended for dynamic fields such as pagination cursors.
It uses Foundation for JSON validation and model decoding, with an optional
lazy numeric-token locator. It supplies no custom encoder or arbitrary-precision arithmetic.

```swift
import Foundation
import Bedrock

struct Page: Codable, Equatable {
    let cursor: JSONValue?
}

let page = try JSONDecoder().decode(Page.self, from: responseData)
let requestData = try JSONEncoder().encode(page)
```

The cases are `.null`, `.bool`, `.string`, `.number`, `.array`, and `.object`.
Use `JSONValue(validating:)` to validate an existing `JSONSerialization` value
tree. It accepts JSON-compatible strings, numbers, booleans, null, arrays, and
string-keyed objects. It rejects Date, URL, Data, and custom objects rather than
guessing their representation. Conversion errors carry the member/index path.
Foundation booleans are identified separately from NSNumber integers 0 and 1.

## Default numeric path

`JSONNumber` decodes a non-NaN Decimal first, then a finite, nonzero Double if
Decimal decoding fails. Decimal covers signed and unsigned 64-bit integers and
ordinary decimal fractions; Double extends the exponent range. Double fallback
may round. Zero is rejected in this fallback because a failed Decimal decode
followed by Double zero may indicate underflow. Normal zero decodes as Decimal.

Numeric constructors accept fixed-width integers, finite Double, and non-NaN
Decimal. Double construction first preserves exactly representable Int64/UInt64
integers; other values use their shortest round-trip text. It does not call
`Decimal(Double)`. Thus constructing from `19.99` agrees with decoding JSON
`19.99` on the tested Foundation implementation.

`int64Value` and `uint64Value` return exact integers from the stored numeric
representation or nil; they do not reconstruct a value from captured original text. Integral
decimal and exponent forms are accepted (`1.0` and `1e2` become 1 and 100).
`decimalValue` requires a matching decimal identity. `doubleValue` allows
rounding but rejects infinity and nonzero underflow. For example, converting
9007199254740993 to Double can yield 9007199254740992; this conversion does not
change the stored number.

```swift
if case .number(let number) = value {
    let exactInteger = number.int64Value
    let decimal = number.decimalValue
    let approximate = number.doubleValue
}
```

## Network response envelopes

A generic response envelope can decode its business status first, decode a typed
payload on success, and capture the response with `JSONValue(from: decoder)` on
failure. The successful payload does not need to pass through JSONValue or an
encode/decode intermediate step. Application-specific status and error policies
remain in the network layer.

See [APIResponseTests.swift](../Tests/BedrockTests/JSON/APIResponseTests.swift) for
executable examples covering a typed page with a nested cursor, returning that
cursor in the next request, a business error whose data does not match the success
model, and a nested type mismatch with its original coding path. Captured JSON
values retain the numeric limitations below; keep the response Data separately
if exact original bytes are needed.

## Capturing original numbers in Codable models

Use the existing JSONDecoder's supplemental entry point:

```swift
let decoder = JSONDecoder()
let page = try decoder.decodePreservingNumberText(Page.self, from: responseData)
```

No property annotation or field configuration is required. Existing Codable
models, nested arrays, dictionaries, and forwarding property wrappers continue
to use Foundation. Ordinary `decoder.decode` remains available with its existing
behavior and no original-text capture.

The entry point copies standard decoder settings and userInfo into a per-call
Foundation decoder; it does not mutate the caller's decoder. Do not change the
caller's settings concurrently with decoding. Custom JSONDecoder subclasses are
decoded through their own overrides without capture.

The first JSONNumber lazily prepares a source locator. It indexes containers
along codingPath, skips unrelated value bytes, and caches those container indexes.
Models containing only ordinary numeric Swift fields do not trigger this work.
The source context is scoped to a decode and is not retained by resulting numbers.

Capture supports UTF-8 JSON (including its BOM), default keys, and unambiguous
snake-case key conversion. Original text remains **optional**:

- Ambiguous paths, duplicate or Unicode-equivalent keys decline capture. A model
  and a dictionary may interpret the same codingPath differently after key conversion.
- Custom key strategies, JSON5, unbraced top-level dictionaries, non-UTF-8 input,
  and paths deeper than 128 components use ordinary decoding without capture.
- If a Foundation version rejects input before reaching JSONNumber, this entry
  point does not bypass that rejection.

If text is unavailable, normal numeric decoding still runs. If numeric decoding
fails but a valid original token is available, JSONNumber retains it as a text-only
value; normal encoding of that value fails explicitly. No raw-number output hook
is added to JSONEncoder.

Captured text never changes numeric equality, getters or default encoding. A long
number may have a rounded stored Decimal **and** an exact `originalText`:

```swift
let input = Data("0.1234567890123456789012345678901234567890123456789".utf8)
let number = try decoder.decodePreservingNumberText(JSONNumber.self, from: input)
let original = number.originalText  // Exact token, when capture succeeds.
let decimal = number.decimalValue  // Foundation's numeric representation.
let output = try JSONEncoder().encode(number) // Encodes the stored number.
```

Use originalText explicitly when a custom consumer needs the original precision.
This is not byte-for-byte JSON round-tripping. Data already converted by
JSONSerialization/ObjectMapper into Any has no recoverable original spelling;
`JSONValue(validating:)` only validates the values it receives.

See [original-text tests](../Tests/BedrockTests/JSON/JSONOriginalTextTests.swift)
and the [reproducible benchmark](../Benchmarks/JSONNumberTextBenchmark/README.md).

## Explicit numeric text

```swift
let number = try JSONNumber(rawValue: "1.2300")
number.originalText       // "1.2300"
number.decimalValue       // 1.23

let enormous = try JSONNumber(rawValue: "1e400")
enormous.originalText     // "1e400"
enormous.isCodableNumber  // false
// JSONEncoder().encode(enormous) throws EncodingError.invalidValue.
```

The text initializer validates the entire ASCII JSON number grammar. It preserves
the original spelling and only selects Decimal or Double when that representation's
decimal spelling matches the input's normalized decimal identity. Otherwise it
keeps a **text-only** value, including legal numbers outside machine ranges or
precision. It never converts a numeric token into a JSON string to make encoding
succeed. An application with a custom JSON writer can retrieve `originalText` and
emit that validated token as a number. Bedrock supplies no raw-token hook into
Foundation JSONEncoder.

`originalText` is nil for numeric constructors and ordinary system decoding.
The supplemental entry point above can capture it from the original Data; the
standard Decoder protocol itself does not expose the token. `description` returns the
original text when present, or a generated numeric spelling otherwise; it must
not be treated as evidence of what the server sent. When copying this feature,
copy all files in `Sources/Bedrock/JSON`, not just JSONValue.swift.

## Equality

- Different JSON kinds are unequal: `true`, `1`, and `"1"` are distinct.
- Objects ignore key order; arrays compare corresponding elements in order.
- Strings and object keys use Swift String semantics, including canonical Unicode
  equivalence. This is not byte-for-byte JSON text comparison.
- Numeric representations compare normalized **decimal spellings**, without
  promoting either operand to Double. `1`, `1.0`, and `1e0` compare equal, as do
  signed zeros. Distinct adjacent 64-bit integers remain distinct.
- Stored Double's identity is its shortest round-trip decimal spelling, not its
  exact binary rational value. The Double constructor preserves exact 64-bit
  integers as Decimal instead. No epsilon or approximate equality is used.
- Original text does not affect equality of numeric representations.
- Text-only values compare exact text and are unequal to numeric representations.
  Thus `1e400` and `10e399` are distinct text-only values. They are opaque escape
  hatches, not arbitrary-precision arithmetic values.

The last rule is deliberately separate: comparison never switches between text
and a rounded numeric approximation depending on the other operand. This keeps
equality reflexive, symmetric, and transitive. Hashable is not part of this API.

## What a system Codable round trip does not promise

Foundation may change number spellings (`1.00` to `1`), object order, whitespace,
and string escapes. It may round long numeric tokens before `JSONNumber` receives
them; successful decoding is not proof of exact preservation of the server's
number. Without original-text capture, lost digits cannot be recovered afterward. Decimal acceptance
also depends on extreme exponent spelling and the Foundation version.

For custom high-precision handling, use captured `originalText` when available,
or construct `JSONNumber(rawValue:)` from independently obtained numeric text. A text-only value cannot round-trip
through the default encoder: it fails explicitly, including its coding path.

Object dictionaries bypass Foundation's model key conversion strategies, so a
cursor's `some_key` remains `some_key` even if its enclosing model uses
`convertFromSnakeCase`. Duplicate keys and Unicode-equivalent keys have the
underlying Foundation/Swift dictionary behavior; this type cannot preserve
multiple entries for such keys. Foundation remains responsible for JSON validation and its decoding resource
limits. The supplemental locator has a separate 128-component path limit.

## Implementation references and verification

The implementation is original. Design references include Go's small
[`json.Number`](https://pkg.go.dev/encoding/json#Number) conversion interface,
[PotentJSON](https://github.com/outfoxx/PotentCodables/tree/main/Sources/PotentJSON),
and OrderedJSON's separation of
[raw tokens from Codable interoperability](https://github.com/ajevans99/swift-json-schema/blob/main/Sources/OrderedJSON/JSONValue%2BCodable.swift).
Their numeric equality, conversion policies, and full codec architectures are
not adopted wholesale.

Tests cover explicit syntax validation, unsupported text preservation, numeric
limits, errors with paths, Foundation value bridging, model key strategies,
equality laws, generic response envelopes, original-text capture and fallbacks,
concurrent calls, and generated integer/decimal round trips. Runtime
verification is on Apple Swift 6.4, macOS 27.0.1, arm64. This does not certify
other Foundation versions, iOS runtimes, or Linux behavior.
