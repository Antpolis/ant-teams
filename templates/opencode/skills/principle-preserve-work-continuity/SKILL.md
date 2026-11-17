---
name: principle-preserve-work-continuity
description: Apply when resuming or handing off existing work; preserve usable artifacts, decisions, evidence, and history instead of restarting unnecessarily.
---

# Preserve Work Continuity

## Trigger

Apply when continuing, transferring, or recovering work that already has an artifact, workspace, decision history, or review in progress.

## Rule

Continue from the existing usable work and preserve context needed by the next person. Replace or restart only when it is safer or necessary, and explain the reason and what must be carried forward. Continuity avoids lost work and repeated decisions; it is not a reason to preserve a broken or unsafe state.

## Apply

- Inspect the current artifact, relevant state, decisions, outstanding feedback, and user changes before proceeding. Do not overwrite or discard unrelated work.
- Reuse the existing document, branch, workspace, or review where appropriate and safe. Carry forward the decision, rationale, constraints, evidence, unresolved questions, and next action using `principle-protect-context` and `principle-concise-actionable-communication` when relevant.
- If the existing state is unusable, stale, unsafe, or cannot be recovered within the authorized scope, explain the reason, preserve accessible history, and use the appropriate owner and recovery process. Avoid destructive cleanup without authorization.
- Check that prior assumptions and evidence are still current; preserving history does not mean blindly repeating an obsolete decision. In managed work, keep the selected workflow's workspace ownership, canonical records, review, and merge gates.

## Boundaries and examples

- Continue a review on the existing PR and address its feedback rather than opening a replacement solely for convenience. If the PR cannot safely be recovered, explain the replacement and link its prior review history where accessible.
- If a local scratch file is disposable and has no useful history, creating a fresh one may be simpler; continuity does not require preserving every temporary artifact.
- This principle does not authorize reusing compromised state, overriding role ownership, or starting a managed workflow.
