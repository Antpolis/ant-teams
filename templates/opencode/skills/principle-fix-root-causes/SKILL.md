---
name: principle-fix-root-causes
description: Apply when investigating a defect, recurring failure, or unexpected behavior; use evidence to identify and address the cause rather than merely hiding its symptoms.
---

# Fix Root Causes

## Trigger

Apply when debugging a failure or recurring unexpected behavior. Scale the investigation to the impact, available evidence, and scope of the requested fix.

## Rule

Trace the observed symptom to the cause supported by evidence and address it at the appropriate level. A guard or workaround that hides an error without resolving the underlying defect can leave the failure to recur elsewhere.

## Apply

- Reproduce the failure and establish expected behavior when practical; capture a failing test or other observable evidence. If reproduction is unavailable, gather the strongest safe evidence and clearly distinguish a hypothesis from a verified cause.
- Follow the data, control flow, and relevant state; ask why the failure occurred until the actionable cause is supported. Inspect errors and add focused instrumentation when needed rather than guessing. For restart-only failures, consider persisted configuration, caches, locks, and serialized state alongside code.
- Fix the cause within the authorized scope, and check nearby instances of the same failure pattern where relevant. Avoid automatically expanding the change to every similar-looking case without evidence or authorization.
- Verify the reported behavior and add a proportionate regression check where practical. If the underlying cause cannot safely be fixed now, distinguish containment from a fix, report residual risk, and propose an owner and next step.

## Boundaries and examples

- If a crash comes from invalid persisted state, investigate how it became invalid and correct the source or recovery contract; merely suppressing the exception does not establish a fix. Validation or defensive handling may still be necessary at the boundary.
- During an incident, a safe temporary guard can reduce harm while diagnosis continues. Label it as containment and verify it does not hide security or data-integrity failures.
- Do not delete user state, expose sensitive logs, or alter production without authorization. If a cause cannot be reproduced or proven, report that limitation rather than claiming certainty.
