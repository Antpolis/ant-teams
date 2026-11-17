---
name: principle-outcome-oriented-execution
description: Apply when planning or carrying out multi-step work, especially migrations and rewrites; drive toward a defined, verified outcome rather than treating intermediate activity as completion.
---

# Execute Toward the Outcome

## Trigger

Apply when work spans multiple steps, tasks, phases, or handoffs, especially when a migration or rewrite introduces transitional states. For a small self-contained change, identify and verify the outcome without inventing a multi-phase plan.

## Rule

Define what success looks like, then organize the work around reaching and verifying that end state. A completed task, a merged change, a passing intermediate check, or a smooth handoff is evidence of progress, not by itself proof of the requested outcome. Avoid preserving temporary states or adding compatibility machinery that does not serve users, safety, or a real rollout need.

## Apply

- Identify the desired user or system behavior, scope, constraints, and observable acceptance evidence. Map necessary work and genuine dependencies to that outcome; distinguish required work from approved deferrals.
- Break work into coherent, independently verifiable units where practical. Continue independently executable work while unrelated work is pending, without bypassing real dependencies or review gates. Reconcile integration and acceptance across the completed units.
- For a transition, identify current behavior and callers, the target state, phase boundaries, verification, rollout and recovery needs. Give temporary adapters, flags, and compatibility paths a removal condition and owner, or an explicit reason and owner for retaining them. Migrate callers and remove obsolete paths when safe; do not break supported users to make the end state look clean.
- Prefer the simplest safe route to the end state over maintaining unnecessary intermediate scaffolding. A temporary broken state is acceptable only within an isolated or explicitly authorized scope where impact, recovery, and affected users are understood. Do not infer permission to disrupt production, bypass protection, or discard security and data-integrity checks.
- Verify the integrated result against the intended outcome before reporting the work complete. Distinguish successful checks from pending or unavailable evidence and disclose approved deferrals or unresolved gaps. If the outcome changes, reconcile scope and obtain the decision from the appropriate owner rather than silently redefining success.

## Boundaries and examples

- When replacing an API over several tasks, agree on the new behavior, move callers in safe slices, verify integration, and remove the temporary adapter when its removal condition is met. If external clients still require it, explicitly record its owner and compatibility plan.
- When independent builders implement separate parts of a feature, individual merged PRs are progress. Verify the combined feature against acceptance before claiming the feature outcome is complete.
- For a typo fix, correct and inspect the text; a migration plan and additional tasks would not improve the outcome.

This principle guides execution judgment; it does not itself start or change a managed workflow, create GitHub artifacts, authorize additional scope, or replace existing role ownership, approval, review, and merge gates. Apply the currently selected playbook and workflow until they are explicitly changed.
