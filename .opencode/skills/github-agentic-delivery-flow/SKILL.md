---
name: github-agentic-delivery-flow
description: Use whenever work should move from idea or spec to shipped product through a multi-agent loop using GitHub Milestones as specs, GitHub Issues as tasks, GitHub Projects as the kanban board, and role-based delegation between strategist, tech-lead, builder, and validator. This is the top-level GitHub delivery workflow skill. Trigger on requests to design, run, improve, or govern the continuous delivery flow, especially when the user mentions delegation, agent collaboration, review loops, GitHub workflow, milestones, issues, project boards, blockers, approvals, or spec-to-release execution.
---

# GitHub Agentic Delivery Flow

Use this skill when the user wants a continuous multi-agent workflow that starts from a spec and ends with validated product delivery.

This skill defines the top-level operating model. It does not replace lower-level skills such as `agentic-flow-terms`, `agent-communication-log`, `role-memory`, `do-task`, `task-development`, `task-completion`, `github-conventions`, `state-transitions`, or `approval-and-escalation`. Use those for the detailed mechanics they already own.

## Purpose

Create a durable, inspectable, repeatable delivery loop where:

- a spec becomes the governing container for a deliverable
- work is split into small executable tasks
- different agents own different stages of the loop
- state changes are visible in GitHub
- review and rework happen in bounded loops
- blockers, tradeoffs, and approvals are recorded durably
- work is not considered done until it is validated

Prevent shaping work from dying in comments after the spec is approved. Strategy and technical review are only complete when execution has been concretized into builder-usable tasks and the next owner is explicit.

## Core Mapping

Use this GitHub mapping consistently:

| Workflow Concept | GitHub Artifact |
|---|---|
| Spec / Deliverable | GitHub Milestone |
| Task | GitHub Issue |
| Workflow State | GitHub Project item status |
| Implementation branch / PR | GitHub Branch + Pull Request |
| Durable delegation / findings / approvals | GitHub issue comments and PR comments |
| Canonical implementation detail | Repository docs linked from the milestone or issue |

Do not rely on GitHub milestone text alone as the full spec. Keep the canonical spec in the repository and link it from the milestone.

## Source Of Truth Rules

- The repository spec document is the canonical implementation spec.
- The GitHub milestone is the tracking container for that spec.
- GitHub issues are the canonical task records for execution state and task-local discussion.
- GitHub Projects is the canonical workflow board for state visualization.
- GitHub issue comments and PR comments are the canonical execution delegation and review record.
- Local markdown task files, local workflow boards, and local communication logs are legacy artifacts and not part of the active execution flow.
- If GitHub and repo docs disagree, reconcile them instead of silently choosing one.

## Agent Roles

Default roles in this workflow:

- `strategist`: pressure-tests the idea, sharpens the MVP, and prepares a spec draft
- `tech-lead`: verifies technical feasibility, architecture direction, sequencing, and guardrails
- `builder`: implements approved scoped work with focused code changes and verification
- `validator`: reviews implementation, checks scope alignment, and performs lightweight smoke verification

Use specialized skills beneath these roles when the task needs domain-specific handling. The orchestration roles should stay focused on flow ownership and decision quality.

## End-To-End Flow

### 1. Shape the work

- `strategist` clarifies the problem, urgency, constraints, and desired outcome.
- Challenge weak assumptions and reduce the scope to the smallest practical MVP.
- Produce a spec draft that is concrete enough for technical review.
- `strategist` is also the product-level review gate and should confirm the work is worth doing, the intended outcome is clear, and major business constraints are captured before technical planning continues.

### 2. Validate the technical direction

- `tech-lead` reviews the spec for feasibility, coupling, migration risk, operational burden, and security concerns.
- Add architecture constraints, sequencing notes, and guardrails.
- Decide whether the work is ready, needs scope adjustment, or should stop.
- `tech-lead` is the technical review gate and should confirm the requested change is technically viable and implementable before tasks are created.

### 3. Create the execution container

- Create or update the repository spec.
- Create a GitHub milestone for that spec.
- Link the repo spec from the milestone.
- Put summary, owner, and delivery intent in the milestone description.

### 4. Split the work

- Break the spec into small GitHub issues.
- Each issue must represent one scoped unit of execution.
- Record dependencies, constraints, acceptance criteria, verification expectations, and owner role.
- Do not stop at milestone comments or planning notes. Strategy and tech-lead work is incomplete until the task set exists in GitHub issues.
- If the work is approved to proceed, create the task issues immediately rather than leaving only guidance in comments.
- At least one issue should be left in a builder-usable state with a clear next action unless the entire spec is explicitly blocked.

### 4.5 Activate execution

- After task creation, assign the next responsible role for each issue.
- Move executable tasks to `Ready`.
- If a specific builder is known, assign the issue directly to that builder. If not, set `Current role: builder` in the issue body and leave a durable delegation comment.
- If no task is actually ready, leave the work in `Shaping` or `Blocked` with an explicit reason. Do not pretend the flow has advanced.

### 5. Run the build-review loop

- Use the `do-task` skill as the canonical execution loop.
- `tech-lead` starts execution by reading the project queue, grouping issues by spec, and prioritizing the next executable issue set.
- `tech-lead` should work one spec group at a time unless a dependency, blocker, or required human intervention makes that impossible.
- `tech-lead` delegates technically clear issues to `builder`, then requires `validator` review before any issue is treated as done.
- If findings remain, return the issue to `builder` and continue the loop until approved, blocked, or escalated.
- An apparently empty executable queue is not the end of the pass by itself. `tech-lead` should next reconcile review-state work, triage open repo issues into the board when safe, or delegate `strategist` to clarify the next actionable spec path before returning to the user.

### 6. Close the work

- Mark the issue done only after scope, acceptance evidence, review, and smoke verification are satisfied.
- Close the milestone only when all required issues are done or explicitly deferred.
- Record follow-up debt, defer items, and unresolved risks before closing the milestone.

## State Machine

Use a small, explicit workflow state machine. Prefer these states unless the repository already has an established equivalent:

- `Inbox`
- `Shaping`
- `Ready`
- `In Progress`
- `In Review`
- `Blocked`
- `Done`

State changes should be meaningful, not decorative.

Use them like this:

- `Inbox`: captured but not yet shaped
- `Shaping`: being refined by strategist and/or founder
- `Ready`: approved for implementation with clear scope
- `In Progress`: builder is actively executing
- `In Review`: waiting for validator review or re-review
- `Blocked`: cannot safely proceed without a dependency or decision
- `Done`: validated and closed

Additional rule:

- A spec-level milestone should not be treated as execution-ready until it has concrete child issues, and at least one non-blocked child issue is in `Ready` when execution can begin.
- During execution, prioritize issues by spec group before jumping across specs. Break that rule only for explicit dependencies, blockers, or human-intervention waits.

## Required Issue Quality Bar

Every GitHub issue used as a task should include:

- problem or task outcome
- in-scope work
- out-of-scope guardrails if needed
- dependencies
- acceptance criteria
- verification steps or expected evidence
- linked milestone
- owner role or current responsible agent
- links to relevant spec/docs/PRs

If the issue is intended for a builder next, it must be actionable without requiring the builder to reinterpret strategist or tech-lead comments into a new plan.

Avoid giant issues that require multiple major decisions at once.

## Handoff Rules

Use durable delegation notes whenever work moves between roles.

Every internal delegation should record:

- current state
- what changed
- files, PRs, or artifacts involved
- verification already completed
- open findings, blockers, or risks
- exact next expected action

When `tech-lead` asks `strategist` to clarify a spec or issue during execution:

- record the clarification request and resolution in GitHub comments
- keep the issue in the current spec group unless it is blocked
- skip to another issue only when waiting on a real blocker or human input

Comments alone are not sufficient when the next action is "implement". That next action must point to an actual task issue, not just a discussion thread.

Do not rely on chat memory alone for decisions that affect future work.

## Review Loop Rules

- Validation findings are the primary output of the validator.
- Findings should be specific enough for a builder to act on without guessing.
- Rework should stay within the approved scope unless the user or tech-lead expands it.
- Keep review loops bounded.
- If the same architectural problem repeats across several loops, escalate instead of thrashing.

Use the repository's `agentic-flow-terms` definitions for loop count, loop breaker, stopper, hard blocker, defer task, and approval semantics.

## Escalation Rules

Escalate when:

- the spec is not implementation-ready
- scope conflicts with technical reality
- a blocker requires human input, credentials, or approval
- security or architecture risk makes normal progress unsafe
- repeated loops show the task is underspecified or mis-scoped

When escalating, say what is blocked, why it is blocked, who must decide, and what the smallest unblocking decision is.

Before escalating to the founder from delivery execution, run `founder-escalation-preflight`.
Founder escalation should happen only after checking repo docs, GitHub collaboration history, relevant role memory, and remaining safe internal delegation paths.
Do not use that preflight as a gate on normal strategist-founder planning, spec review, or sprint discussion.

## Approval Rules

- `strategist` helps prepare the spec but does not overrule the founder.
- `tech-lead` determines technical go/no-go and guardrails.
- `strategist` and `tech-lead` do not complete their phase by leaving advice in comments only. If the work should proceed, they must ensure task issues exist and the next builder-facing state is explicit.
- `builder` does not self-approve implementation readiness.
- `validator` decides whether the task is approved, returned for rework, or blocked.
- Merge or completion should happen only after the defined approval gates pass.

## Usage Guidance

- Use this skill first when designing or adjusting the overall workflow.
- Use this skill to interpret how GitHub milestones, issues, projects, comments, branches, PRs, and agent roles fit together.
- Use lower-level workflow skills for detailed execution mechanics after the top-level flow is clear.
- If the workflow starts to feel heavy, reduce issue size and simplify state transitions before adding more agent roles.
