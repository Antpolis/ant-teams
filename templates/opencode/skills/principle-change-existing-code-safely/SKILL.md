---
name: principle-change-existing-code-safely
description: Apply when refactoring existing code or replacing an interface with existing callers; preserve required behavior, verify changes, and migrate consumers safely when contracts change.
---

# Change Existing Code Safely

## Trigger

Apply when restructuring existing code or replacing an API, interface, command, or other contract with existing consumers. A small self-contained edit does not need a migration plan.

## Rule

Understand the existing behavior and its consumers before changing it. Preserve required behavior during a refactor; when a contract intentionally changes, migrate callers and retire old paths only when safe. Verify the result against the appropriate old or new contract rather than assuming a cleaner implementation is correct.

## Apply

- Inspect relevant callers, tests, configuration, scripts, and documentation. Establish a passing baseline or other evidence of current behavior where practical; identify unknown consumers and verification limits rather than assuming they do not exist.
- For behavior-preserving refactoring, keep changes focused and incremental where practical, verify preserved behavior, and avoid hiding a risky rewrite or unrelated behavioral change under the label of cleanup. Retain necessary validation, error handling, security, and data integrity.
- For an intentional contract change, identify compatibility obligations and migrate and verify callers against the new contract. Update relevant tests and examples; remove tests that protect only retired implementation details while retaining coverage of required behavior. Prefer a coordinated change for internal-only callers when feasible.
- For staged or external migrations, give adapters and deprecations an owner, observable removal condition, and next action. Retain compatibility where required, communicate changes through the appropriate channel, and provide rollback where warranted.
- Remove obsolete paths and unused dependencies once their removal conditions are verified. If safe removal cannot be proven, report the gap and do not claim it is finished. Use `principle-outcome-oriented-execution` for the overall transition when applicable.

## Boundaries and examples

- When simplifying a calculation without changing its contract, establish representative passing checks and refactor in focused steps; no caller migration plan is needed.
- When replacing a private helper used by three local callers, update all three and their tests together when feasible, then remove the unused old helper.
- For a public API with unknown downstream consumers, deleting the old endpoint immediately may break users. Plan and communicate a staged deprecation or retain the contract until removal is authorized and safe.
- Do not bypass repository protections, alter public contracts without appropriate approval, or remove security validation to simplify code. This principle does not start a managed workflow.
