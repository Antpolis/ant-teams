---
name: do-task
description: Use when the orchestrator should drive execution from the GitHub project queue, invoke tech-lead for technical interpretation, invoke builder for implementation, and require reviewer review before any issue is treated as done.
---

# Do Task

Use this skill whenever execution should start from the current GitHub project issue queue rather than from a single already-picked task.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use github-agentic-delivery-flow for the top-level GitHub operating model.
Use github-conventions, state-transitions, approval-or-escalation, and agent-communication-log for GitHub workflow mechanics.
Use orchestrator-task-done whenever one issue reaches done, blocked, or another local stopping point and the orchestrator needs to decide whether the queue pass continues.
Use pr-review-flow when builder work is ready for reviewer review so the PR becomes the canonical review surface.
Use role-memory for durable cross-loop continuity.
Use founder-escalation-preflight before asking the founder for a decision.

Bundled helpers for issue-isolated development live in:

- `scripts/create_task_worktree.sh`
- `scripts/cleanup_task_worktree.sh`

Use these helpers instead of inventing ad hoc `git worktree` commands when the builder needs to start or clean up issue workspaces.
These helpers read the default issue-worktree root from top-level `worktreeRoot` in `.github-project.json` when it is present.

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
The `tech-lead` provides the ordered issue list, execution priorities, technical interpretation, and guardrails for each pass.
The delegated execution roles own their own workflow side effects. Once `builder` takes an issue, `builder` is responsible for creating or switching to the issue worktree and task branch, moving the issue into the correct implementation state, opening or updating the PR, and leaving a durable implementation handover note before `reviewer` takes over. `orchestrator` should coordinate and verify those handoff artifacts exist, not perform them on behalf of delegated agents.

Do not require strategist confirmation for every issue.
Bring in `strategist` only when product intent, scope meaning, or execution meaning is unclear.
Bring in `tech-lead` when technical interpretation, sequencing, guardrails, or loop-breaker judgment is needed.

## Queue-Driven Flow

1. Start from the GitHub project issue queue.
2. First inspect any issues in `Ready to Merge` and route them immediately to `tech-lead` for the final spec-alignment check and merge decision. Do not pull fresh `Ready` work while a `Ready to Merge` issue is waiting.
3. Inspect any issues already in `In Progress`.
4. Inspect any issues already in `In Review` before pulling fresh work so reviewer-gated work does not stall behind new execution.
5. Inspect any issues in `Need attentions` before pulling fresh `Ready` work — route all of them to `tech-lead` first regardless of what caused the attention (see step 8 routing rules).
6. Invoke `tech-lead` to produce the ordered issue list, current spec focus, sequencing rationale, and execution guardrails for this pass.
7. Use the `tech-lead` ordered list as the execution plan unless a blocker, completed task, or new evidence requires refreshing the plan.
8. For each active issue in `Ready to Merge`, `In Progress`, `In Review`, or `Need attentions`:
   - if the issue is in `Ready to Merge`: route to `tech-lead` for final check and merge (see Tech-Lead Merge Gate)
   - if the issue is `In Progress`: review with `builder` whether implementation is done or still in flight; if done, verify builder left the required handover note and PR linkage, then delegate `reviewer`
   - if the issue is `In Review`: delegate `reviewer` before pulling fresh queue work
   - if the issue is in `Need attentions`: route to `tech-lead` first regardless of the source of the attention flag; `tech-lead` reads the GitHub comment, attempts to resolve, and communicates with `strategist` if product or scope clarity is needed
   - if `tech-lead` (with or without `strategist`) resolves the issue, record the resolution in a GitHub comment and move the issue back to `Ready` for builder to pick up
   - if `tech-lead` and `strategist` cannot resolve the issue internally, run `founder-escalation-preflight` before escalating to the founder, or move to `Blocked` if the remaining problem is an external dependency or approval
   - if `builder` has questions about product intent or scope, invoke `strategist` as needed and record the discussion in GitHub comments
   - if `builder` has questions about technical direction or guardrails, invoke `tech-lead` and continue the pass after the answer
   - if the issue is blocked for any reason, move it to `Blocked`, add a GitHub comment explaining the blocker, and notify the user
9. After reconciling active issues, read the remaining issues in the project with their milestone/spec, status, dependencies, prior comments, and linked docs.
10. Group issues by spec or milestone.
11. Prioritize within the current spec group before moving to another spec, using the ordered list from `tech-lead`.
12. Only switch away from the current spec group when:
   - an issue is blocked by a real dependency
   - human intervention is required
   - there are no more executable issues in that spec group
13. Process issues one by one according to the ordered list from `tech-lead`.
14. Each time one issue reaches done, blocked, or another local stopping point, run `orchestrator-task-done` before deciding whether to end the pass, escalate, or move to the next issue.
15. If there are no executable issues after reconciliation:
   - do not stop at queue reporting alone
   - inspect open repo issues that are not on the project board or are on the board in a non-executable state but may be ready for triage
   - check whether open repo issues or spec work exist outside the current executable queue that can be triaged into the project
   - if tasks exist but are not builder-usable, invoke `tech-lead` to create or request the missing technical delegation details needed to make one issue executable
   - if product/spec direction is needed, invoke `strategist` to clarify or prepare the next actionable spec/issue path
   - only return to the user without internal delegation when no safe next internal action exists or explicit human direction is required

## Return-To-User Gate

Do not return control to the user merely because the current project queue looks empty.

Before ending a `do-task` pass, explicitly exhaust this checklist:

1. route any `Ready to Merge` issues to `tech-lead` for final check and merge
2. reconcile any `In Progress` issues with `builder`
3. reconcile any `In Review` issues with `reviewer`
4. reconcile any `Need attentions` issues through `strategist`, `tech-lead`, or founder escalation as appropriate
5. process any `Ready` issues in the current spec group
6. inspect open repo issues or milestone work that may need project-board triage
7. decide whether a missing executable task can be created or clarified safely through `tech-lead` or `strategist`
8. after each issue-level completion point, run `orchestrator-task-done` so the queue pass does not end early while safe internal work remains

If any checklist item still has a safe internal next step, take that step before replying to the user.

Only stop and report back when:

- every safe internal delegation path has been attempted, and
- the remaining blocker is a real human decision, missing approval, missing credential, or missing external input

When you do return to the user, say which checklist items were exhausted and name the exact blocking decision.
If the orchestrator owns the current pass, the orchestrator must be the role that runs founder-escalation-preflight and decides whether the founder is actually needed for execution blockers.
If product intent, scope meaning, prioritization, or business direction becomes the blocking question, invoke `strategist`; `strategist` may run founder-escalation-preflight and decide whether founder input is actually needed for that product-level decision.
Before returning for a founder decision, run founder-escalation-preflight and include its result.

## Per-Issue Rules

For each issue:

- confirm the technical requirement is clear enough for implementation
- read the linked spec, dependencies, prior delegations, and relevant repository docs
- if product intent, scope meaning, or execution meaning is unclear, clear it with `strategist`
- if technical interpretation, sequencing, or guardrails are unclear, resolve them with `tech-lead`
- record each clarification discussion as an Obsidian communication event file for auditability; update GitHub only for status or final closure
- if the issue has a blocker or needs human intervention, record that in GitHub and skip to the next executable issue
- if the issue needs strategist or tech-lead resolution before safe execution can continue, record a durable GitHub comment and move it to `Need attentions`
- once the technical requirement is clear, invoke `builder` and record that delegation in GitHub
- after delegating, expect `builder` to own issue worktree creation or reuse, branch creation or reuse inside that worktree, implementation-state transitions, PR creation or update, and the builder handover note
- do not create the issue worktree, task branch, open the PR, or write the builder's implementation handover note unless the user explicitly asks the current role to do emergency manual recovery

## Builder And Reviewer Gate

- `builder` works the delegated issue according to the assigned GitHub issue, approved guardrails, and the shared build-review loop
- when `builder` starts, `builder` must create or switch to the issue worktree, create or switch to the issue branch in that worktree, and move the issue into `In Progress`
- after `builder` finishes implementation, `builder` must create or update the PR, move the issue into `In Review`, and leave a durable handover note in the issue or PR before `reviewer` review starts
- builder-reviewer agent communication must be recorded as individual Obsidian event files in the issue communication folder; code-specific findings and final approval remain in PR comments or review threads
- `orchestrator` should only check that the worktree, branch, PR, state change, and handover note exist before delegating `reviewer`
- after the PR is ready, `reviewer` must review before the issue advances
- if `reviewer` finds issues, `reviewer` returns the issue to `builder` in the same worktree and on the same branch and continues the loop through durable review findings
- if `reviewer` approves with no blockers, `reviewer` posts an explicit approval comment on the PR and moves the issue to `Ready to Merge`
- builder completion is not final completion; reviewer approval is not final completion

## Tech-Lead Merge Gate

- every issue in `Ready to Merge` must be routed to `tech-lead` by `orchestrator` before it is considered done
- `tech-lead` reads the linked central Obsidian project documentation, GitHub issue, and PR diff to verify that implementation matches approved scope and satisfies architecture guardrails (KISS, separation of concerns, folder/package/namespace)
- if the check passes: `tech-lead` merges the PR, moves the issue to `Done`, and posts a merge confirmation comment on the PR
- if the check fails: `tech-lead` posts specific findings as PR comments and moves the issue to `Need attentions` with a durable GitHub comment summarising the findings; in the next reconciliation pass, `tech-lead` reviews the `Need attentions` comment, confirms the findings are builder-actionable, and moves the issue back to `Ready`; builder then picks up from `Ready`, fixes the findings on the same branch, moves to `In Progress` then `In Review`, and the review loop continues
- a tech-lead final check failure that results in builder rework counts as a continuation of the same review loop — the 8-loop cap applies across all review passes for the issue including those triggered by tech-lead findings; if the cap is hit, treat it as a loop-breaker and escalate to founder
- `tech-lead` is the only role that merges; no other role may merge without an explicit recovery exception recorded in GitHub
- an issue is `Done` only after `tech-lead` has merged the PR following a passed final check

## GitHub Audit Rules

- GitHub Issues are the canonical execution tasks
- GitHub Project status is the canonical workflow board
- individual Obsidian issue and milestone communication event files are the canonical agent-to-agent delegation log
- GitHub issue comments and PR comments are the final status, closure, and code-review audit record
- the central Obsidian project folder is the canonical product and architecture source
- repository files are canonical only for code-adjacent implementation guidance

## Delegation Rule

- for internal role-to-role work, always delegate when the next safe role is clear
- when `builder`, `reviewer`, or `strategist` is available in this runtime, invoke that role now in the same execution pass instead of stopping at a recorded handoff
- if the current role can delegate to itself under another role context, do that rather than narrating what should happen next
- do not stop after only posting a GitHub comment if `strategist`, `builder`, or `reviewer` can be invoked now
- reserve the word `handoff` for founder-facing return, escalation, or final control transfer

## Ownership Rules

- `orchestrator` owns queue selection, cross-role coordination, and verification that required GitHub artifacts exist.
- `strategist` owns product framing, scope clarity, success criteria, and product-level resolution of ambiguous work.
- `tech-lead` owns technical interpretation, architecture guardrails, sequencing, loop-breaker technical decisions, all `Need attentions` resolution (routing to `strategist` if needed), the final spec-alignment check, the merge decision, and the transition from `Ready to Merge` to `Done`.
- `builder` owns the issue worktree, task branch, implementation, implementation-state transitions into active work and review, PR creation or update, and builder handover event files in Obsidian.
- `reviewer` owns review findings, review approvals, return-to-builder decisions, reviewer verification notes, and the transition from `In Review` to `Ready to Merge` on approval or back to `In Progress` on findings. Reviewer does not merge and does not move issues to `Done`.
- A role should not perform another role's normal workflow mutation just because it has tool access. If recovery is necessary, record why the usual owner could not perform the action.

## Development Loop Ownership Rules

- `builder` must not treat "code pushed" as equivalent to "ready for review"; review starts only after the PR and handover artifacts exist.
- during `do-tasks`, `builder` should continue in the existing issue worktree, on the existing task branch, and on the existing PR when those artifacts already exist
- during `do-tasks`, `builder` must not start a fresh worktree, fresh branch, or replacement PR as part of normal continuation work
- if the existing worktree, branch, or PR is unusable, `builder` may create a replacement only after recording why recovery is necessary and linking the old and new artifacts in GitHub
- after merge or explicit task closure, `builder` should clean up the issue worktree and local branch once the PR no longer needs them
- `reviewer` must not silently fix builder work as a substitute for findings unless the workflow explicitly assigns reviewer implementation for a special recovery case.
- `orchestrator` should not close the loop based on verbal assurances; it should verify the branch, PR, state, and comments.
- `strategist` and `tech-lead` should resolve ambiguity with durable guidance, then return execution to `builder` or `reviewer` rather than carrying the implementation loop themselves.

## Required Delegation Content

Every orchestrator or tech-lead delegation to builder should include:

- current issue and spec
- technical interpretation of the requirement
- guardrails and constraints
- dependencies or blockers
- expected verification
- exact next action

Every builder-to-reviewer handover should include:

- worktree path, branch name, and PR link
- concise implementation summary
- verification already run
- known risks, tradeoffs, or follow-up items
- exact review focus or open questions

## Stop And Skip Rules

- if an issue needs human intervention, record it and skip to the next executable issue
- if an in-progress issue is blocked, move it to `Blocked`, add a GitHub comment, and notify the user
- if a spec is too unclear to proceed safely, record the clarification need in GitHub before pausing or switching
- if the executable queue is empty, treat that as a triage trigger, not as completion of the pass
- do not start a new spec unless the remaining work changes scope

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

- builder stayed in the existing issue worktree and on the existing task branch when they already existed
- builder updated the existing PR when one already existed
- any new worktree, branch, or PR creation has an explicit GitHub recovery note explaining why continuity was not possible
