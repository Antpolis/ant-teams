---
name: do-task
description: Use when the orchestrator should drive execution from the GitHub project queue, invoke tech-lead for technical interpretation, invoke builder for implementation, and require reviewer review before any issue is treated as done.
---

# Do Task

Use this skill whenever execution should start from the current GitHub project issue queue rather than from a single already-picked task.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use github-agentic-delivery-flow for the top-level GitHub operating model.
Use github-conventions, state-transitions, approval-and-escalation, and agent-communication-log for GitHub workflow mechanics.
Use pr-review-flow when builder work is ready for reviewer review so the PR becomes the canonical review surface.
Use role-memory for durable cross-loop continuity.
Use founder-escalation-preflight before asking the founder for a decision.

Bundled helpers for issue-isolated development live in:

- `scripts/create_task_worktree.sh`
- `scripts/cleanup_task_worktree.sh`

Use these helpers instead of inventing ad hoc `git worktree` commands when the builder needs to start or clean up issue workspaces.
These helpers read the default issue-worktree root from top-level `worktreeRoot` in `.github-project.json` when it is present.

## Core Rule

The `orchestrator` owns the queue pass and role-to-role control flow for execution.
The `tech-lead` provides the ordered issue list, execution priorities, technical interpretation, and guardrails for each pass.
The delegated execution roles own their own workflow side effects. Once `builder` takes an issue, `builder` is responsible for creating or switching to the issue worktree and task branch, moving the issue into the correct implementation state, opening or updating the PR, and leaving a durable implementation handover note before `reviewer` takes over. `orchestrator` should coordinate and verify those handoff artifacts exist, not perform them on behalf of delegated agents.

Do not require strategist confirmation for every issue.
Bring in `strategist` only when product intent, scope meaning, or execution meaning is unclear.
Bring in `tech-lead` when technical interpretation, sequencing, guardrails, or loop-breaker judgment is needed.

## Queue-Driven Flow

1. Start from the GitHub project issue queue.
2. First inspect any issues already in `In Progress` or equivalent processing status.
3. Also inspect any issues already in `In Review` before pulling fresh work so reviewer-gated work does not stall behind new execution.
4. Inspect any issues already in `Need attentions` before pulling fresh `Ready` work so strategist- or tech-lead-resolvable issues do not linger across passes.
5. Invoke `tech-lead` to produce the ordered issue list, current spec focus, sequencing rationale, and execution guardrails for this pass.
6. Use the `tech-lead` ordered list as the execution plan unless a blocker, completed task, or new evidence requires refreshing the plan.
7. For each active issue already in progress, review, or `Need attentions`:
   - review with `builder` whether the implementation is actually done or still in flight
   - if the work is done from the builder side, verify that `builder` left the required handover note and PR linkage, then delegate `reviewer` rather than moving the issue forward yourself
   - if the work is already waiting on reviewer, delegate reviewer before considering fresh queue work
   - if the work is in `Need attentions`, read the durable GitHub comment first and route it to `strategist` for product, scope, or acceptance clarification, or to `tech-lead` for technical, sequencing, feasibility, or guardrail clarification
   - if a `Need attentions` issue is resolved safely, record the resolution in GitHub comments and move it back to `Ready`
   - if a `Need attentions` issue cannot be resolved safely through available internal roles, run founder-escalation-preflight before escalating to the founder, or move it to `Blocked` if the remaining problem is an external dependency or approval
   - if the work is not done, carry on to finish it before pulling fresh work
   - if `builder` has questions about product intent, scope meaning, or execution meaning, invoke `strategist` only as needed and record that discussion in GitHub comments
   - if `builder` has questions about technical direction or guardrails, invoke `tech-lead` and continue the pass after the answer
   - if the issue is blocked for any reason, move it to `Blocked`, add a GitHub comment explaining the blocker, and notify the user
8. After reconciling active issues, read the remaining issues in the project with their milestone/spec, status, dependencies, prior comments, and linked docs.
9. Group issues by spec or milestone.
10. Prioritize within the current spec group before moving to another spec, using the ordered list from `tech-lead`.
11. Only switch away from the current spec group when:
   - an issue is blocked by a real dependency
   - human intervention is required
   - there are no more executable issues in that spec group
12. Process issues one by one according to the ordered list from `tech-lead`.
13. If there are no executable issues after reconciliation:
   - do not stop at queue reporting alone
   - inspect open repo issues that are not on the project board or are on the board in a non-executable state but may be ready for triage
   - check whether open repo issues or spec work exist outside the current executable queue that can be triaged into the project
   - if tasks exist but are not builder-usable, invoke `tech-lead` to create or request the missing technical delegation details needed to make one issue executable
   - if product/spec direction is needed, invoke `strategist` to clarify or prepare the next actionable spec/issue path
   - only return to the user without internal delegation when no safe next internal action exists or explicit human direction is required

## Return-To-User Gate

Do not return control to the user merely because the current project queue looks empty.

Before ending a `do-task` pass, explicitly exhaust this checklist:

1. reconcile any `In Progress` issues with `builder`
2. reconcile any `In Review` issues with `reviewer`
3. reconcile any `Need attentions` issues through `strategist` or `tech-lead`
4. process any `Ready` issues in the current spec group
5. inspect open repo issues or milestone work that may need project-board triage
6. decide whether a missing executable task can be created or clarified safely through `tech-lead` or `strategist`

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
- record any clarification discussion in GitHub comments for auditability
- if the issue has a blocker or needs human intervention, record that in GitHub and skip to the next executable issue
- if the issue needs strategist or tech-lead resolution before safe execution can continue, record a durable GitHub comment and move it to `Need attentions`
- once the technical requirement is clear, invoke `builder` and record that delegation in GitHub
- after delegating, expect `builder` to own issue worktree creation or reuse, branch creation or reuse inside that worktree, implementation-state transitions, PR creation or update, and the builder handover note
- do not create the issue worktree, task branch, open the PR, or write the builder's implementation handover note unless the user explicitly asks the current role to do emergency manual recovery

## Builder And Reviewer Gate

- `builder` works the delegated issue according to the assigned GitHub issue, approved guardrails, and the shared build-review loop
- when `builder` starts, `builder` must create or switch to the issue worktree, create or switch to the issue branch in that worktree, and move the issue into `In Progress`
- after `builder` finishes implementation, `builder` must create or update the PR, move the issue into `In Review`, and leave a durable handover note in the issue or PR before `reviewer` review starts
- builder-reviewer review discussion must happen in the PR comments or review threads
- `orchestrator` should only check that the worktree, branch, PR, state change, and handover note exist before delegating `reviewer`
- after the PR is ready, `reviewer` must review before the issue can be treated as done
- if `reviewer` finds issues, `reviewer` returns the issue to `builder` in the same worktree and on the same branch and continues the loop through durable review findings
- builder completion is not final completion
- an issue is only treated as done after reviewer approval, or otherwise blocked or escalated

## GitHub Audit Rules

- GitHub Issues are the canonical execution tasks
- GitHub Project status is the canonical workflow board
- GitHub issue comments and PR comments are the canonical delegation and audit log
- repository docs are the canonical spec and architecture source

## Delegation Rule

- for internal role-to-role work, always delegate when the next safe role is clear
- when `builder`, `reviewer`, or `strategist` is available in this runtime, invoke that role now in the same execution pass instead of stopping at a recorded handoff
- if the current role can delegate to itself under another role context, do that rather than narrating what should happen next
- do not stop after only posting a GitHub comment if `strategist`, `builder`, or `reviewer` can be invoked now
- reserve the word `handoff` for founder-facing return, escalation, or final control transfer

## Ownership Rules

- `orchestrator` owns queue selection, cross-role coordination, and verification that required GitHub artifacts exist.
- `strategist` owns product framing, scope clarity, success criteria, and product-level resolution of ambiguous work.
- `tech-lead` owns technical interpretation, architecture guardrails, sequencing, and loop-breaker technical decisions.
- `builder` owns the issue worktree, task branch, implementation, implementation-state transitions into active work and review, PR creation or update, and builder handover notes.
- `reviewer` owns review findings, review approvals, return-to-builder decisions, reviewer verification notes, and transitions from review to done or back to rework.
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

When checking work delegated to `builder`, verify these artifacts exist before involving `reviewer`:

- issue worktree path and task branch linked or named in the issue or PR
- issue state moved to the correct active state by the delegated role
- PR opened or updated for the current implementation
- durable builder handover note with enough detail for review to continue without chat context

If any artifact is missing, send the issue back to `builder` to complete the workflow record. Do not silently complete those actions on the builder's behalf.

During `do-tasks`, also verify continuity:

- builder stayed in the existing issue worktree and on the existing task branch when they already existed
- builder updated the existing PR when one already existed
- any new worktree, branch, or PR creation has an explicit GitHub recovery note explaining why continuity was not possible
