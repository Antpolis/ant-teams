---
name: how-to-create-task
description: Use when creating, splitting, refining, or documenting implementation tasks for a product spec or enhancement spec in GitHub. Use GitHub issues as tasks, linked to the relevant milestone/spec, with clear scope, dependencies, acceptance criteria, and verification expectations.
---

# How To Create Tasks

Use this skill whenever turning a product spec, enhancement spec, architecture plan, or approved deliverable into GitHub implementation tasks.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by tasks.
Use the GitHub workflow skills for milestone, issue, state, approval, and escalation conventions.

## Core Rule

All tasks that belong to one spec should live as separate GitHub issues linked to the same GitHub milestone.

Do not use local markdown task files as the primary collaboration surface.
Do not stop at strategist or tech-lead comments if the intended next role is builder. Create the actual GitHub issues.
If strategist and tech-lead refine scope or sequencing before task creation, write the resolved discussion back to the milestone or shaping issue as a durable GitHub comment before or alongside the task split.

## Required Inputs

Before creating tasks, read or establish:

- The parent spec or enhancement request
- Relevant docs from the repository docs root
- Architect viability notes and guardrails
- Known dependencies, constraints, and non-goals

If these are missing, call that out before task creation.

If the spec is approved and technically viable, task creation is not optional busywork. It is the handoff mechanism that allows builders to start.

## GitHub Issue Template

Use this structure for each task issue:

```md
## Outcome

<Describe the specific result this issue should produce.>

## Scope

- In scope:
- Out of scope:

## Dependencies

- Spec / milestone:
- Blocking issues or docs:

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Verification

- Commands or checks:
- Evidence expected:

## Owner

- Current role:
- Current assignee:

## Links

- Spec:
- PR:
- Related docs:
```

## Task Quality Bar

Every task must include:

- Enough implementation detail for a builder to start without re-planning
- Clear dependencies
- Acceptance tests specific to the task
- Verification expectations
- A link to the milestone/spec
- The current responsible role or assignee

Every task must also be builder-activatable:

- a builder should be able to start from the issue without reconstructing scope from scattered comments
- if the issue is ready now, set the owner role to builder and move it to `Ready`
- if it is not ready, say exactly what is missing and leave it in `Shaping` or `Blocked`

## GitHub-Only Rule

- GitHub issues are the only execution task records for this workflow.
- GitHub Project status is the only canonical task board for workflow state.
- GitHub issue comments and PR comments are the only canonical collaboration log for task execution.
- Repository docs remain the canonical place for specs, architecture, ADRs, GOV docs, and other reusable guidance.

## Splitting Guidance

Split tasks by ownership boundaries, not just chronology:

- API contracts
- Data model and migrations
- Backend behavior
- Frontend behavior
- Infrastructure/configuration
- Documentation
- Tests and verification

Tasks should be parallelizable where possible. If two developers would likely edit the same files at the same time, call out the conflict or split differently.

Use the GitHub workflow skills to decide project states, blockers, approvals, and escalation behavior.

## Required Handoff Outcome

When this skill is used as part of spec execution setup, finish with one of these outcomes:

1. one or more builder-ready issues created and moved to `Ready`
2. issues created but explicitly left in `Blocked` with the blocker recorded
3. a clear escalation that says why task creation cannot safely continue

Do not finish with only a planning comment if the user expects delivery work to continue.
