---
name: state-transitions
description: Use when the GitHub delivery flow is already in place and the agent needs the specific rules for moving work between project states such as open, backlog, ready, in progress, in review, ready to merge, need attentions, blocked, and done. Prefer `github-agentic-delivery-flow` for the overall workflow model; use this skill for state-machine details.
---

# State Transitions

Use this skill whenever the agent needs to decide how work should move through the delivery workflow.

This skill defines the default project-board state machine and the conditions for each transition. It helps keep status changes meaningful and prevents work from drifting through the board without meeting entry or exit conditions.

## Canonical State Model

The canonical happy-path state model is:

`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`

Two exception states exist outside the happy path:

- `Need attentions` — founder-only decision state, entered only after strategist and tech-lead review have both been attempted and neither can resolve the question internally
- `Blocked` — exception state entered when tech-lead and strategist cannot resolve a dependency, decision, credential, permission, or external condition; any state may enter `Blocked`, typically `In Progress` or `In Review`

## States

Use these default states unless the repository already has a well-established equivalent:

- `Open`
- `Backlog`
- `Ready`
- `In Progress`
- `In Review`
- `Ready to Merge`
- `Done`
- `Need attentions` (founder-only exception)
- `Blocked` (exception)

Legacy board option names such as `Inbox` (now `Open`) and `Shaping` (now `Backlog`) may still exist on some GitHub boards. Agents must use the canonical names in all communication and must not rename remote board options without explicit founder-approved handling.

## Transition Rules

### `Open` -> `Backlog`

Allowed when:

- the idea has enough substance to evaluate

Typical owner:

- strategist

### `Backlog` -> `Ready`

Allowed when:

- founder direction is clear
- spec is written or linked
- tech-lead says the scope is technically viable
- initial task shape is clear enough to execute
- the work has been materialized into one or more GitHub task issues
- the next responsible role for the ready issue is builder

Typical owner:

- strategist or tech-lead

### `Ready` -> `In Progress`

Allowed when:

- the issue has acceptance criteria
- dependencies are not blocking
- a builder is taking ownership

Typical owner:

- builder

Builder is responsible for making this transition when implementation starts; orchestrator should not do it on the builder's behalf during normal flow.

### `In Progress` -> `In Review`

Allowed when:

- implementation is complete for the approved scope
- evidence is attached
- the builder reports known risks honestly

Typical owner:

- builder

Builder is responsible for this transition only after the branch, PR, verification evidence, and durable handover note are in place.

### `In Review` -> `In Progress`

Allowed when:

- reviewer finds actionable issues
- the issue is not blocked on outside input

Typical owner:

- reviewer

Reviewer should record durable findings and return the issue to builder on the same branch when rework is needed.

### `Any State` -> `Need attentions` (founder-only)

`Need attentions` is a founder-only decision state. An issue may enter it only when all of the following are true:

- strategist review has been attempted and cannot resolve the question
- tech-lead review has been attempted and cannot resolve the question
- the remaining question is a real founder decision: product direction, prioritization, approval, credentials, or a tradeoff agents cannot safely make
- the agent has recorded the full reasoning in an Obsidian communication event file and left a concise founder-addressed GitHub comment naming the exact decision needed

Typical owner:

- any role, after strategist and tech-lead review; usually routed by orchestrator or tech-lead

Internal strategist or tech-lead questions must not use `Need attentions`. Resolve them in Obsidian communication and keep the issue in its current state (or return it to `Ready`) while internal resolution happens.

### `Need attentions` -> Prior State

Allowed when:

- the founder has recorded the decision
- the next executable path is clear again
- the issue returns to the state it came from — typically `Ready`, `In Review`, or `Backlog`

Typical owner:

- the role that receives the founder decision, usually tech-lead

### `Need attentions` -> `Blocked`

Allowed when:

- the founder decision depends on a real dependency, approval, credential, or outside condition that no one controls

Typical owner:

- tech-lead or strategist

### `In Review` -> `Ready to Merge`

Allowed when:

- reviewer finds no blocking issues
- all mandatory review criteria are satisfied (KISS, separation of concerns, correct folder/package/namespace per architecture docs)
- smoke verification is acceptable for the task
- reviewer posts an explicit approval comment on the PR stating the issue is clear with no blockers

Typical owner:

- reviewer

Reviewer must post the approval comment on the PR before making this transition. The comment must state that no blockers remain and the PR is ready to merge.

### `Any State` -> `Blocked` (exception)

`Blocked` is an exception state, not a workflow stage. Any state may enter it — typically `In Progress` or `In Review` — when:

- tech-lead and strategist have both attempted resolution and cannot clear the problem internally
- a dependency, decision, credential, permission, or external condition prevents safe progress
- the blocker is recorded as an Obsidian communication event file with a concise GitHub status note saying what is needed to unblock it

Typical owner:

- any role after tech-lead/strategist resolution was attempted; usually tech-lead

### `Blocked` -> Prior State

Allowed when:

- the blocking condition is resolved
- the next responsible role is explicit
- the issue returns to the state it was in before blocking — typically `In Progress` or `In Review`

Typical owner:

- the role that clears the blocker or receives the clarified next step

### `Ready to Merge` -> `Done`

Allowed when:

- tech-lead has performed the final spec-alignment check and it passed
- the PR has been merged by tech-lead
- the merge commit is on the production base branch
- tech-lead has posted a merge confirmation comment on the PR

Typical owner:

- tech-lead only; no other role may make this transition without an explicit recovery exception recorded in GitHub

After merge, tech-lead owns cleanup: removing the task worktree and local branch once they are no longer needed for review, rollback, or follow-up fixes, using `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh`.

## Rules Of Restraint

- Do not move work to `Done` because it looks close.
- Do not move work to `Done` directly from `In Review`; it must pass through `Ready to Merge` after reviewer approval.
- Do not move work to `Ready to Merge` without a reviewer approval comment on the PR explicitly stating no blockers remain.
- Do not move work to `Ready` if the spec is still argument-shaped instead of execution-shaped.
- Do not move work into `Need attentions` before strategist and tech-lead review have both been attempted; it is a founder-only decision state, and the founder-addressed GitHub comment must name the exact decision needed.
- Do not use `Need attentions` for internal strategist or tech-lead questions; resolve those in Obsidian communication while the issue stays in its current state.
- Do not move a spec or milestone forward based only on comments if no builder-usable task issue exists yet.
- Do not move work into `Blocked` before tech-lead and strategist resolution has been attempted, and never leave it there without saying what is needed to unblock it.
- Do not bounce work between `In Progress` and `In Review` indefinitely; escalate recurring architectural rework.

## Anti-Stall Rule

If strategist or tech-lead work ends with "builder should do X next", then one of the following must happen before their phase is considered complete:

- create a task issue for X and move it to `Ready`
- assign X to an existing task issue and move it to `Ready`
- mark the work `Blocked` with the missing prerequisite recorded after tech-lead and strategist resolution was attempted

Do not let the flow end at a comment-only handoff.

## Usage Guidance

- Use this skill when deciding the next board state for a task.
- Use this skill when designing GitHub Project columns or automation rules.
- Use this skill with approval and escalation rules so state transitions reflect real delivery decisions.
