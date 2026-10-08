---
name: do-task
description: Drive an explicitly requested approved spec through its required GitHub issues, builder implementation, independent review, and tech-lead merge. Do not stop after one issue or pull another spec automatically.
disable-model-invocation: true
---

# Do Task

Ant Agent (`ant`) takes the orchestrator role for this queue pass. Read the `github-agentic-delivery-flow` skill and its Delivery Orchestration reference before executing the pass.

This procedure owns whole-spec execution requested through `/do-tasks`. The shared delivery-flow skill supplies conventions; reading it does not start this procedure.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use github-agentic-delivery-flow for the top-level GitHub operating model.
Use github-conventions, state-transitions, approval-or-escalation, and agent-communication-log for GitHub workflow mechanics.
Use continue-delivery-queue whenever one issue reaches done, blocked, or another local stopping point and the orchestrator needs to decide whether the queue pass continues.
Use pr-review-flow when builder work is ready for reviewer review so the PR becomes the canonical review surface.
Use role-memory for durable cross-loop continuity.
Use founder-escalation-preflight before asking the founder for a decision.

Bundled helpers for issue-isolated development live in:

- `$ANT_TEAM_SCRIPTS/gh_project_helper.sh create-task-branch`
- `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh`

Use these helpers instead of inventing ad hoc `git worktree` commands. `tech-lead` owns creating or reusing the issue worktree and task branch before delegating new implementation to `builder`; `tech-lead` also owns post-merge cleanup. `ANT_TEAM_SCRIPTS` is installed and configured by `init-company.sh`.
These helpers load `ANT_TEAM_WORKTREE_ROOT` from `.github-project.env` themselves; invoke them directly rather than prefixing each call with `source ./.github-project.env &&`.

## Selected Spec and Run Scope

Resolve the selected canonical SPEC and milestone from the user's argument or an unambiguous existing execution context. A supplied issue can identify its parent spec; respect an explicit issue-only or otherwise narrowed request. If multiple specs are plausible or no spec is identified, ask which approved spec to execute before dispatching work. Do not choose a different spec because it has runnable issues.

Record the selected spec/milestone and scoped issue set in the queue plan and pass that scope to every delegate and continuation check. Every queue query, reconciliation, priority rule, readiness check, triage, and next-action decision below is limited to that scope. Outside issues may be read as dependency evidence; they are not execution candidates without an explicit scope change.

Continue through implementation, independent review, and tech-lead merge for every required scoped issue. One merged issue is a checkpoint, not completion. A blocked issue does not stop independent executable work in the same scope; record it and continue safely. If no scoped action remains, report the actual blocking decision or dependency.

The run is complete when every required scoped issue is `Done` with the required merge or approved non-code completion evidence and no unresolved scope or acceptance gap remains. Deferred or removed work counts only when its explicit approved disposition is recorded in GitHub. An empty `Ready` queue alone does not prove completion.

Report final spec acceptance/verification evidence, issue disposition, PR/merge evidence, and remaining risks. Completion does not create a release/tag, close the milestone, select the next spec, or start shaping. Those actions require an explicit request.

## Issue Done Definition

An issue is done **only** when all of the following are true:

1. Builder has implemented the approved scope on the task branch and left a durable handover note.
2. Reviewer has reviewed, found no blockers, posted an explicit approval comment on the PR, and moved the issue to `Ready to Merge`.
3. Tech-lead has performed the final spec-alignment check, confirmed KISS, separation of concerns, and folder/package/namespace placement against architecture docs, merged the PR, posted a merge confirmation comment, and moved the issue to `Done`.

None of the following is sufficient on its own to treat an issue as done and move to the next:

- builder says implementation is complete
- code is pushed to the task branch
- PR is open
- reviewer approves and moves to `Ready to Merge`

The orchestrator must verify all three conditions are met before treating an issue as settled and advancing the queue.

## Core Rule

The `orchestrator` owns the queue pass and role-to-role control flow for execution.
The `tech-lead` establishes the ordered issue list, dependencies, execution priorities, technical interpretation, and guardrails once at queue-plan initialization for each pass.
`tech-lead` owns preparing the issue worktree and task branch before builder delegation, using the centralized helper for new work and reusing existing issue workspaces for continuation. `orchestrator` verifies that setup and records the location in the concise delegation. `builder` owns implementation, moving the issue into the correct implementation state, opening or updating the PR, and leaving a durable implementation handover note before `reviewer` takes over; builder must not create a competing workspace or branch during normal flow.

Do not require strategist confirmation for every issue.
Bring in `strategist` only when product intent, scope meaning, or execution meaning is unclear.
Bring in `tech-lead` when technical interpretation, sequencing, guardrails, or loop-breaker judgment is needed.

## Queue-Driven Flow

1. As the first workflow action of the pass, invoke `tech-lead` synchronously
   to inspect the selected spec’s GitHub issue queue and establish the ordered issue list,
   dependencies, current spec focus, active-work reconciliation, sequencing
   rationale, and execution guardrails. Wait for its completed final response
   and verify its required GitHub record before proceeding.
2. Inspect any issues in `Ready to Merge` and route them to `tech-lead` for
   the final spec-alignment check and merge decision. Do not pull fresh
   `Ready` work while a `Ready to Merge` issue is waiting.
3. Inspect any issues already in `In Progress`.
4. Inspect any issues already in `In Review` before pulling fresh work so
   reviewer-gated work does not stall behind new execution.
5. Inspect any issues in `Need attentions` before pulling fresh `Ready`
   work — `Need attentions` is founder-only, so confirm strategist and
   tech-lead review were both attempted, then follow step 8 routing rules
   for any genuine founder decision.
6. Use the completed initialization consultation as the queue plan for this
   pass; do not repeat it for routine ordering between issues.
7. Treat that order as the initial plan, not authority over the live GitHub Collaboration Record. Before each action, reconcile planned issues against current Workflow State, linked PR and required artifacts, dependencies, and recent comments. The live state and workflow gates determine executability. If evidence conflicts with the plan, do not silently transition, skip, or reorder: record the discrepancy in the canonical GitHub location; route state/ownership issues by the current state; ask tech-lead to resolve conflicts affecting technical sequencing or priority, and strategist to resolve product/scope meaning. Continue with another independently executable issue only if this does not violate dependency or spec-group priority. Refresh the plan for a blocker or changed dependency/scope, stale or conflicting issue instructions, plan-versus-board discrepancy affecting priority, loop-breaker, or exhausted executable queue. No routine tech-lead consultation is needed when plan and live evidence agree.
8. For each active issue in `Ready to Merge`, `In Progress`, `In Review`, or `Need attentions`:
   - if the issue is in `Ready to Merge`: route to `tech-lead` for final check and merge (see Tech-Lead Merge Gate)
   - if the issue is `In Progress`: review with `builder` whether implementation is done or still in flight; if done, verify builder left the required handover note and PR linkage, then delegate `reviewer`
   - if the issue is `In Review`: delegate `reviewer` before pulling fresh queue work
   - if the issue is in `Need attentions`: it is a founder decision state; verify from the founder-addressed GitHub comment that strategist and tech-lead review were both attempted, run `founder-escalation-preflight`, and surface the founder decision
   - if review shows strategist or tech-lead resolution was actually still possible, route it back to that role, record the resolution in an issue comment, and return the issue to its prior state (`Ready`, `In Review`, or `Backlog`)
   - once the founder decides, record the decision in a GitHub issue comment and return the issue to its prior state, or move to `Blocked` if the remaining problem is an external dependency or approval
   - if `builder` has questions about product intent or scope, invoke `strategist` as needed and record the discussion in GitHub comments
   - if `builder` has questions about technical direction or guardrails, invoke `tech-lead` and continue the pass after the answer
   - if the issue is blocked for any reason, move it to `Blocked`, add a GitHub comment explaining the blocker, and notify the user
9. After reconciling active scoped issues, read the remaining selected-spec issues with their status, dependencies, prior comments, and linked docs.
10. Verify each issue belongs to the selected milestone and authorized scope; record discrepancies and ask tech-lead to resolve missing coverage or readiness gaps.
11. Use the tech-lead ordering to continue within the selected spec; do not dispatch another spec automatically.
12. If an issue is blocked, record its unblocking condition and continue another independently executable scoped issue. Work on an external dependency requires an explicit scope extension.
13. Process required scoped issues through implementation, review, and merge.
14. At each local stopping point, run `continue-delivery-queue` with the selected scope before ending the pass.
15. If no executable scoped issue remains, reconcile all required issues and acceptance coverage. Ask tech-lead to resolve incomplete scoped readiness or technical instructions, and strategist to clarify product acceptance when needed. If all required work is complete, report completion. Otherwise report the exact remaining blocker; do not triage unrelated repository work or start another spec.

## Empty Scoped Queue

An empty executable queue is a reconciliation point. Check scoped `Ready to Merge`, `In Progress`, `In Review`, `Need attentions`, `Ready`, and `Blocked` issues against their required evidence and dependency records. Resolve safe internal gaps within the selected spec before escalating. Check planned acceptance coverage for missing work through tech-lead.

If every required scoped issue is done with evidence, report completion. If required work remains and no safe scoped action is possible, apply `founder-escalation-preflight` for a genuine founder decision or report the external dependency. Do not search for another spec or unrelated tasks merely to keep the pass running.

## Per-Issue Rules

For each issue:

- confirm the issue is genuinely builder-ready for spec-based delivery: require bounded scope, non-goals, acceptance criteria, dependencies, verification, owner, its milestone, and a `Durable Context` section with the exact canonical SPEC and every applicable ARCH, ADR, GOV, and runbook URL. Standalone defect playbooks own their issue readiness and execution; do not pull their issues into this spec queue.
- read the issue first, then open every Durable Context URL; do not reconstruct requirements from chat or perform a broad vault search
- if a required URL is missing, ambiguous, stale, or conflicts with the issue, do not invoke builder; request tech-lead clarification in a GitHub issue comment and keep the issue out of `Ready`
- if product intent, scope meaning, or execution meaning is unclear, clear it with `strategist`
- if technical interpretation, sequencing, or guardrails are unclear, resolve them with `tech-lead`
- record one concise handoff at each meaningful role boundary or state change in the canonical location: issue/milestone comment for task ownership, scope, dependencies, clarification, blockers, escalation, or state changes; PR description for builder-to-reviewer implementation handoff; PR comments/review threads for code-specific findings, rework, responses, approval, and merge reasoning
- do not add a separate issue comment when the canonical PR record already captures the handoff and issue ownership/state did not change; use the `agent-communication-log` handoff template, keeping only receiver-needed context and links
- if the issue has a blocker or needs human intervention, record the blocker and required unblocking action in a GitHub issue comment and skip to the next executable issue
- if the issue needs strategist or tech-lead resolution before safe execution can continue, request and record that resolution in an issue comment and keep the issue in its current state; `Need attentions` is reserved for founder decisions after both reviews were attempted
- once the technical requirement is clear, invoke `builder` and record that delegation in GitHub
- before delegating new implementation, require `tech-lead` to create or reuse the issue worktree and task branch with `$ANT_TEAM_SCRIPTS/gh_project_helper.sh create-task-branch`, then record the branch and worktree path in the GitHub issue; for continuation, tech-lead verifies and reuses the existing issue worktree and branch
- `orchestrator` verifies the setup and includes the worktree path and branch in the builder runtime delegation
- `builder` owns implementation-state transitions, PR creation or update, and the builder handover note; builder verifies the supplied worktree and branch and stops to route any mismatch or unusable workspace to tech-lead rather than silently creating replacements
- do not let orchestrator or builder create the issue worktree or task branch in normal flow; tech-lead alone owns setup, while tech-lead also owns cleanup after merge

## Builder And Reviewer Gate

- `builder` works from the assigned GitHub issue first, then its exact Durable Context links, approved guardrails, and the shared build-review loop; the linked canonical SPEC is authoritative for this planned delivery slice
- before `builder` starts, `tech-lead` must create or verify the issue worktree and task branch and record their path/name in GitHub. Builder verifies and uses the supplied workspace and branch, then moves the issue into `In Progress`. If the supplied workspace or branch is missing, mismatched, or unusable, builder stops and routes the problem to tech-lead; builder must not create replacements.
- after `builder` finishes implementation, `builder` must create or update the PR, move the issue into `In Review`, and leave a durable handover note in the issue or PR before `reviewer` review starts
- builder-reviewer communication, findings, rework reasoning, and approvals must be recorded in PR comments or review threads; use issue comments for concise task-state summaries
- `orchestrator` verifies tech-lead's worktree and branch setup before builder delegation, then checks that the PR, state change, and handover note exist before delegating `reviewer`
- after the PR is ready, `reviewer` must review before the issue advances
- if `reviewer` finds issues, `reviewer` returns the issue to `builder` in the same worktree and on the same branch and continues the loop through durable review findings
- if `reviewer` approves with no blockers, `reviewer` posts an explicit approval comment on the PR and moves the issue to `Ready to Merge`
- builder completion is not final completion; reviewer approval is not final completion

## Optional Ponytail Simplification Passes

The repository ships optional Ponytail skills: `ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-debt`, and `ponytail-gain`. They are optional aids and never override correctness, security, architecture guardrails, required tests, role ownership, GitHub audit records, review gates, or merge approval. They add no new required state or approval gate, and they do not change any gate in this skill.

- Before completing implementation, `builder` may run the core ponytail self-check for minimal-diff simplicity. This is additive: one focused executable check remains required for non-trivial changes. Mark meaningful deliberate simplifications with a `ponytail:` code marker naming the ceiling and upgrade trigger.
- During the review pass, normal correctness/architecture/security review stays authoritative. `reviewer` may additionally run `ponytail-review` as a separate complexity-only pass; its findings are actionable only when they do not conflict with the issue's requirements or tech-lead guardrails.
- The tech-lead merge gate is unchanged: no ponytail finding by itself blocks or accelerates merge approval.
- When a ponytail invocation affects an existing task or decision, record the invocation and outcome in the normal issue/PR comments; standalone informational runs need no new record. One-shot skills stay one-shot.

## Tech-Lead Merge Gate

- every issue in `Ready to Merge` must be routed to `tech-lead` by `orchestrator` before it is considered done
- `tech-lead` reads the linked central Obsidian project documentation, GitHub issue, and PR diff to verify that implementation matches approved scope and satisfies architecture guardrails (KISS, separation of concerns, folder/package/namespace)
- if the check passes: `tech-lead` merges the PR, moves the issue to `Done`, and posts a merge confirmation comment on the PR
- if the check fails: `tech-lead` posts the code-specific findings and rework reasoning in PR comments, with a concise issue-comment summary; builder picks the findings up on the same branch and the review loop continues through `In Progress` and `In Review`; `tech-lead` moves the issue to `Need attentions` only when a founder decision is required before the findings can be addressed
- a tech-lead final check failure that results in builder rework counts as a continuation of the same review loop — the 8-loop cap applies across all review passes for the issue including those triggered by tech-lead findings; if the cap is hit, treat it as a loop-breaker and escalate to founder
- `tech-lead` is the only role that merges; no other role may merge without an explicit recovery exception recorded in GitHub
- an issue is `Done` only after `tech-lead` has merged the PR following a passed final check

## GitHub Audit Rules

- GitHub Issues are the canonical execution tasks
- GitHub Project status is the canonical workflow board
- GitHub issue comments are the canonical delegation, clarification, blocker, founder-request, and task-status record
- PR comments and review threads are the canonical code-review, rework, approval, and merge-reasoning record
- the central Obsidian project folder may be linked for durable specs, architecture, ADRs, GOV, runbooks, and exceptional decisions; it is not a routine event log
- repository files are canonical only for code-adjacent implementation guidance

## Delegation Rule

- for internal role-to-role work, always delegate when the next safe role is clear
- when `builder`, `reviewer`, or `strategist` is available in this runtime, invoke that role now in the same execution pass instead of stopping at a recorded handoff
- if the current role can delegate to itself under another role context, do that rather than narrating what should happen next
- do not stop after only posting a GitHub comment if `strategist`, `builder`, or `reviewer` can be invoked now
- reserve the word `handoff` for founder-facing return, escalation, or final control transfer

Dependent role delegations are synchronous. Wait for the current agent to
finish and return its final response, then verify its required GitHub records
before invoking any dependent role. A posted handoff, workflow-state change,
or launch acknowledgement alone is not agent completion. An interrupted or
failed invocation does not satisfy this gate; reconcile its outcome before
proceeding. “Invoke now” and “continue in the same execution pass” mean after
these checks, never while the prerequisite role is still running.

## Ownership Rules

- `orchestrator` owns queue selection, cross-role coordination, and verification that required GitHub artifacts exist.
- `strategist` owns product framing, scope clarity, success criteria, and product-level resolution of ambiguous work.
- `tech-lead` owns technical interpretation, architecture guardrails, sequencing, loop-breaker technical decisions, verifying `Need attentions` founder-decision readiness (routing back to `strategist` when internal resolution is still possible), creating or reusing the issue worktree and task branch before builder delegation, recording their path/name in GitHub, the final spec-alignment check, the merge decision, the transition from `Ready to Merge` to `Done`, and post-merge cleanup.
- `builder` owns implementation, implementation-state transitions into active work and review, PR creation or update, and the builder handover comment in the issue or PR.
- `reviewer` owns review findings, review approvals, return-to-builder decisions, reviewer verification notes, and the transition from `In Review` to `Ready to Merge` on approval or back to `In Progress` on findings. Reviewer does not merge and does not move issues to `Done`.
- A role should not perform another role's normal workflow mutation just because it has tool access. If recovery is necessary, record why the usual owner could not perform the action.

## Development Loop Ownership Rules

- `builder` must not treat "code pushed" as equivalent to "ready for review"; review starts only after the PR and handover artifacts exist.
- before delegating implementation, `tech-lead` creates a dedicated issue worktree and task branch for new work; for continuation, tech-lead verifies and reuses the existing worktree, branch, and PR
- `builder` implements in the workspace and branch supplied by tech-lead and updates the existing PR when one exists; builder must not create a fresh worktree, branch, or replacement PR during normal continuation
- if the existing worktree, branch, or PR is unusable, builder stops and reports the issue to tech-lead; tech-lead records the recovery reason and old/new artifact links in GitHub before provisioning replacements
- after merge or explicit task closure, `tech-lead` cleans up the issue worktree and local branch with `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh` once they are no longer needed for review, rollback, or follow-up fixes
- `reviewer` must not silently fix builder work as a substitute for findings unless the workflow explicitly assigns reviewer implementation for a special recovery case.
- `orchestrator` should not close the loop based on verbal assurances; it should verify the branch, PR, state, and comments.
- `strategist` and `tech-lead` should resolve ambiguity with durable guidance, then return execution to `builder` or `reviewer` rather than carrying the implementation loop themselves.

## Required Delegation Content

Record each meaningful delegation using the `agent-communication-log` `## Delegation` template in the GitHub issue or PR location where the receiver acts. Follow `github-agentic-delivery-flow/references/context-relay.md` for the direct runtime instruction. Read and consolidate the upstream role's completed findings, accepted decisions and rationale, user corrections, and unresolved questions. Send that actionable summary with exact issue/PR and handoff links, applicable durable-context URLs, execution context, verification expectations, and expected record.

Before builder delegation, relay tech-lead's selected approach, architecture decisions and rationale, guardrails, dependencies, acceptance/verification expectations, and readiness record alongside the worktree and branch. Before reviewer delegation, relay builder's implementation summary, checks and evidence, deviations, risks, and exact PR/head. Return reviewer findings and resolved technical/product answers to builder explicitly; do not assume sibling memory.

Keep briefs concise by omitting full transcripts and document copies, not by omitting consequential decisions or context.
Use placement deliberately:

- strategist ↔ tech-lead planning, tech-lead → builder, and any task-level clarification: issue or milestone comment;
- builder → reviewer implementation handoff: PR description;
- reviewer → builder code rework: PR review thread/comment;
- builder/reviewer → strategist or tech-lead ambiguity: issue comment.

Do not paste entire specs or chat transcripts into a delegation. The issue and its `Durable Context` URLs are the authoritative navigation path.

## Stop And Skip Rules

- if an issue needs human intervention, record it and skip to the next executable issue
- if an active issue is blocked after tech-lead and strategist resolution was attempted, move it to `Blocked`, add a concise GitHub issue comment stating the blocker and required unblocking action, and notify the user
- if a spec is too unclear to proceed safely, record the clarification need in GitHub before pausing or switching
- if the scoped executable queue is empty, reconcile required scoped work and evidence before deciding completion or blockage
- do not start a new spec or broaden execution without an explicit user request

## Orchestrator Verification Rule

**Before involving `reviewer`** — verify these builder artifacts exist:

- issue worktree path and task branch linked or named in the issue or PR
- issue state moved to `In Review` by builder
- PR opened or updated for the current implementation
- durable builder handover note with enough detail for review to continue without chat context

**Before routing to `tech-lead` for merge** — verify these reviewer artifacts exist:

- explicit reviewer approval comment on the PR stating no blockers remain
- issue state moved to `Ready to Merge` by reviewer

**Before treating an issue as `Done`** — verify these tech-lead artifacts exist:

- tech-lead merge confirmation comment on the PR
- PR merged to the production base branch
- issue state moved to `Done` by tech-lead

If any artifact is missing at any gate, do not advance. Send the issue back to the role that owns that artifact. Do not silently complete those actions on another role's behalf.

During `do-tasks`, also verify continuity:

- tech-lead provided the issue worktree and task branch before builder started; existing worktree, branch, and PR were reused for continuation
- builder used the supplied worktree and branch and updated the existing PR when one already existed
- any replacement worktree, branch, or PR was provisioned by tech-lead with an explicit GitHub recovery note explaining why continuity was not possible
