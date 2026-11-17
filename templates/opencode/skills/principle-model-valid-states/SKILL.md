---
name: principle-model-valid-states
description: Apply when designing or changing data shapes, types, state transitions, or function contracts; make invalid combinations difficult to represent and validate untrusted values at boundaries.
---

# Model Valid States

## Trigger

Apply when a change introduces or modifies data shapes, function contracts, lifecycle states, or values with different meanings. Use the techniques appropriate to the language, runtime, risk, and existing architecture; a trivial local value does not justify a new type hierarchy.

## Rule

Represent meaningful states and contracts so invalid combinations are difficult to create, and handle the cases a change introduces. Use the language's type system where it adds real protection, but do not confuse compile-time claims with runtime validation or authorization.

## Apply

- Identify valid states, transitions, required fields, and invariants. Prefer a single source of truth over duplicated fields that can disagree; use discriminated variants or equivalent constructs when they make real constraints clearer.
- Distinguish similar-looking values when mixing them up would cause a material defect. Use existing types or lightweight wrappers where helpful; do not add brands, classes, or layers to every primitive by default.
- Parse and validate untrusted external data at appropriate boundaries, including values from configuration, network responses, files, and command arguments. Follow `principle-validate-boundaries`; preserve independent authorization and storage constraints.
- Handle all meaningful variants and failures. Use exhaustive compiler checks where supported and useful, and tests or runtime validation where static guarantees are unavailable. Avoid unchecked casts or assertions that hide uncertainty; if unavoidable, isolate, justify, and verify them.
- Reuse or derive from the authoritative schema when practical. Do not create a second hand-maintained definition without a reason; account for versioning and generators when they are the source of truth.

## Boundaries and examples

- If a completed task must have a completion timestamp, model open and completed states so a completed task cannot silently lack that timestamp; validate external records before treating them as either state.
- A short-lived local counter does not need a custom wrapper merely because it is numeric. Prefer a clear name and focused checks if the risk is low.
- A type annotation does not prove data from a network or database is safe, and it does not replace authorization, concurrency control, or database constraints. This principle does not start a managed workflow or require GitHub artifacts.
