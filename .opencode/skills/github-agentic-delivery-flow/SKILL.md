---
name: github-agentic-delivery-flow
description: Use whenever work should move from idea or spec to shipped product through a multi-agent loop using GitHub Milestones as specs, GitHub Issues as tasks, GitHub Projects as the kanban board, and orchestration across strategist, tech-lead, builder, and reviewer. This is the top-level GitHub delivery workflow skill. Trigger on requests to design, run, improve, or govern the continuous delivery flow, especially when the user mentions delegation, agent collaboration, orchestration, review loops, GitHub workflow, milestones, issues, project boards, blockers, approvals, or spec-to-release execution.
---

# GitHub Agentic Delivery Flow

Use this skill when the user wants a continuous multi-agent workflow that starts from a spec and ends with validated product delivery.

This skill defines the top-level operating model. It does not replace lower-level skills such as `agentic-flow-terms`, `agent-communication-log`, `role-memory`, `do-task`, `task-completion`, `github-conventions`, `state-transitions`, or `approval-or-escalation`. Use those for the detailed mechanics they already own.

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

- `orchestrator`: owns queue-driven execution, gets the ordered issue list from tech-lead, invokes the next role directly, verifies that delegated roles left the expected GitHub artifacts, and keeps the loop moving until a real human decision is required
- `strategist`: pressure-tests the idea, sharpens the MVP, writes the business sections of the spec (problem statement, business value, success metrics, goals, non-goals, stakeholders, constraints), and confirms the issue set maps to business value before execution starts
- `tech-lead`: verifies technical feasibility and architecture direction; writes the technical sections of the spec (functional requirements, technical requirements, architecture notes, acceptance criteria); is the sole owner of the GitHub milestone and every execution issue — no other role creates or modifies milestones or issues in normal flow; sequences all issues and sets per-issue guardrails before marking anything `Ready`; performs the final spec-alignment check and is the only role that merges PRs
- `builder`: implements approved scoped work with focused code changes and verification, owns branch and PR lifecycle for the delegated task, updates task state during implementation, and leaves a durable review handover note
- `reviewer`: reviews builder output, checks scope and architecture alignment, flags unnecessary additions, performs lightweight smoke verification, and records clear findings or approval back into the GitHub workflow

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

Tech-lead creates the GitHub milestone. No other role creates or modifies the milestone in normal flow.

- Tech-lead creates the GitHub milestone linked to the spec document.
- Tech-lead adds a milestone description: summary, spec link, delivery intent, and sequencing overview.
- If the spec is not yet implementation-ready (missing any required business or technical section), tech-lead must not create the milestone yet — return to shaping.

### 4. Split the work

Tech-lead creates all execution issues using the `how-to-create-task` skill. No other role creates issues in normal flow.

- Break the spec into small GitHub issues, each representing one scoped unit of execution.
- Every issue must include: Why, Outcome, Scope, Dependencies (with architecture doc links), Tech-Lead Guardrails, Acceptance Criteria traceable to spec, Verification, Owner, and Sequence Position.
- Record the full sequence in a durable milestone comment before marking any issue `Ready`.
- Strategy and tech-lead work is incomplete until the full task set exists in GitHub issues and every spec acceptance criterion is covered.
- If the work is approved to proceed, create all task issues before advancing — do not leave only guidance in comments.

Coverage gate (required before any issue moves to `Ready`):
- every spec acceptance criterion maps to at least one issue
- every functional and technical requirement maps to at least one issue
- strategist has confirmed the issue set maps to the spec's business value

### 4.5 Activate execution

- Tech-lead sets `Current role: builder` and Sequence Position on each issue.
- Tech-lead moves issues to `Ready` only after the sequencing and coverage gate passes.
- If no task is actually ready, leave the work in `Shaping` or `Blocked` with an explicit reason recorded in GitHub. Do not pretend the flow has advanced.

### 5. Run the build-review loop

- Use the `do-task` skill as the canonical execution loop.
- `orchestrator` starts execution by reading the project queue, then invoking `tech-lead` to produce the ordered issue list, spec focus, sequencing rationale, and guardrails for the current pass.
- `orchestrator` should work one spec group at a time unless a dependency, blocker, or required human intervention makes that impossible.
- `orchestrator` uses the `tech-lead` ordered list as the execution plan, invokes `builder` for the next technically clear issue, checks that the builder-owned branch, PR, state transition, and handover artifacts exist, and then requires `reviewer` review before any issue advances.
- If reviewer finds issues, return the issue to `builder` on the same branch and continue the loop until the reviewer approves, a blocker appears, or 8 loops are reached.
- When reviewer approves with no blockers, reviewer posts an explicit approval comment on the PR and moves the issue to `Ready to Merge`. The loop does not end here.
- `orchestrator` routes every `Ready to Merge` issue to `tech-lead` for the final spec-alignment check. See step 5a.
- An apparently empty executable queue is not the end of the pass by itself. `orchestrator` should next reconcile `Ready to Merge` work, triage open repo issues into the board when safe, or invoke `strategist` to clarify the next actionable spec path before returning to the user.

### 5a. Tech-lead final check and merge

After an issue reaches `Ready to Merge`, `tech-lead` performs the final spec-alignment check:

- Read the linked spec, GitHub issue, and PR diff.
- Verify that the implementation matches the approved scope and does not violate architecture or guardrails.
- Check that KISS, separation of concerns, and folder/package/namespace placement (per architecture docs) are satisfied.

If the check passes:
- `tech-lead` merges the PR.
- Moves the issue to `Done`.
- Posts a merge confirmation comment on the PR.

If the check fails:
- `tech-lead` posts specific findings on the PR as comments.
- Moves the issue back to `Need attentions` with a durable GitHub comment naming the findings and directing builder to pick it up.
- Builder picks up the issue from `Need attentions`, fixes the findings on the same branch, and the review loop restarts from `In Review`.

### 6. Close the work

- An issue is `Done` only after the PR is merged by tech-lead following a passed final check.
- Close the milestone only when all required issues are done or explicitly deferred.
- Record follow-up debt, defer items, and unresolved risks before closing the milestone.

## State Machine

Use a small, explicit workflow state machine. Prefer these states unless the repository already has an established equivalent:

- `Inbox`
- `Shaping`
- `Need attentions`
- `Ready`
- `In Progress`
- `In Review`
- `Ready to Merge`
- `Blocked`
- `Done`

State changes should be meaningful, not decorative.

Use them like this:

- `Inbox`: captured but not yet shaped
- `Shaping`: being refined by strategist and/or founder
- `Need attentions`: waiting for internal role resolution (strategist/tech-lead) or for a founder decision; a durable GitHub comment must exist before moving here naming who needs to act and what they need to decide
- `Ready`: approved for implementation with clear scope
- `In Progress`: builder is actively executing
- `In Review`: waiting for reviewer review or re-review
- `Ready to Merge`: reviewer has approved with no blockers and posted an explicit approval comment on the PR; waiting for tech-lead final check and merge
- `Blocked`: cannot safely proceed without a dependency or decision
- `Done`: PR merged and validated

Additional rule:

- A spec-level milestone should not be treated as execution-ready until it has concrete child issues, and at least one non-blocked child issue is in `Ready` when execution can begin.
- During execution, prioritize issues by spec group before jumping across specs. Break that rule only for explicit dependencies, blockers, or human-intervention waits.
- During sprint planning, inspect issues in `Need attentions` before pulling fresh `Ready` work. Resolve them through strategist or tech-lead when safe, then move them back to `Ready` or escalate only if no safe internal path remains.

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

For builder-owned implementation handoffs, the delegated agent should also record the branch, PR, verification evidence, and review focus so the next role can continue from GitHub alone.

When an agent moves an issue to `Need attentions`:

- leave a durable GitHub comment first
- explain what attention is needed
- name whether strategist or tech-lead should resolve it first
- state the smallest decision or clarification needed to move the issue back toward `Ready`

When `tech-lead` asks `strategist` to clarify a spec or issue during execution:

- record the clarification request and resolution in GitHub comments
- keep the issue in the current spec group unless it is blocked
- skip to another issue only when waiting on a real blocker or human input

Comments alone are not sufficient when the next action is "implement". That next action must point to an actual task issue, not just a discussion thread.

Do not rely on chat memory alone for decisions that affect future work.

## Review Loop Rules

- Validation findings are the primary output of the reviewer.
- Findings should be specific enough for a builder to act on without guessing.
- Rework should stay within the approved scope unless the user or tech-lead expands it.
- Keep review loops bounded.
- If the same architectural problem repeats across several loops, escalate instead of thrashing.
- The reviewer checks builder output against the approved task and guardrails. The reviewer does not make new product or architecture decisions; when findings imply a deeper technical decision, escalate to `tech-lead`.

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
When the orchestrator owns the queue pass, the orchestrator is responsible for running that preflight and confirming there is no safe remaining role invocation before founder escalation on execution blockers.
When the blocker is a true product, scope, prioritization, or business-direction question, `strategist` may run that preflight and decide that founder input is needed.
Do not use that preflight as a gate on normal strategist-founder planning, spec review, or sprint discussion.

## Approval Rules

- `strategist` helps prepare the spec but does not overrule the founder.
- `tech-lead` determines technical go/no-go and guardrails.
- `strategist` and `tech-lead` do not complete their phase by leaving advice in comments only. If the work should proceed, they must ensure task issues exist and the next builder-facing state is explicit.
- `builder` does not self-approve implementation readiness.
- `reviewer` decides whether builder output is approved for merge readiness, returned for rework, or blocked. Approval means: posting an explicit approval comment on the PR and moving the issue to `Ready to Merge`. The reviewer does not merge.
- `tech-lead` owns the final spec-alignment check and the merge decision. Tech-lead is the only role that merges. Tech-lead either merges and marks the issue `Done`, or posts findings and moves the issue to `Need attentions` for builder to address.
- Merge must not happen before reviewer approval (`Ready to Merge`) and tech-lead final check. No role bypasses this sequence.

## Usage Guidance

- Use this skill first when designing or adjusting the overall workflow.
- Use this skill to interpret how GitHub milestones, issues, projects, comments, branches, PRs, and agent roles fit together.
- Use lower-level workflow skills for detailed execution mechanics after the top-level flow is clear.
- If the workflow starts to feel heavy, reduce issue size and simplify state transitions before adding more agent roles.
