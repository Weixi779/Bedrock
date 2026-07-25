# HeapBenchmark

`HeapBenchmark` compares Bedrock's public `Heap` with small priority-queue
implementation alternatives.

The benchmark uses a min-priority queue: the smallest integer is the next item
to remove. `Heap` accepts a priority predicate, so a max-heap is the same
storage and algorithm with the comparison reversed.

## Run

```sh
swift run -c release HeapBenchmark
swift run -c release HeapBenchmark 1000
swift run -c release HeapBenchmark 10000
```

The optional argument is the number of deterministic, pseudo-random priority
values. Every measurement reports the best time from three iterations. The
target checks each candidate's priority-order invariant before measuring it.

## Candidates

- `Heap`: Bedrock's conventional array-backed binary heap. It supports
  `O(log n)` insertion and removal, `O(1)` peek, and `O(n)` bottom-up heapify.
- `FourAryMinHeap`: an array-backed 4-ary heap. Its tree is shallower, but each
  downward step must select from up to four children.
- `SortedArrayMinQueue`: maintains descending order. Peek and removal are
  `O(1)`, while insertion shifts an average of `n / 2` elements.
- `UnsortedArrayMinQueue`: appends in `O(1)`, but peek and removal scan all
  stored elements.

The array baselines are intentional. They make the workload tradeoffs visible:
a heap is not automatically the fastest choice for a tiny queue or a workload
that only inserts.

## Workloads

- **Individual insertions** models incoming tasks whose priorities are known
  one at a time.
- **Bulk construction** models restoring a persisted task list. The heap
  candidates use bottom-up heapify rather than repeatedly inserting values.
- **Remove every task** isolates the cost of executing a prebuilt queue in
  priority order.
- **Steady-state scheduling** models a worker that removes its next task and
  receives one replacement while keeping a bounded queue.
- **Top K** keeps the highest priorities from a stream using a min-priority
  queue. This is the pattern behind retaining the slowest requests, largest
  files, or highest-scored feed items without sorting the complete stream.

## Scope

This benchmark informs tuning decisions for the public implementation. Its
`Heap` candidate is a small adapter around the real Bedrock type, not a copy of
its storage algorithm.

## Local Baseline

Command:

```sh
swift run -c release HeapBenchmark
```

Environment:

- Platform: macOS 26.5.1, arm64
- Swift: Apple Swift 6.3.3
- Build configuration: release
- Input: 10,000 values, a 1,024-item scheduler window, and `K = 128`

Representative best-of-3 timings:

| Workload | Public Heap | 4-ary heap | Sorted array | Unsorted array |
| --- | ---: | ---: | ---: | ---: |
| Individual insertions | 0.119 ms | 0.118 ms | 2.690 ms | 0.014 ms |
| Bulk construction | 0.038 ms | 0.018 ms | 0.594 ms | 0.011 ms |
| Remove every task | 0.225 ms | 0.354 ms | 0.011 ms | 60.575 ms |
| Steady-state scheduling | 0.393 ms | 0.256 ms | 0.295 ms | 16.383 ms |
| Top K from a stream | 0.028 ms | 0.015 ms | 0.024 ms | 0.239 ms |

## Direction

The results support an array-backed binary heap for the first public
implementation. The public heap removes every task faster than the 4-ary heap
and remains competitive in the mixed workloads. A 4-ary heap can win some
bounded-queue workloads, but not consistently enough to justify its more
complex child-selection logic in the first release.

The sorted array wins a deliberately narrow case: draining a queue after
paying its sort cost up front. It does not remain competitive once new work
arrives dynamically. The unsorted array is useful only for insertion-heavy work
that rarely needs its next priority.

The public API therefore uses an `Array`-backed binary heap with:

- one generic priority predicate, rather than separate max-heap and min-heap
  storage types;
- a bulk initializer that uses bottom-up heapify;
- `peek`, `insert`, and `pop` as the small core API; and
- `reserveCapacity` if real call sites can predict queue size.

Avoid treating a single local run as a universal performance claim. The useful
signal is whether one candidate has a consistent advantage in the workloads
Bedrock intends to support.
