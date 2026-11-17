---
name: principle-validate-boundaries
description: Apply when data, commands, permissions, or failures cross a trust or system boundary; validate and enforce the relevant contract where it can be reliably guaranteed.
---

# Validate Boundaries

## Trigger

Apply when accepting external inputs, using credentials, calling services, changing permissions, parsing configuration, or moving data across a trust boundary. Identify the actual boundary and the consequences of invalid or unauthorized inputs.

## Rule

Validate and normalize untrusted input, enforce authorization at the appropriate boundary, and propagate actionable errors. Keep boundary handling separate from core behavior where practical, without duplicating checks that are genuinely guaranteed or removing checks that protect a separate invariant.

## Apply

- Identify sources, trust levels, contracts, failure modes, and who owns authorization. Treat user input, environment, files, external responses, and agent-generated content according to their actual trust, not their apparent format.
- Check required shape, allowed values, permissions, and relevant constraints before unsafe effects. Preserve validation, access controls, error handling, and data-integrity checks when moving or refactoring code.
- Pass validated representations inward where the runtime and contract make the guarantee reliable. Revalidate when a new trust boundary, mutable state, persistence, concurrency, or independent security invariant requires it; types alone do not secure an external boundary.
- Prefer simple, testable core logic and existing validation mechanisms. Return or record useful failures without exposing sensitive values. Verify both valid and invalid inputs where risk warrants it.

## Boundaries and examples

- A CLI that changes a GitHub issue checks its arguments and authorization before the mutation, handles API errors, and does not treat an agent's generated input as inherently trusted.
- A pure internal calculation using an immutable value already guaranteed by its contract need not repeat the same format check at every call.
- Do not remove authorization, database constraints, or security checks merely because a caller performed validation. This principle does not authorize new permissions or bypass workflow gates.
