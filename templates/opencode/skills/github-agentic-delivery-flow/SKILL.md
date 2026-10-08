---
name: github-agentic-delivery-flow
description: "Shared GitHub development operating model: issue and milestone ownership, communication, workflow states, independent review, and merge gates. Consult for managed delivery, bugfix, or hotfix; loading guidance does not start execution."
disable-model-invocation: true
---

# GitHub Agentic Delivery Flow

## Guidance and execution boundaries

This skill defines how managed development uses GitHub and role collaboration. It does not own or start an execution loop. Managed development starts only through an explicit command or a clear user request to start or resume a named procedure. Loading this skill for reference or discussing its rules does not activate any procedure. Ordinary questions, coding, debugging, direct edits, and standalone reviews do not enter delivery because they mention GitHub, specs, issues, or urgency.

`ant` (Ant Agent) is the primary runtime agent. The coordinator (historically called the orchestrator) is a responsibility Ant takes within an active workflow, not a separate agent to invoke. Shared rules below define ownership and evidence for all managed development playbooks; they do not authorize execution or progression into another stage.

Procedure owners and entry points (consult only the explicitly requested procedure):

| Explicit workflow | Procedure | Boundary |
|---|---|---|
| `/new-spec` | [Shape and plan](references/new-spec.md) | Ends with planned issues; does not start implementation. |
| `/sync-spec` | [Sync existing specs](references/sync-spec.md) | Tech-lead syncs milestones/issues; does not start implementation. |
| `/do-tasks` | `do-task` and [Queue coordination](references/orchestration.md) | Owns execution of all required issues in the selected spec through review and merge. |
| `/sprint-clean` | [Reconcile delivery](references/sprint-clean.md) | Reconciles records and docs; does not start fresh implementation. |
| `/close-spec` | `spec-closeout` | Closes an explicitly requested completed spec. |

Continue the selected stage through its required handoffs and gates. Requesting one stage does not select another. Use `agentic-flow-terms`, `github-conventions`, `state-transitions`, and `approval-or-escalation` for detailed rules when needed. Do not load queue coordination for shaping, sync, reconciliation, or closeout.

## Standalone alternatives

`fix-bug` and `hotfix` are separate playbooks. Their own skills define qualification, readiness, and execution. This skill supplies their shared GitHub ownership, handoff, review, and merge rules; reading those rules does not enter shaping or the `do-tasks` spec queue.

If investigation reveals a defect that warrants another playbook, report the reason and proposed alternative. Switching requires the user's explicit request; do not select or execute it automatically.

## Specialist assignments

Before delegating, follow [Context Relay](references/context-relay.md): read and consolidate the upstream result, relevant founder corrections, decisions and rationale, and unresolved questions into the actual runtime brief. Name the active stage, assigned role, exact requested action, and applicable context. Each specialist reads [Shared Specialist Context](references/specialist-context.md) plus only its role reference: [builder](references/builder-delivery.md), [reviewer](references/reviewer-delivery.md), [strategist](references/strategist-delivery.md), or [tech-lead](references/tech-lead-delivery.md). Direct specialist assistance does not require these delivery procedures. Delegation does not transfer the coordinator's queue ownership.

## Purpose

Define a durable, inspectable operating model where:

- planned work uses a spec as its governing container; standalone fix playbooks define their own scope
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
| Workflow State | GitHub Project item status (canonical `Workflow State` field) |
| Implementation branch / PR | GitHub Branch + Pull Request |
| Collaboration Record | GitHub issue + linked pull request + GitHub Project `Workflow State` |
| Handoffs, blockers, escalations, and task decisions | GitHub issue comments; use PR comments for code-specific discussion |
| Product, architecture, and governance knowledge | Curated central Obsidian project documentation linked from the milestone or issue |
| Canonical implementation detail | Repository and linked pull request |

Do not rely on GitHub milestone text alone as the full spec. Keep the canonical spec in the central Obsidian project documentation and link it from the milestone.

## Source Of Truth Rules

- The central Obsidian project documentation is the canonical source for curated specs, architecture, ADRs, governance, runbooks, and exceptional durable decisions.
- The GitHub milestone is the tracking container for a deliverable and links to its applicable durable documentation.
- The Collaboration Record is the GitHub issue, linked pull request, and GitHub Project `Workflow State` together.
- GitHub issues are the canonical task records for scope, ownership, handoffs, blockers, escalations, and task decisions.
- GitHub Projects is the canonical workflow board for state visualization, using the canonical `Workflow State` field.
- Pull requests are the canonical implementation and code-review record, including verification evidence, findings, responses, and approval.
- Add or update Obsidian only when the result meets the GOV-001 durable-knowledge threshold; never use it as a routine task, communication-event, or review-loop mirror. The scoped exception is the orchestrator-assigned local `session-context/` note (GOV-001): one UUID-keyed note per root conversation for in-flight cross-agent context, searched with `rg`, archived on session close, never committed to the durable documentation repo, and never authoritative for Workflow State, PR approval, merge, task ownership, blockers, or closure.
- Role memory is event-triggered: record only reusable lessons, recurring constraints, or cross-task tradeoffs. Do not create no-op memory entries.
- Local markdown task files, local workflow boards, and chat transcripts are not part of the active execution flow.
- If GitHub and durable documentation disagree, reconcile them instead of silently choosing one.

## Agent Roles

Default roles in this workflow:

- `orchestrator`: owns queue-driven execution, gets the ordered issue list from tech-lead, invokes the next role directly, verifies that delegated roles left the expected GitHub artifacts, and keeps the loop moving until a real human decision is required
- `strategist`: pressure-tests the idea, sharpens the MVP, writes the business sections of the spec (problem statement, business value, success metrics, goals, non-goals, stakeholders, constraints), and confirms the issue set maps to business value before execution starts
- `tech-lead`: verifies technical feasibility and architecture direction; writes the technical sections of the spec (functional requirements, technical requirements, architecture notes, acceptance criteria); is the sole owner of the GitHub milestone and every execution issue — no other role creates or modifies milestones or issues in normal flow; sequences all issues and sets per-issue guardrails before marking anything `Ready`; performs the final spec-alignment check and is the only role that merges PRs. Tech-lead also creates or reuses the issue worktree and task branch before builder delegation and owns post-merge cleanup.
- `builder`: implements approved scoped work with focused code changes and verification in the worktree and task branch supplied by tech-lead; owns commits, pushes, and PR creation/update for the delegated task; updates task state during implementation; and leaves a durable review handover note. Builder does not create or replace worktrees or task branches in normal flow.
- `reviewer`: reviews builder output, checks scope and architecture alignment, flags unnecessary additions, performs lightweight smoke verification, and records clear findings or approval back into the GitHub workflow; routes product/scope/acceptance ambiguity to strategist and technical/architecture/verification ambiguity to tech-lead

Use specialized skills beneath these roles when the task needs domain-specific handling. The orchestration roles should stay focused on flow ownership and decision quality.

## Procedure Ownership

These conventions are references, not commands to execute every stage:

- `new-spec` owns shaping and planning. Strategist clarifies business intent; tech-lead verifies feasibility, defines the milestone and issues using `how-to-create-task`, and establishes readiness. Required decisions and requirement coverage must be resolved before tasks enter `Ready`.
- `do-tasks`, backed by `do-task`, owns the selected spec's development loop: plan the issue order, dispatch implementation, verify handoffs, obtain independent review, route merges to tech-lead, and continue until all required scoped issues are done or no safe scoped action remains. Detailed sequencing lives in that procedure.
- `fix-bug` and `hotfix` own their standalone issue procedures and artifact requirements. They use the same role ownership, communication, review, and merge conventions without inheriting whole-spec execution.
- `sprint-clean` owns explicitly requested reconciliation; it does not pull fresh implementation.
- For explicitly requested release or milestone closeout, run `spec-closeout`. `do-tasks` completion does not create a release/tag or close the milestone automatically. Keep completed Project items in `Done` as audit history.

Tech-lead is the only role that merges under the managed approval rules below. An issue is not complete merely because implementation ended or reviewer approved; merge and completion evidence must exist.

## State Machine

Use a small, explicit workflow state machine. The canonical happy path is:

`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`

Two exception states exist outside the happy path: `Need attentions` (founder-only) and `Blocked` (exception). State changes should be meaningful, not decorative.

Use them like this:

- `Open`: captured but not yet shaped
- `Backlog`: being refined by strategist and/or founder
- `Need attentions`: founder-only decision state, entered only after strategist and tech-lead review have both been attempted and neither can resolve the question; a founder-addressed GitHub comment naming the exact decision must exist before moving here
- `Ready`: approved for implementation with clear scope, verification, exact durable-context links, and no planning-blocking open decision
- `In Progress`: builder is actively executing
- `In Review`: waiting for reviewer review or re-review
- `Ready to Merge`: reviewer has approved with no blockers and posted an explicit approval comment on the PR; waiting for tech-lead final check and merge
- `Blocked`: exception state entered when tech-lead and strategist cannot resolve a dependency, decision, credential, permission, or external condition; any state may enter it, typically `In Progress` or `In Review`
- `Done`: PR merged and validated by tech-lead

Additional rule:

- A spec-level milestone should not be treated as execution-ready until it has concrete child issues, and at least one non-blocked child issue is in `Ready` when execution can begin.
- During `do-tasks`, execution stays within the selected spec or an explicitly narrowed scope. A dependency or blocker does not authorize work on another spec; request an explicit scope change when needed.
- During sprint planning, inspect issues in `Need attentions` before pulling fresh `Ready` work. Confirm strategist and tech-lead review were both attempted, surface the founder decision if one is genuinely pending, then move resolved issues back to their prior state.

## Required Issue Quality Bar

The selected playbook determines required artifacts. Planned spec work requires the linked milestone and canonical SPEC; standalone fix playbooks may record them as not applicable with a reason. Every managed task issue should include:

- problem or task outcome
- in-scope work
- out-of-scope guardrails if needed
- dependencies
- acceptance criteria
- verification steps or expected evidence
- linked milestone when required by the selected playbook
- owner role or current responsible agent
- exact links to applicable durable context: canonical SPEC for spec-based work, plus applicable ARCH, ADR, GOV, and runbooks; mark non-applicable references with a reason

If the issue is intended for a builder next, it must be actionable without requiring the builder to reinterpret strategist or tech-lead comments into a new plan.

Avoid giant issues that require multiple major decisions at once.

## Handoff Rules

At each meaningful role boundary or state change, record one concise GitHub handoff in the canonical location. Use the issue or milestone for task ownership, scope, dependencies, clarification, blockers, escalations, and workflow-state changes; use the PR for implementation detail and code review.

Every handoff should give the receiving role the information needed to continue without chat history: task outcome, source and target roles, authoritative issue/PR and durable-context links, relevant evidence, constraints or risks, exact next action, and expected record. Include the actionable upstream decisions, rationale, and constraints in the runtime brief even when recorded in linked artifacts. Link full acceptance criteria, file lists, and evidence rather than copying whole documents. Concision must not remove the information the next role needs to act.

For builder-owned implementation handoffs, the PR description is the canonical handoff and should include the branch, implementation summary, verification evidence, known risks or skipped checks, and review focus. Add an issue comment only when ownership, workflow state, scope, dependencies, or a non-code decision changes. For code-specific review/rework, use PR comments or review threads. Do not create a second comment merely to duplicate a handoff already recorded in its canonical location.

When an agent moves an issue to `Need attentions`:

- strategist and tech-lead review must both have been attempted first
- leave a concise founder-addressed GitHub comment naming the exact decision needed, the reason it is blocked, and the intended next state
- state the smallest decision or clarification needed to move the issue back toward its prior state

When `tech-lead` asks `strategist` to clarify a spec or issue during execution:

- record the clarification request, resolution, and next action in the relevant GitHub issue or PR
- update an Obsidian document only if the result changes durable product intent, architecture, governance, a runbook, or reusable cross-task knowledge
- keep execution within the selected spec; record external dependencies as blockers rather than treating them as permission to switch specs
- skip to another issue only when waiting on a real blocker or human input

Comments alone are not sufficient when the next action is "implement". That next action must point to an actual task issue, not just a discussion thread.

Do not rely on chat memory alone for decisions that affect future work.

Dependent role delegations are synchronous. Wait for the current agent to
finish and return its final response, then verify its required GitHub records
before invoking any dependent role. A posted handoff, workflow-state change,
or launch acknowledgement alone is not agent completion. An interrupted or
failed invocation does not satisfy this gate; reconcile its outcome before
proceeding. “Invoke now” and “continue in the same execution pass” mean after
these checks, never while the prerequisite role is still running.

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
- `tech-lead` owns the final spec-alignment check and the merge decision. Tech-lead is the only role that merges. If alignment passes, tech-lead merges and marks the issue `Done`. Otherwise, tech-lead posts actionable findings and returns the issue to builder rework on the same task branch and PR, followed by reviewer review. `Need attentions` is reserved for a genuine founder decision after strategist and tech-lead resolution have both been attempted; it is not a builder-rework state.
- Merge must not happen before reviewer approval (`Ready to Merge`) and tech-lead final check. No role bypasses this sequence.

## Optional Ponytail Simplification Tools

The repository ships optional Ponytail skills: `ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-debt`, and `ponytail-gain`. They complement this flow as optional aids, not flow components.

Hard precedence: ponytail tools never override correctness, security, architecture guardrails, required tests, role ownership, GitHub audit records, review gates, or merge approval. They add no new required state and no new approval gate.

Optional integration points:

- **Shaping / tech-lead planning**: `strategist` and `tech-lead` may apply the core `ponytail` ladder to challenge YAGNI, reuse of existing code, new dependencies, and task size. Record meaningful deliberate simplifications with a `ponytail:` code marker naming the ceiling and the upgrade trigger.
- **Before builder completion**: `builder` may run the core ponytail self-check. One focused executable check remains required for non-trivial changes; ponytail does not waive it.
- **During reviewer pass**: normal correctness/architecture/security review stays authoritative. `reviewer` may additionally run `ponytail-review` as a separate complexity-only pass; its findings are actionable only when they do not conflict with requirements or guardrails.
- **Milestone close / periodic maintenance**: `tech-lead` may run `ponytail-audit`. `tech-lead` may use `ponytail-debt` to inspect deferred `ponytail:` markers and convert warranted debt into GitHub issues/tasks under the existing issue-ownership rules — never silently hide it. `ponytail-gain` is informational benchmark context only and must not be used as a project metric.

When a ponytail tool invocation affects an existing task or decision, record the invocation and outcome in the normal issue/PR or milestone comments; standalone informational runs need no new record. One-shot skills (audit, debt, gain) stay one-shot; do not turn them into standing modes.

## Usage Guidance

- Consult this skill when designing or interpreting managed GitHub development conventions; discussion does not activate execution.
- Use this skill to interpret how GitHub milestones, issues, projects, comments, branches, PRs, and agent roles fit together.
- Use lower-level workflow skills for detailed execution mechanics after the top-level flow is clear.
- If the workflow starts to feel heavy, reduce issue size and simplify state transitions before adding more agent roles.
