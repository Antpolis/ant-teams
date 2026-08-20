---
name: how-to-create-task
description: Use when tech-lead is creating, splitting, sequencing, or documenting execution tasks for a spec in GitHub. Tech-lead is the sole owner of the GitHub milestone and all execution issues. No other role creates or modifies milestones or issues in normal flow.
---

# How To Create Tasks

Use this skill when tech-lead is turning an approved, implementation-ready spec into a GitHub milestone and execution issues.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by tasks.
Use the GitHub workflow skills for milestone, issue, state, approval, and escalation conventions.

## Ownership Rule

Tech-lead is the sole owner of the GitHub milestone and every execution issue for a spec.

- No other role creates the milestone or any issue in normal flow.
- No other role sets sequence positions, tech-lead guardrails, or moves issues to `Ready`.
- If orchestrator or strategist needs a task created, they must request it from tech-lead, not create it themselves.
- Strategist confirms the issue set maps to business value after tech-lead creates it — strategist does not create or modify issues to make them fit.

## Core Rules

All tasks for one spec live as separate GitHub issues linked to the same GitHub milestone.

Do not use local markdown task files as the execution surface.
Do not stop at comments if the intended next role is builder — create the actual GitHub issues.
If strategist and tech-lead refine scope or sequencing, write the resolved outcome to the milestone as a durable GitHub comment before creating issues. Do not create issues from unresolved discussion.

## Required Inputs — Hard Gate

Before creating any issue or milestone, tech-lead must read the spec and confirm every item below exists and is complete. If any item is missing, stop and return the spec to strategist or tech-lead authoring — do not create partial issues and do not proceed.

Business sections (must be present in the spec — written by strategist):
- [ ] Problem statement
- [ ] Business value
- [ ] Success metrics
- [ ] Goals
- [ ] Non-goals
- [ ] Stakeholders
- [ ] Constraints

Technical sections (must be present in the spec — written by tech-lead; each must be present or explicitly marked "not applicable" with a reason):
- [ ] Functional requirements
- [ ] Technical requirements
- [ ] Data model changes (new or modified tables, indexes, migrations, seed data)
- [ ] API changes (new or modified endpoints, contracts, versioning, breaking changes)
- [ ] Security considerations (auth changes, data sensitivity, secrets handling, threat model)
- [ ] Integration points (external or internal services, queues, webhooks; failure behaviour for each)
- [ ] Observability requirements (logging, metrics, alerting, tracing)
- [ ] Error handling (user-facing errors, retry or fallback behaviour, failure modes)
- [ ] Testing strategy (what must be tested, who writes tests, coverage expectations)
- [ ] Architecture notes referencing relevant central Obsidian project docs; any new ADR or ARCH doc needed
- [ ] Acceptance criteria at the spec level
- [ ] Rollout and rollback plan (phasing, feature flags, migration steps, rollback procedure)

Also confirm:
- [ ] Relevant architecture docs in the central Obsidian project folder have been read and inform the guardrails for this spec
- [ ] No open shaping discussion remains unresolved in chat or comments

If any checkbox cannot be checked, record which items are missing as a GitHub comment on the milestone, leave the milestone in `Shaping`, and stop. Do not create issues from an incomplete spec.

## Milestone Template

Tech-lead creates the milestone before creating any issue. Use `.github/milestone-template.md` as the authoritative template. The required structure is:

```md
## Spec

- Spec document: <path to spec file in repo>
- Spec ID: <SPEC-ID>
- Milestone created by: tech-lead

## Delivery Intent

<One sentence: what this milestone delivers and why it matters to the business.>

## Summary

<What the deliverable is, the problem it solves, and the expected business outcome.>

## Success Criteria

- <Criterion 1 — specific and observable>
- <Criterion 2>

## Scope

- Included:
- Excluded:

## Risks

- <Key delivery, technical, or business risks and mitigations>

## Issue Sequence

| # | Issue | Type | Depends on | Parallel-safe with |
|---|---|---|---|---|
| 1 | <issue title> | backend | none | — |
| 2 | <issue title> | data model | #1 | — |

## Required Task Types Coverage

- [ ] Data model / migration — issue exists or excluded: <reason if excluded>
- [ ] API / contract — issue exists or excluded: <reason if excluded>
- [ ] Backend / business logic — issue exists or excluded: <reason if excluded>
- [ ] Frontend / UI — issue exists or excluded: <reason if excluded>
- [ ] Infrastructure / configuration — issue exists or excluded: <reason if excluded>
- [ ] Integration — issue exists or excluded: <reason if excluded>
- [ ] Security — issue exists or excluded: <reason if excluded>
- [ ] Observability — issue exists or excluded: <reason if excluded>
- [ ] Error handling — issue exists or excluded: <reason if excluded>
- [ ] Documentation — issue exists or excluded: <reason if excluded>
- [ ] Testing / QA — issue exists or excluded: <reason if excluded>

## Spec Coverage Confirmation

- [ ] Every spec acceptance criterion is traceable to at least one issue
- [ ] Every functional requirement is addressed by at least one issue
- [ ] Every technical requirement is addressed by at least one issue
- [ ] Every data model, API, security, observability, and error handling requirement is addressed
- [ ] Strategist has confirmed the issue set maps to business value and acceptance criteria

## Architecture Docs Referenced

- <path to arch doc used to set guardrails>

## Exit Rule

Close this milestone only when all required issues are Done or explicitly deferred with rationale recorded as a GitHub comment.
```

## GitHub Issue Template

Use this structure for each task issue:

```md
## Why

<One sentence: what business or product problem does this task contribute to, and why does it matter. Reference the spec's problem statement.>

## Outcome

<Describe the specific result this issue should produce.>

## Scope

- In scope:
- Out of scope:

## Dependencies

- Spec / milestone:
- Blocking issues:
- Architecture docs:

## Tech-Lead Guardrails

- Architecture constraints for this issue:
- Folder / package / namespace rules (cite the relevant architecture doc):
- Patterns to follow or avoid:
- Known risks or sequencing notes:

## Acceptance Criteria

- [ ] Criterion 1 (traceable to spec acceptance criteria — cite which one)
- [ ] Criterion 2

## Verification

- Commands or checks:
- Evidence expected:

## Definition of Done

- [ ] Acceptance criteria above are all passing
- [ ] Verification commands pass
- [ ] No KISS, separation of concerns, or folder/package/namespace violations (per architecture docs cited above)
- [ ] PR created with builder handover note
- [ ] Reviewer approved and posted approval comment — issue moved to Ready to Merge
- [ ] Tech-lead final check passed and PR merged

## Owner

- Current role:
- Current assignee:
- Sequence position: <number in tech-lead ordered list>

## Links

- Spec:
- PR:
- Architecture docs:
- Related docs:
```

## Task Quality Bar

Every task must include:

- A Why statement linking the task to the spec's business problem
- Enough implementation detail for a builder to start without re-planning
- Tech-lead guardrails specific to this issue (not just generic principles)
- Clear dependencies and sequence position
- Acceptance criteria traceable to the spec's acceptance criteria
- Verification expectations
- A link to the milestone and spec document
- The current responsible role or assignee

Every task must also be builder-activatable:

- a builder should be able to start from the issue without reconstructing scope from scattered comments or re-reading the full spec
- if the issue is ready now, set the owner role to builder and move it to `Ready` — but only after tech-lead has sequenced all issues for this spec pass
- if it is not ready, say exactly what is missing and leave it in `Shaping` or `Blocked`

## Sequencing and Coverage — Hard Gate

Tech-lead must complete all sequencing and coverage checks before any issue is moved to `Ready`. This is a hard gate — not a best-effort check.

Sequencing (tech-lead):
- [ ] All issues for this spec are created
- [ ] Each issue has a Sequence Position assigned
- [ ] The full sequence is recorded in a durable GitHub comment on the milestone
- [ ] Parallelism conflicts are identified and resolved or called out

Coverage (tech-lead confirms, strategist co-signs):
- [ ] Every spec acceptance criterion is traceable to at least one issue
- [ ] Every functional requirement is addressed by at least one issue
- [ ] Every technical requirement is addressed by at least one issue
- [ ] Every data model, API, security, observability, and error handling requirement is addressed by at least one issue
- [ ] Required Task Types checklist is fully worked through — every type has an issue or an explicit exclusion with written reason in the milestone
- [ ] Documentation and testing/QA tasks exist or their exclusion is justified in writing
- [ ] No spec scope is left without a corresponding issue

Strategist sign-off:
- [ ] Strategist has confirmed the issue set maps to the spec's business value and acceptance criteria

If any checkbox fails, create the missing issue or record the gap in a GitHub milestone comment. Do not move any issue to `Ready` until every checkbox above is checked. Partial sequencing and partial coverage are not acceptable stopping points.

## GitHub-Only Rule

- GitHub issues are the only execution task records for this workflow.
- GitHub Project status is the only canonical task board for workflow state.
- GitHub issue comments and PR comments are the only canonical collaboration log for task execution.
- Repository docs remain the canonical place for specs, architecture, ADRs, GOV docs, and other reusable guidance.

## Required Task Types — Hard Gate

Tech-lead must work through this checklist for every spec. Each task type must either have at least one issue created, or be explicitly excluded with a written reason recorded in the milestone's "Excluded Task Types" section. Silently skipping a type is not acceptable.

- [ ] Data model / migration tasks — schema changes, new tables, index changes, seed data, migration scripts
- [ ] API / contract tasks — new or modified endpoints, request/response contracts, versioning, breaking change handling
- [ ] Backend / business logic tasks — service changes, domain logic, handlers, workers
- [ ] Frontend / UI tasks — components, pages, flows, client-side state (mark N/A if no frontend)
- [ ] Infrastructure / configuration tasks — deployment config, environment variables, secrets, IaC changes
- [ ] Integration tasks — third-party or internal service connections, queue consumers or producers, webhooks
- [ ] Security tasks — auth changes, permission model updates, sensitive data handling, secrets rotation
- [ ] Observability tasks — logging additions, metrics emission, alerting rules, tracing setup
- [ ] Error handling tasks — user-facing error surfaces, retry logic, fallback behaviour
- [ ] Documentation tasks — spec update, runbook, API docs, architecture doc update, DOCUMENT_INDEX update
- [ ] Testing / QA tasks — unit tests, integration tests, end-to-end tests, smoke test updates

Documentation and testing tasks are required by default. If either is excluded, a written justification must appear in the milestone before any issue moves to `Ready`.

Split tasks by ownership boundary rather than chronology. If two tasks would touch the same files concurrently, call out the conflict, resolve it by resequencing, or split differently. Tasks should be as parallelisable as the dependencies allow.

Use the GitHub workflow skills to decide project states, blockers, approvals, and escalation behaviour.

## Required Handoff Outcome

When this skill is used as part of spec execution setup, finish with one of these outcomes:

1. one or more builder-ready issues created and moved to `Ready`
2. issues created but explicitly left in `Blocked` with the blocker recorded
3. a clear escalation that says why task creation cannot safely continue

Do not finish with only a planning comment if the user expects delivery work to continue.
