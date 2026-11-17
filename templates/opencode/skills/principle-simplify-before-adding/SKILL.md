---
name: principle-simplify-before-adding
description: Apply when choosing how to implement or change a capability; look for unnecessary work to remove and existing capabilities to reuse before adding code, dependencies, or abstractions.
---

# Simplify Before Adding

## Trigger

Apply when designing or implementing a change, especially when it proposes new code, configuration, dependencies, or abstractions. For a straightforward small change, a quick check of the surrounding code is enough.

## Rule

Meet the requested outcome with the smallest complete, understandable change. Before adding machinery, ask whether the need can be met by removing unnecessary complexity or using what already exists. Deletion is valuable when it improves the result, not merely because it reduces the line count.

## Apply

- Understand required behavior and inspect relevant callers, tests, configuration, and existing conventions. Separate genuinely unnecessary work from behavior or scope the user requires.
- Prefer an appropriate existing project capability; otherwise consider the standard library or platform, then an installed dependency, before introducing a new dependency. Fit the existing architecture rather than adding a parallel mechanism.
- Remove obsolete code or duplication when it is safe and within scope. Avoid speculative features, wrappers, options, and abstractions; add structure when it makes the actual solution clearer or safer.
- Complete all affected changes and verify the result. Account for callers, compatibility, security, accessibility, validation, error handling, and data integrity; a short diff that breaks them is not a complete solution.
- When a deliberate shortcut has a meaningful limit, make its impact and upgrade trigger discoverable in an appropriate code comment or project record. Follow the project's debt and ownership conventions; do not hide a material risk.

## Boundaries and examples

- If an existing helper satisfies the requested behavior, reuse it and remove a now-unused duplicate after checking its callers and tests.
- Do not delete a public compatibility path simply because it looks redundant: verify consumers and apply `principle-change-existing-code-safely` when replacing an interface.
- A few clear lines can be better than a cryptic one-liner or a forced reuse of an unsuitable helper. Do not silently discard requested features or expand scope under the banner of simplification. This principle does not start a managed workflow.
