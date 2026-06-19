# DequeBenchmark

Storage experiments for a future `Deque` implementation.

## Run

```sh
swift run -c release DequeBenchmark 100000
```

The benchmark compares the public `Deque` against candidate internal layouts
across double-ended append, remove, and random-access workloads.

## Research summary

Swift implementations should drive the design. Other languages are useful
references, but Swift's value semantics, copy-on-write storage, and Collection
protocol expectations matter more here.

The primary reference is
[`apple/swift-collections` `Deque`](https://github.com/apple/swift-collections/tree/main/Sources/DequeModule/Deque):

- Its public `Deque` documentation says the type stores elements in a circular
  buffer. It conforms to `RangeReplaceableCollection`, `MutableCollection`, and
  `RandomAccessCollection`, with integer indices matching `Array`.
- Storage is a copy-on-write `ManagedBufferPointer` wrapping a
  `_DequeBufferHeader` and element storage. The header stores `capacity`,
  `count`, and `startSlot`.
- Logical index to physical storage is handled by slot arithmetic:
  `slot(forOffset:)` adds the offset to `startSlot` and wraps around
  `capacity`. This is the core ring-buffer mapping.
- When growth or copy-on-write uniqueness requires a new buffer, elements are
  copied or moved into a new buffer with `startSlot` reset to zero.
- `append(_:)` ensures unique capacity and initializes at `endSlot`;
  `prepend(_:)` initializes at `slot(before: startSlot)` and moves `startSlot`
  backward. Both are documented as amortized O(1), with O(`count`) cases when
  reallocating or copying shared storage.
- The implementation deliberately does not expose a stable `capacity` property;
  capacity remains an implementation detail, though `reserveCapacity` exists.

Swift-specific takeaway: a public `Deque` should be a value type with
copy-on-write storage and `RandomAccessCollection`-style integer indices. A
ring buffer is not just conventional; it is the design chosen by the main Swift
Collections package.

Other languages remain secondary references:

- Rust `VecDeque` and Java `ArrayDeque` are also growable array/ring-buffer
  designs, which supports the same general direction.
- CPython `collections.deque` and C++ `std::deque` use segmented blocks. These
  are useful alternatives to study for very large or allocation-sensitive
  workloads, but they add complexity that does not match this package's current
  small Swift value-type style.
- Two-array balancing is not a standard Swift Collections `Deque` design. It
  can benchmark well in Swift because `Array.append` and `popLast` are fast, so
  it is worth measuring, but it should not override the Swift Collections
  circular-buffer precedent without stronger evidence.

## Candidates in this benchmark

- `RingBufferDeque`: power-of-two circular buffer with `head`, `count`, and
  optional slots. This is the same storage shape used by the public `Deque` and
  public `RingBuffer` implementations.
- `CenteredArrayDeque`: stores active elements in the middle of an array and
  recenters or grows when either end runs out of space.
- `FullMoveDeque`: two arrays that move all elements to the other side when an
  empty side is popped. This matches the existing `Queue` idea generalized to
  two ends, but has a bad alternating-pop case.
- `HalfRebalanceDeque`: two arrays that move only about half the elements when
  one side empties. This keeps the Swift `Array` fast path while avoiding the
  obvious full-move cliff.
- `Queue` and plain `Array` are included only as baselines.

## Local result snapshot

Command:

```sh
swift run -c release DequeBenchmark 100000
```

Environment:

- Date: 2026-06-19
- Platform: macOS arm64e, Swift 6 package, release build
- Stress workload size: `20_000` for the alternating-pop case

Representative best-of-3 timings:

| Workload | Public Deque | Ring buffer | Centered array | Full move | Half rebalance | Baseline |
|---|---:|---:|---:|---:|---:|---:|
| Append back, pop front | 0.526 ms | 0.497 ms | 0.606 ms | 0.388 ms | 0.329 ms | Queue 12.392 ms |
| Append front, pop back | 0.352 ms | 0.295 ms | 0.394 ms | 0.270 ms | 0.219 ms | Array 605.697 ms |
| Append back, alternate pop front/back | 0.072 ms | 0.076 ms | 0.077 ms | 145.988 ms | 0.040 ms | - |
| Mixed append/pop at both ends | 0.373 ms | 0.381 ms | 0.325 ms | 0.252 ms | 0.246 ms | - |
| Sliding window | 0.196 ms | 0.188 ms | 0.301 ms | 0.290 ms | 0.183 ms | Queue 9.908 ms |
| Random access | 0.691 ms | 0.677 ms | 0.768 ms | 0.705 ms | 0.734 ms | Array 0.556 ms |

## Current conclusion

Do not use the full-move two-array strategy for the public `Deque`: it looks
good in FIFO-like workloads, but alternating pops after one-sided appends expose
an O(n^2)-shaped cliff.

The public `Deque` now uses ring-buffer storage. This matches Swift
Collections' circular-buffer design, supports O(1) random access, and naturally
matches the public `RingBuffer` shape added to the package. The current public
implementation benchmarks in the same range as the standalone `RingBufferDeque`
experiment once hot public APIs are marked `@inlinable`.

Keep `HalfRebalanceDeque` in the benchmark as a future tuning reference: it can
win some end-operation microbenchmarks, but its Collection conformance and
balancing invariants need more careful design before it should replace the
ring-buffer implementation.
