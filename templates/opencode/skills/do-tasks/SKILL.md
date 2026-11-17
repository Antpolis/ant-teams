---
name: do-tasks
description: Drive an explicitly requested approved spec through its required GitHub issues, builder implementation, independent review, and tech-lead merge. Do not stop after one issue or pull another spec automatically.
disable-model-invocation: true
---

# Do Task

Ant Agent (`ant`) takes the orchestrator role for this queue pass. Read the `github-agentic-delivery-flow` skill and its Delivery Orchestration reference before executing the pass.

This procedure owns whole-spec execution requested through `/do-tasks`. The shared delivery-flow skill supplies conventions; reading it does not start this procedure.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use github-agentic-delivery-flow for the top-level GitHub operating model.
Use `github-conventions`, `github-agentic-delivery-flow/references/state-transitions.md`, `playbook-approval-or-escalation`, and `agent-communication-log` for GitHub workflow mechanics.
Use continue-delivery-queue whenever one issue reaches done, blocked, or another local stopping point and the orchestrator needs to decide whether the queue pass continues.
Use pr-review-flow when builder work is ready for reviewer review so the PR becomes the canonical review surface.
Use role-memory for durable cross-loop continuity.
Use principle-founder-escalation-preflight before asking the founder for a decision.

Apply `principle-make-state-changes-evidence-based`: `Open` and `Backlog` are Backlog; `Ready` (to do), `In Progress`, `Need attentions`, and `Blocked` are Progressing; `In Review` and `Ready to Merge` are Reviews; `Done` is Done. Category flow is forward except Reviews may return to Progressing. Review work that needs rework, attention, or blocker resolution returns to the appropriate Progressing status; satisfy the review-entry conditions again before returning to Reviews. The state-transition reference owns the detailed status gates and role ownership.

Bundled helpers for issue-isolated development live in:

- `$ANT_TEAM_SCRIPTS/create-task-branch.sh`
- `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh`

Use these helpers instead of inventing ad hoc `git worktree` commands. `tech-lead` owns creating or reusing the issue worktree and task branch before delegating new implementation to `builder`; `tech-lead` also owns post-merge cleanup. `ANT_TEAM_SCRIPTS` is installed and configured by `init-company.sh`.
These helpers load `ANT_TEAM_WORKTREE_ROOT` from `.github-project.env` themselves; invoke them directly rather than prefixing each call with `source ./.github-project.env &&`.

## Selected Spec and Run Scope

Resolve the selected canonical SPEC and milestone from the user's argument or an unambiguous existing execution context. A supplied issue can identify its parent spec; respect an explicit issue-only or otherwise narrowed request. If multiple specs are plausible or no spec is identified, ask which approved spec to execute before dispatching work. Do not choose a different spec because it has runnable issues.

Record the selected spec/milestone and scoped issue set in the queue plan and pass that scope to every delegate and continuation check. Every queue query, reconciliation, priority rule, readiness check, triage, and next-action decision below is limited to that scope. Outside issues may be read as dependency evidence; they are not execution candidates without an explicit scope change.

Before the first delegation of the pass, create a task list using the runtime task-list tool if available, otherwise maintain it in the local session-context note. Start with queue planning and reconciliation; populate scoped issues as they are discovered, before dispatching builders. Track each issue's scope, dependencies, assigned builder session, worktree, branch, PR, current stage, next responsible role, pending review/merge/CI or blockers, and completion/verification evidence. Update it at meaningful handoffs and reconcile against GitHub before dispatch and completion. This is a coordination aid only: GitHub remains authoritative for ownership, state, handoffs, approvals, and merges.

Continue through implementation, independent review, and tech-lead merge for every required scoped issue. One merged issue is a checkpoint, not completion. A blocked issue does not stop independent executable work in the same scope; record it and continue safely. If no scoped action remains, report the actual blocking decision or dependency.

## CI Timing For This Pass

CI is not a per-issue review or workflow merge gate: do not wait for pending CI to review, approve, merge, or start another independently executable issue. Keep the normal reviewer approval, tech-lead alignment, and focused local verification gates; investigate concrete correctness or security failures rather than ignoring them. Record pending or failing CI and continue safe independent work.

After all scoped implementation PRs have merged, verify the full CI suite against the final integrated production-base commit, record the commit, run link and result in the GitHub collaboration record, and resolve failures before reporting the pass complete or closing the spec. Re-run on the new final integrated commit after any fix. For a single-issue loop, perform this final CI check after its PR merges and before closing or marking the issue `Done`; a merged PR awaiting final CI is not yet `Done`. For a multi-issue loop, intermediate issues may be `Done` after their normal merge gates, while final integrated CI remains outstanding for the pass. Do not wait for spec closeout to discover or run this check.

For a single-issue loop, link the PR to the issue without GitHub closing keywords such as `Fixes #123` in the PR body or commits, so merge does not auto-close it before final CI. Before merging, check the PR and commits for closing references and other known auto-close automation; correct any under the responsible role. If external automation nevertheless closes it early, record the discrepancy, reopen the issue, and keep it out of `Done` until final CI passes. Do not pretend the check succeeded if CI is unavailable or fails.

If an actual GitHub branch protection or ruleset requires CI or code-scanning results before merge, report the exact rule, affected PR and check to the user, record it in GitHub, and continue independently executable work. Do not bypass or modify protections, claim the PR merged, or mark an unmerged issue `Done`. If no safe work remains, report the external merge restriction and its consequences; do not silently treat it as a workflow CI gate.

The run is complete when every required scoped issue is `Done` with the required merge or approved non-code completion evidence and no unresolved scope or acceptance gap remains. Deferred or removed work counts only when its explicit approved disposition is recorded in GitHub. An empty `Ready` queue alone does not prove completion.

Report final spec acceptance/verification evidence, issue disposition, PR/merge evidence, and remaining risks. Completion does not create a release/tag, close the milestone, select the next spec, or start shaping. Those actions require an explicit request.

## Issue Done Definition

An issue is done **only** when all of the following are true:

1. Builder has implemented the approved scope on the task branch and left a durable handover note.
2. Reviewer has reviewed, found no blockers, posted an explicit approval comment on the PR, and moved the issue to `Ready to Merge`.
3. Tech-lead has performed the final spec-alignment check, confirmed KISS, separation of concerns, and folder/package/namespace placement against architecture docs, merged the PR, posted a merge confirmation comment, and moved the issue to `Done` (after final integrated CI for a single-issue loop).

None of the following is sufficient on its own to treat an issue as done and move to the next:

- builder says implementation is complete
- code is pushed to the task branch
- PR is open
- reviewer approves and moves to `Ready to Merge`

The orchestrator must verify all three conditions before treating an issue as settled. Pending CI or a GitHub-enforced merge restriction must not stop independent scoped work from advancing.

## Core Rule

The `orchestrator` owns the queue pass and role-to-role control flow for execution.
The `tech-lead` establishes the ordered issue list, dependencies, execution priorities, technical interpretation, and guardrails once at queue-plan initialization for each pass.
`tech-lead` owns preparing the issue worktree and task branch before builder delegation, using the centralized helper for new work and reusing existing issue workspaces for continuation. `orchestrator` verifies that setup and records the location in the concise delegation. `builder` owns implementation, moving the issue into the correct implementation state, opening or updating the PR, and leaving a durable implementation handover note before `reviewer` takes over; builder must not create a competing workspace or branch during normal flow.

**Serialize builder ownership per issue.** Dispatch only one builder for an issue/worktree/branch at a time; do not launch a duplicate builder or reviewer while implementation, verification, or a task-owned background process is still active. A progress-only response is not completion. Require the same builder session to finish or explicitly reconcile its process, worktree, branch, PR head, and GitHub handoff before any continuation or role change. Parallel builders are permitted only for independent issues with separate tech-lead-provisioned worktrees/branches and no shared mutable resources.

For independent ready issues, Ant may dispatch multiple builders concurrently after tech-lead provisions each workspace and the task list records ownership. Respect capacity and real dependencies; assign one builder per issue. Track each session separately, and do not start its reviewer until that builder has finished and its PR and handoff are verified. Continue other safe work while a builder, review, merge, or CI check is in flight. Reconcile results and GitHub records as each finishes; tech-lead retains exclusive merge ownership and verifies integration against the current base. Worktree separation does not eliminate contract, merge, or shared-resource conflicts. Second-level delegation is not required: Ant may launch builders directly.

Do not require strategist confirmation for every issue.
Bring in `strategist` only when product intent, scope meaning, or execution meaning is unclear.
Bring in `tech-lead` when technical interpretation, sequencing, guardrails, or loop-breaker judgment is needed.

## Queue-Driven Flow

1. As the first workflow action of the pass, invoke `tech-lead` synchronously
   to inspect the selected spec’s GitHub issue queue and establish the ordered issue list,
   dependencies, current spec focus, active-work reconciliation, sequencing
   rationale, and execution guardrails. Wait for its completed final response
   and verify its required GitHub record before proceeding.
   Minimize and justify hard dependencies using `how-to-create-task`; identify independently executable work and do not add CI as an inter-issue prerequisite.
2. Inspect any issues in `Ready to Merge` and route them to `tech-lead` for
   the final spec-alignment check and merge decision. If merge cannot proceed because of an external CI-related rule, record and report it, then continue independent `Ready` work.
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
   - if the issue is in `Need attentions`: it is a founder decision state; verify from the founder-addressed GitHub comment that strategist and tech-lead review were both attempted, run `principle-founder-escalation-preflight`, and surface the founder decision
   - if review shows strategist or tech-lead resolution was actually still possible, route it back to that role, record the resolution in an issue comment, and move the issue to the appropriate Progressing status subject to its entry conditions
   - once the founder decides, record the decision in a GitHub issue comment and move to the appropriate Progressing status, or `Blocked` if the remaining problem is an external dependency or approval; satisfy review-entry conditions again before returning to review
   - if `builder` has questions about product intent or scope, invoke `strategist` as needed and record the discussion in GitHub comments
   - if `builder` has questions about technical direction or guardrails, invoke `tech-lead` and continue the pass after the answer
   - if progress is impeded, first route safe internal resolution to the responsible role. Move to `Blocked` only after tech-lead and strategist resolution has been attempted and a dependency, decision, credential, permission, or external condition still prevents safe progress; record the blocker and unblocking action in a GitHub issue comment and notify the user. Follow `github-agentic-delivery-flow/references/state-transitions.md`.
9. After reconciling active scoped issues, read the remaining selected-spec issues with their status, dependencies, prior comments, and linked docs.
10. Verify each issue belongs to the selected milestone and authorized scope; record discrepancies and ask tech-lead to resolve missing coverage or readiness gaps.
11. Use the tech-lead ordering to continue within the selected spec; do not dispatch another spec automatically.
12. If an issue is blocked, record its unblocking condition and continue another independently executable scoped issue. Work on an external dependency requires an explicit scope extension.
13. Process required scoped issues through implementation, review, and merge.
14. At each local stopping point, run `continue-delivery-queue` with the selected scope before ending the pass.
15. If no executable scoped issue remains, reconcile all required issues and acceptance coverage and verify final integrated CI as described above. Ask tech-lead to resolve incomplete scoped readiness or technical instructions, and strategist to clarify product acceptance when needed. If all required work is complete, report completion. Otherwise report the exact remaining blocker; do not triage unrelated repository work or start another spec.

## Empty Scoped Queue

An empty executable queue is a reconciliation point. Check scoped `Ready to Merge`, `In Progress`, `In Review`, `Need attentions`, `Ready`, and `Blocked` issues against their required evidence and dependency records. Resolve safe internal gaps within the selected spec before escalating. Check planned acceptance coverage for missing work through tech-lead.

If every required scoped issue is done with evidence, report completion. If required work remains and no safe scoped action is possible, apply `principle-founder-escalation-preflight` for a genuine founder decision or report the external dependency. Do not search for another spec or unrelated tasks merely to keep the pass running.

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
- before delegating new implementation, require `tech-lead` to create or reuse the issue worktree and task branch with `$ANT_TEAM_SCRIPTS/create-task-branch.sh`, then record the branch and worktree path in the GitHub issue; for continuation, tech-lead verifies and reuses the existing issue worktree and branch
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
- if `reviewer` approves with no blockers, `reviewer` posts an explicit approval comment on the PR and moves the issue to `Ready to Merge`. This comment is the workflow's approval record; do not require GitHub's native review state for this gate.
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
- if the check passes: `tech-lead` merges the PR, posts a merge confirmation comment on the PR, and moves the issue to `Done` (for a single-issue loop, only after final integrated CI passes). The reviewer approval comment plus the passed tech-lead check authorize this workflow merge; do not wait for CI or a GitHub-native `APPROVED` review state unless repository rules explicitly require one.
- If `pr-merge` is rejected by GitHub, inspect the actual error and PR checks/rules. Do not claim that the approval comment is a native approval or repeatedly retry. If a repository rule specifically requires a native approval from a distinct account, this workflow cannot satisfy that rule with the same account: record the exact blocker in the PR and issue, move the issue to `Blocked`, and notify the user to provide an authorized reviewer or change the repository rule. Otherwise resolve the reported failing check or permission issue and continue.
- if the check fails: `tech-lead` posts the code-specific findings and rework reasoning in PR comments, with a concise issue-comment summary; builder picks the findings up on the same branch and the review loop continues through `In Progress` and `In Review`; `tech-lead` moves the issue to `Need attentions` only when a founder decision is required before the findings can be addressed
- a tech-lead final check failure that results in builder rework counts as a continuation of the same review loop — the 8-loop cap applies across all review passes for the issue including those triggered by tech-lead findings. At the cap, apply `principle-break-unproductive-loops` and use `playbook-approval-or-escalation` for the loop-breaker decision. Escalate to the founder only if a genuine founder-owned decision remains after the required preflight.
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

## Role And Continuity Rules

Follow `github-agentic-delivery-flow` and its specialist references for role ownership, review, workspace continuity, recovery, and cleanup. Do not perform another role's normal mutation merely because tools permit it; record a necessary recovery exception. Keep the queue-specific gates, synchronous handoffs, and orchestrator verification in this procedure.

After merge or explicit task closure, `tech-lead` cleans up the issue worktree and local branch using `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh` once they are no longer needed for review, rollback, or follow-up fixes.

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

Do not require a native GitHub approval review as an additional workflow artifact. Native approval is only an external repository-rule requirement, which must be verified from GitHub's actual merge-block reason.

**Before treating an issue as `Done`** — verify these tech-lead artifacts exist:

- tech-lead merge confirmation comment on the PR
- PR merged to the production base branch
- issue state moved to `Done` by tech-lead

If any artifact is missing at any gate, do not advance. Send the issue back to the role that owns that artifact. Do not silently complete those actions on another role's behalf.

During `do-tasks`, also verify continuity:

- tech-lead provided the issue worktree and task branch before builder started; existing worktree, branch, and PR were reused for continuation
- builder used the supplied worktree and branch and updated the existing PR when one already existed
- any replacement worktree, branch, or PR was provisioned by tech-lead with an explicit GitHub recovery note explaining why continuity was not possible
