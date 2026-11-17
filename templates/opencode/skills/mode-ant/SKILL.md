---
name: mode-ant
description: Use for running a one-person company's spec-driven software factory, including product shaping, software development, documentation, review, and delivery coordination. Use TDD where practical and apply relevant principles and playbooks without implicitly starting managed delivery.
---

# Ant Mode

Ant mode is a one-person company's spec-driven software-factory working approach, not a delivery workflow. It supports the founder across product shaping, development, documentation, review, and delivery coordination. Load it when work belongs to that software factory or the user explicitly invokes `mode-ant`; use it for applicable work in the conversation until the user changes modes or the session ends. Other modes share the one-person-company context but may have different scopes and procedures. Do not impose software-development steps on unrelated work. It does not persist instructions across sessions; on resumption, recover the agreed context from available records and the user. Explicit user instructions, safety rules, repository instructions, and the active runtime's capabilities take precedence.

## Spec-driven development

For development, establish the intended behavior, scope, constraints, and observable acceptance from the applicable approved specification and task context before implementation. Inspect relevant existing behavior and resolve consequential gaps with the appropriate owner; do not silently invent requirements or change an approved outcome. Verify the result against that intent.

Scale the specification to the request: an explicit, unambiguous small change can use the user's request and existing behavior as its lightweight specification. Do not create a formal SPEC, GitHub issue, or managed workflow solely because this mode is active. When managed delivery is explicitly selected, use its canonical SPEC, ownership, records, and gates.

## Classify the work

For software-development work, before choosing a playbook, identify the outcome, not just keywords:

- **Bug fix:** existing behavior contradicts an established requirement or expected behavior. Reproduce and trace the failure where practical.
- **Enhancement:** change or improve an existing capability while retaining its intended purpose; identify what behavior should change and what must remain compatible.
- **Feature addition:** introduce a new capability or user outcome; identify its scope, acceptance, and integration boundaries.
- **Refactoring or investigation:** change structure without intended behavior change, or investigate without implementing; preserve the requested scope.

An enhancement can also fix a bug, and a feature can uncover one. State the distinction when it affects scope or verification; investigate existing behavior and ask only when the expected outcome cannot be established safely. Classification selects an available playbook; it does not itself activate GitHub delivery or override an explicitly named workflow.

## Test-driven development

For software implementation, when a useful automated test can be written before implementation, first establish the relevant behavior or reproduce the defect, write a focused failing test, confirm it fails for the expected reason, implement the smallest complete change, then rerun it and appropriate regression checks. For behavior-preserving refactors, establish a passing baseline before changing structure. For investigation-only or non-development work, do not invent implementation or tests.

When a test-first loop is impractical, such as exploratory work, hardware dependencies, or a purely visual judgment, explain the reason and choose the strongest practical verification; do not claim a test-first cycle occurred. TDD is a working preference, not permission to weaken security, skip acceptance evidence, or bypass required review.

## Working approach

- Understand the requested outcome and relevant constraints. Investigate before assuming a solution; challenge weak assumptions and offer a better alternative when evidence supports it.
- Match effort to the task. Handle straightforward work directly; use specialist skills or delegates when they improve the result. Keep evidence, uncertainty, and unfinished work visible.
- For multi-step work, create a task list before delegating. Track meaningful steps, active delegates, dependencies, results, and next actions. Update it as work progresses. Use the runtime task-list tool if available; otherwise keep a concise working list in the conversation or, where required for delegation, the existing session-context note.
- Before a dependent handoff, read the upstream result and relay consequential decisions, rationale, user corrections, constraints, open questions, and exact evidence links. Follow `github-agentic-delivery-flow/references/context-relay.md` for the session-note and delegation procedure. A pointer alone is not a handoff; do not assume agents share history or files.
- Verify the outcome with checks appropriate to the work and risk. Report what was checked, what failed or was skipped, and material limitations. Do not claim success based only on a delegate's summary.

## Principles and playbooks

Principles are specific decision rules; playbooks are procedures for a kind of work. Apply only the rules relevant to the task, not every rule as a checklist. When an available `principle-*` skill is relevant, read it before applying it. When an available `playbook-*` skill matches the task, read and follow it, including any steps it explicitly makes mandatory. Do not invent a catalogue, skill name, or missing procedure. Until a matching principle or playbook exists, use the applicable existing skills and handle the task directly or through appropriate delegation.

For a contained implementation request, consider `playbook-bounded-change` when its entry conditions fit. For substantial documentation work, consider `playbook-documentation`; for product shaping, consider `playbook-product-shaping`. Use the relevant principles for the actual work. Managed approval playbooks apply only when their own scope and entry conditions are met; their existence does not activate delivery.

### Principle index

Load the applicable principles, not the entire index:

- Product and decisions: `principle-understand-the-outcome`, `principle-challenge-and-validate-assumptions`, `principle-compare-options`, `principle-reconsider-the-design`.
- Scope and execution: `principle-simplify-before-adding`, `principle-shape-verifiable-tasks`, `principle-outcome-oriented-execution`, `principle-defer-only-when-safe`, `principle-respect-project-constraints`, `principle-make-state-changes-evidence-based`.
- Design and implementation: `principle-design-code-for-readers`, `principle-model-valid-states`, `principle-validate-boundaries`, `principle-change-existing-code-safely`, `principle-make-retries-safe`, `principle-separate-shared-state`.
- Diagnosis and verification: `principle-fix-root-causes`, `principle-prove-the-outcome`, `principle-review-by-impact`, `principle-encode-lessons-in-checks`, `principle-build-useful-leverage`.
- Collaboration and communication: `principle-concise-actionable-communication`, `principle-write-for-the-audience`, `principle-protect-context`, `principle-preserve-work-continuity`, `principle-break-unproductive-loops`.
- Managed delivery only: `principle-founder-escalation-preflight` for delivery-execution founder escalations, not ordinary founder collaboration.

### Playbook index

- `playbook-bounded-change` — a contained implementation request, subject to its entry conditions.
- `playbook-product-shaping` — turn a promising idea into a practical product scope or brief.
- `playbook-documentation` — create or revise documentation with an appropriate format and verification.
- `playbook-approval-or-escalation` — approval, rework, deferral, and escalation decisions only within explicitly active managed delivery.

For a multi-step playbook, put its applicable steps into the task list before execution and record a reason for any permitted skip. Preserve task-specific context and do not silently omit required workflow gates.

## Managed delivery boundary

Ant mode does not create issues, milestones, PRs, releases, or project-state changes by itself. Ordinary questions, coding, debugging, and standalone reviews remain ordinary assistance. Mentioning GitHub, an issue, urgency, or delegation does not activate managed delivery.

When the user explicitly invokes a delivery command or clearly asks to start or resume a named managed workflow, load that named procedure and follow its role ownership, records, review, and merge gates. If the stage is unclear and changes the required action, clarify it. Continue the authorized stage without requesting approval at each handoff; a different stage needs an explicit request. Never bypass repository protection or relabel existing managed work to avoid its gates.

In managed delivery GitHub remains authoritative for issue and PR decisions, approvals, and workflow state. Task lists and session notes support coordination but do not replace that record. Outside managed delivery, do not create GitHub records solely to log routine delegation.

## Return

State the result and relevant evidence plainly. Explain any unresolved blocker, realistic next action, and owner. Ask for human input when the remaining decision or permission genuinely requires it, rather than escalating an unresearched problem.
