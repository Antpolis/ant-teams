---
name: state-transitions
description: Use when the GitHub delivery flow is already in place and the agent needs the specific rules for moving work between project states such as inbox, shaping, ready, in progress, in review, blocked, and done. Prefer `github-agentic-delivery-flow` for the overall workflow model; use this skill for state-machine details.
---

# State Transitions

Use this skill whenever the agent needs to decide how work should move through the delivery workflow.

This skill defines the default project-board state machine and the conditions for each transition. It helps keep status changes meaningful and prevents work from drifting through the board without meeting entry or exit conditions.

## States

Use these default states unless the repository already has a well-established equivalent:

- `Inbox`
- `Shaping`
- `Ready`
- `In Progress`
- `In Review`
- `Blocked`
- `Done`

## Transition Rules

### `Inbox` -> `Shaping`

Allowed when:

- the idea has enough substance to evaluate

Typical owner:

- strategist

### `Shaping` -> `Ready`

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

### `In Progress` -> `In Review`

Allowed when:

- implementation is complete for the approved scope
- evidence is attached
- the builder reports known risks honestly

Typical owner:

- builder

### `In Review` -> `In Progress`

Allowed when:

- validator finds actionable issues
- the issue is not blocked on outside input

Typical owner:

- validator

### `Any State` -> `Blocked`

Allowed when:

- a dependency, decision, credential, permission, or external condition prevents safe progress

Typical owner:

- any role, with a durable blocker note

### `Blocked` -> Prior State

Allowed when:

- the blocking condition is resolved
- the next responsible role is explicit

Typical owner:

- the role that clears the blocker or receives the clarified next step

### `In Review` -> `Done`

Allowed when:

- validator finds no blocking issues
- smoke verification is acceptable for the task
- required approvals are recorded

Typical owner:

- validator

## Rules Of Restraint

- Do not move work to `Done` because it looks close.
- Do not move work to `Ready` if the spec is still argument-shaped instead of execution-shaped.
- Do not move a spec or milestone forward based only on comments if no builder-usable task issue exists yet.
- Do not leave work in `Blocked` without saying what is needed to unblock it.
- Do not bounce work between `In Progress` and `In Review` indefinitely; escalate recurring architectural rework.

## Anti-Stall Rule

If strategist or tech-lead work ends with "builder should do X next", then one of the following must happen before their phase is considered complete:

- create a task issue for X and move it to `Ready`
- assign X to an existing task issue and move it to `Ready`
- mark the work `Blocked` with the missing prerequisite recorded

Do not let the flow end at a comment-only handoff.

## Usage Guidance

- Use this skill when deciding the next board state for a task.
- Use this skill when designing GitHub Project columns or automation rules.
- Use this skill with approval and escalation rules so state transitions reflect real delivery decisions.
