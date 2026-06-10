---
name: state-transitions
description: Use when the GitHub delivery flow is already in place and the agent needs the specific rules for moving work between project states such as inbox, shaping, need attentions, ready, in progress, in review, ready to merge, blocked, and done. Prefer `github-agentic-delivery-flow` for the overall workflow model; use this skill for state-machine details.
---

# State Transitions

Use this skill whenever the agent needs to decide how work should move through the delivery workflow.

This skill defines the default project-board state machine and the conditions for each transition. It helps keep status changes meaningful and prevents work from drifting through the board without meeting entry or exit conditions.

## States

Use these default states unless the repository already has a well-established equivalent:

- `Inbox`
- `Shaping`
- `Need attentions`
- `Ready`
- `In Progress`
- `In Review`
- `Ready to Merge`
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

### `Any Active State` -> `Need attentions` (internal)

Allowed when:

- an agent has identified an issue that needs strategist or tech-lead intervention before safe execution can continue
- the issue is not simply blocked on an external dependency
- the agent can leave a durable GitHub comment explaining the attention needed, the risk, and the exact question to resolve

Typical owner:

- builder, reviewer, strategist, or tech-lead

### `Need attentions` -> `Ready`

Allowed when:

- strategist or tech-lead has resolved the issue through a durable GitHub comment
- the next executable path is clear again
- the issue is builder-usable without hidden ambiguity

Typical owner:

- strategist or tech-lead

### `Need attentions` -> `Blocked`

Allowed when:

- the required attention exposes a real dependency, approval, credential, or outside condition that agents cannot safely clear internally

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

### `In Review` -> `Ready to Merge`

Allowed when:

- reviewer finds no blocking issues
- all mandatory review criteria are satisfied (KISS, separation of concerns, correct folder/package/namespace per architecture docs)
- smoke verification is acceptable for the task
- reviewer posts an explicit approval comment on the PR stating the issue is clear with no blockers

Typical owner:

- reviewer

Reviewer must post the approval comment on the PR before making this transition. The comment must state that no blockers remain and the PR is ready to merge.

### `Ready to Merge` -> `Done`

Allowed when:

- tech-lead has performed the final spec-alignment check and it passed
- the PR has been merged by tech-lead
- the merge commit is on the production base branch
- tech-lead has posted a merge confirmation comment on the PR

Typical owner:

- tech-lead only; no other role may make this transition without an explicit recovery exception recorded in GitHub

### `Any Active State` -> `Need attentions`

Allowed when (founder-facing):

- a PR or issue requires a founder decision before it can safely proceed or merge
- the question cannot be resolved by strategist, tech-lead, builder, or reviewer alone
- the agent leaves a durable GitHub comment explaining what the founder needs to decide and why internal resolution is not sufficient

This use of `Need attentions` is distinct from the internal strategist/tech-lead intervention use. Label the comment clearly so the founder knows the attention is directed at them.

## Rules Of Restraint

- Do not move work to `Done` because it looks close.
- Do not move work to `Done` directly from `In Review`; it must pass through `Ready to Merge` after reviewer approval.
- Do not move work to `Ready to Merge` without a reviewer approval comment on the PR explicitly stating no blockers remain.
- Do not move work to `Ready` if the spec is still argument-shaped instead of execution-shaped.
- Do not move work into `Need attentions` without a durable GitHub comment that explains what attention is needed and who should resolve it (internal role or founder).
- Do not leave work in `Need attentions` through sprint planning without first attempting strategist or tech-lead resolution for internal questions; escalate to founder only after internal paths are exhausted.
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
