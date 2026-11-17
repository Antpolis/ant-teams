---
name: principle-reconsider-the-design
description: Apply when a new requirement exposes repeated workarounds, conflicting responsibilities, or a design that no longer fits; compare a targeted correction with a proportionate redesign before committing to more patches.
---

# Reconsider the Design

## Trigger

Use when evidence shows that an existing design repeatedly resists a requirement: similar workarounds recur, responsibilities conflict, or changes repeatedly break the same invariant. A single awkward line or an unfamiliar pattern is not enough evidence for a redesign.

## Rule

Understand the current design and why it exists, then ask what shape would meet the present requirements without the observed friction. Compare that shape with the smallest complete correction. Choose the approach that solves the demonstrated problem while accounting for migration, compatibility, safety, maintenance, and delivery risk.

## Apply

- Trace affected callers, data, tests, and constraints; identify concrete failures or recurring friction rather than relying on taste. Preserve valid existing behavior and security boundaries.
- Consider a coherent alternative alongside a bounded fix. Reuse existing mechanisms where they fit; avoid extra abstractions and speculative flexibility. Explore or prototype only as much as uncertainty and reversibility justify.
- If a redesign is warranted, define its scope and verify it in safe increments. Plan caller migration and compatibility when needed; do not leave an undocumented transition or delete an API while users still depend on it.
- Use `principle-simplify-before-adding`, `principle-respect-project-constraints`, and `ponytail` for implementation judgment. Product changes, destructive actions, and managed-workflow gates still require their existing authority; reading this principle does not start a workflow.

## Examples and boundaries

- If three unrelated features need special cases around the same shared state, compare a clearer ownership model against another special case, including how existing users would migrate.
- If one validation message is wrong, fix and test that behavior; do not redesign the validation system solely because an alternative looks cleaner.
- When evidence is incomplete, report the uncertainty and investigate proportionately. Do not present an architectural preference as a proven defect or make a risky rewrite necessary for every small change.
