---
name: principle-defer-only-when-safe
description: Apply when considering postponing a known issue, improvement, or unfinished work; assess whether the current outcome remains complete and safe and make residual risk and follow-up explicit.
---

# Defer Only When Safe

## Trigger

Apply when a real concern is proposed for later rather than resolved in the current work, including after review or during a staged transition.

## Rule

Defer only when the remaining deliverable satisfies its required outcome and can be used safely without the deferred work. Make the residual risk, responsible owner, and follow-up condition visible; obtain the decision from the appropriate authority.

## Apply

- Determine whether the concern is required for acceptance, security, data integrity, compatibility, or a binding approval. A preference or optional improvement is not automatically a blocker; an unmet requirement cannot be silently relabeled as optional.
- Assess the impact of postponement and identify the owner, next action, and observable trigger or time for reconsideration in the appropriate record. Be honest if ownership or a safe follow-up path is unknown.
- When scope or acceptance must change to allow deferral, obtain the decision from its owner and update the applicable records. Preserve any independent review, approval, and workflow gates.
- Do not create a tracking artifact for every minor suggestion, but do not hide a material known risk because a formal task seems inconvenient.

## Boundaries and examples

- A nonessential performance improvement can be deferred if the delivered feature meets agreed limits and the known scaling threshold and owner are recorded.
- A missing authorization check cannot be deferred simply to merge sooner. Address it or obtain a properly authorized scope change and safe containment before proceeding.
- This principle does not authorize changing acceptance, creating GitHub issues, bypassing protections, or starting a managed workflow.
