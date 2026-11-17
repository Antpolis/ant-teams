---
name: principle-review-by-impact
description: Apply when reviewing a change, artifact, or decision; ground findings and severity in evidence and practical impact, separating required corrections from preferences.
---

# Review by Impact

## Trigger

Apply when evaluating work or deciding whether a concern needs correction before acceptance. Match investigation depth to the change, risk, and review scope.

## Rule

Base findings on observable evidence, a plausible concrete impact, and the applicable requirements. Treat smells and preferences as prompts to investigate, not automatic defects; do not dismiss a genuine risk merely because it is difficult to reproduce.

## Apply

- Inspect the relevant change and connected behavior, contracts, and project constraints. Verify a suspected problem when practical; distinguish demonstrated failures from credible risks and unanswered questions.
- Match review independence to the consequences, uncertainty, and applicable requirements. An author can self-check low-risk work, but an independent reviewer should assess consequential changes when needed to reduce blind spots; honor any mandatory independent-review gate. Do not represent the author's self-check as independent approval.
- For each material finding, identify where it occurs, the conditions and impact, appropriate severity, and a practical correction. State uncertainty and verification limitations rather than claiming evidence that is absent.
- Distinguish required corrections, non-blocking suggestions, and unresolved decisions. State the review disposition within the reviewer's authority and applicable approval gates; do not present an unresolved decision as approval.
- Require correction for demonstrated or credible material correctness, safety, security, scope, or binding-constraint problems under the applicable review rules. Mark optional improvements and subjective preferences as such; a single caller or an unfamiliar layout alone is not proof of a defect.
- Report meaningful gaps in verification even when no defect is proven. Preserve mandated approvals, independent review, and merge gates; do not treat this principle as permission to approve or block outside the reviewer's authority.

## Boundaries and examples

- A new helper with one caller is not automatically a blocker. If it hides authorization checks and creates a concrete security risk, explain the path and required correction.
- A plausible data-loss scenario can warrant a finding even if production reproduction would be unsafe; describe the evidence, assumptions, and safer way to verify it.
- A typo fix may need only the author's inspection, while a high-risk authorization change may warrant an independent security review. Existing mandatory review rules take precedence in either case.
- This principle guides judgment and communication, not a review procedure, severity policy, or managed workflow activation.
