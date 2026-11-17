---
name: principle-break-unproductive-loops
description: Apply when review, debugging, negotiation, or implementation repeatedly revisits the same problem without meaningful progress; diagnose the constraint and choose a different path.
---

# Break Unproductive Loops

## Trigger

Apply when repeated attempts or disagreements do not reduce uncertainty, resolve findings, or advance the intended outcome. A normal correction and recheck is not by itself an unproductive loop.

## Rule

Pause repetition and identify the underlying disagreement or constraint. Use evidence to choose a different feasible path, such as clarifying the requirement, changing the approach, obtaining an appropriate decision, or safely deferring a separable concern.

## Apply

- Summarize the recurring issue, attempts, evidence, and what remains unresolved. Distinguish a repeated symptom from an underlying product, technical, or authority question.
- Involve the person with the appropriate expertise or decision authority when needed. Offer a concrete question, viable options, recommendation, and next action rather than repeatedly asking for a generic review.
- Preserve required acceptance, safety, and approval gates. Apply `principle-defer-only-when-safe` if considering a deferral; explicitly record consequential decisions and rationale in the applicable record.
- Follow any existing workflow threshold and role-specific procedure. This principle does not establish a universal number of attempts or activate managed delivery.

## Boundaries and examples

- If review repeatedly rejects the same architecture, reconcile the relevant requirement and evidence with the responsible technical owner before another implementation pass.
- One failed test followed by a clear correction is ordinary progress; stopping for a formal loop-breaker would add friction.
- Do not approve a known blocking defect merely to end a loop, or involve a founder who cannot resolve the actual constraint.
