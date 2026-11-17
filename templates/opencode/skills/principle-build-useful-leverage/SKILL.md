---
name: principle-build-useful-leverage
description: Apply when repeated, error-prone, or hard-to-verify work could benefit from a script, generator, codemod, shared recipe, or reproducible check; choose proportionate automation that makes the work safer or easier to verify.
---

# Build Useful Leverage

## Trigger

Apply when performing edits, migrations, analysis, verification, or coordinated work where a small reusable tool or recipe could materially improve consistency, speed, or reproducibility.

## Rule

Prefer an existing or small, verifiable lever over repetitive manual work when its benefit outweighs its creation and maintenance cost. A rerunnable artifact can make both the change and its evidence easier to inspect; automation is not an end in itself.

## Apply

- Check for an existing tool first. Compare a focused script, codemod, generator, query, check, or shared delegate recipe with direct work; include one-off work when reproducibility provides meaningful value.
- Understand a representative case and the desired result before automating. Test on a small sample, inspect the diff or output, and check edge cases before expanding the scope.
- Make mutation tools safe to rerun where practical, limit their scope, and provide a preview or recovery path appropriate to the risk. Verify their results independently; automation can repeat mistakes quickly.
- Give parallel workers a consistent, stable recipe and verification contract when useful, with clear boundaries; a deterministic tool may eliminate unnecessary manual fan-out. Keep shared state and permissions protected.
- Keep a useful recurring lever in the appropriate source location when authorized; otherwise use a disposable artifact and report how the result was verified. Do not create a framework for a one-off need.

## Boundaries and examples

- For hundreds of similar API call sites, test a scoped codemod on a few examples, inspect the results, then run it and targeted checks across the remaining callers.
- For two obvious wording fixes, editing and inspecting the lines directly may be cheaper and clearer than writing a script.
- Do not automate destructive changes, expose secrets, bypass approvals, or commit generated tools without authorization. This principle does not require an artifact for every nontrivial task or start a managed workflow.
