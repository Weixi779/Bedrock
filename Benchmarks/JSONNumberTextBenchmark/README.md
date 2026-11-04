# JSONNumberTextBenchmark

Compares Foundation `JSONDecoder.decode` with Bedrock's
`decodePreservingNumberText` on the same typed models and input bytes.

```sh
swift run -c release JSONNumberTextBenchmark
```

The executable imports the public Bedrock module. It measures decoder setup,
original-text lookup and model decoding together, excluding input generation,
network and disk I/O. Results are milliseconds per decode: the median of seven
batch averages after warmup, with measurement order alternating between modes.
Checksums keep decoded results observable. No performance thresholds are enforced.

Workloads include typed pages without dynamic numbers, pages with three cursor
numbers at several payload sizes, and an array of 1,000 JSONNumbers. Typed Int
fields do not trigger original-text lookup. The first JSONNumber prepares a
per-call locator, which indexes only containers along requested paths and skips
unrelated values. Later numbers reuse those container indexes.

These workloads measure latency, not peak memory or iOS device performance.
The implementation retains input bytes during decoding. Original text may be
unavailable for ambiguous key paths or unsupported formats; see the
[JSONValue guide](../../Docs/JSONValue.md) for guarantees and fallback behavior.

## Local snapshot

Measured on 2026-11-05, Apple M4 Max, macOS 27.0.1, Apple Swift 6.4,
SwiftPM release build. Values are milliseconds per complete decode.

| Workload | Bytes | Native | Preserving text | Additional time |
| --- | ---: | ---: | ---: | ---: |
| 20 rows, no dynamic number | 2,205 | 0.0237 | 0.0239 | 0.0002 |
| 20 rows, three cursor numbers | 2,214 | 0.0309 | 0.0404 | 0.0095 |
| 200 rows, three cursor numbers | 21,674 | 0.1743 | 0.1986 | 0.0242 |
| 2,000 rows, three cursor numbers | 219,874 | 1.6266 | 1.7587 | 0.1321 |
| 10,000 rows, three cursor numbers | 1,107,874 | 7.9925 | 8.7703 | 0.7778 |
| 1,000 dynamic numbers | 7,891 | 0.3860 | 0.7031 | 0.3171 |

Small differences can be measurement noise. Additional time is computed from
unrounded measurements. These figures are a local snapshot, not a latency SLA.
The locator still crosses unrelated bytes to find field boundaries; it avoids
building a complete second value tree. Dense dynamic-number payloads benefit
less because most values actually need original-text lookup.
