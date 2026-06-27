# Roadmap

Bedrock `0.1.0` is the baseline release. It is intentionally small: a set of
project-friendly Swift foundation types with readable implementations,
predictable semantics, and minimal abstraction.

The roadmap is directional, not a promise that every item will ship. A feature
belongs in Bedrock only when it is common across projects, useful with a small
API surface, and not better left to application-specific policy.

## Near-Term Work

- Improve README examples for the existing types.
- Add focused documentation for frequently used types as needs become clear.
- Document key semantics clearly: ordering, equality, capacity behavior,
  mutation costs, and edge cases.
- Keep benchmarks tied to implementation decisions instead of turning them into
  a separate performance framework.

## Candidate Features

### Existing Type Polish

- Small convenience APIs when real usage shows repeated boilerplate.
- Reordering or update helpers when they preserve clear type invariants.
- Additional examples for common usage patterns.
- More benchmark notes when they explain implementation tradeoffs.

### Possible Later Types

- `PriorityQueue` / `Heap`
- `Counter` / `Bag`
- `Multimap`
- `BiMap`

These are candidates because they are common project-level primitives, but each
should be added only if the API can stay small and the behavior is easy to
explain.

## Non-Goals

- Replacing Swift Collections.
- Framework-level architecture.
- Thread-safe containers by default.
- Built-in serialization policies for every type.
- Large abstraction layers around collection protocols.
- Features added only for completeness.
