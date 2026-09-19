---
name: github-conventions
description: Use when work is already being managed through the GitHub delivery flow and the agent needs specific conventions for milestones, issues, labels, comments, PRs, or repository-doc linking. Prefer `github-agentic-delivery-flow` for the overall workflow model; use this skill for detailed GitHub artifact mapping.
---

# GitHub Conventions

Use this skill whenever the delivery workflow already depends on GitHub artifacts and the agent needs to apply the detailed conventions consistently.

This skill defines how GitHub should represent workflow concepts. It does not replace the repository spec, task logic, or review rules. Use it to keep GitHub structure aligned with the broader delivery flow.

## Purpose

Use GitHub as the shared operational surface for multi-agent delivery while keeping product documentation in the central Obsidian vault and code implementation detail in the repository.

## Core Mapping

Apply this mapping consistently:

| Workflow Concept | GitHub Artifact |
|---|---|
| Spec / Deliverable | GitHub Milestone |
| Task | GitHub Issue |
| Workflow State | GitHub Project item status |
| Implementation artifact | GitHub Branch + Pull Request |
| Collaboration Record | GitHub issue + linked pull request + GitHub Project `Workflow State` |
| Handoffs, blockers, escalations, and task decisions | GitHub issue comments; use PR comments for code-specific discussion |
| Final closing message / approval | GitHub issue and pull request comments |
| Product and architecture documentation | Curated central Obsidian vault project path linked from the milestone or issue |
| Code implementation detail | Project repository and pull request |

Do not treat milestone text as the full spec.

## Milestones

Use one milestone per spec or deliverable.

A milestone should contain:

- short summary
- link to the canonical spec doc
- owner
- target outcome
- status summary if useful

Use milestones to group all execution issues for one deliverable.

## Issues

Use one issue per scoped executable task.

Each issue should include:

- task goal
- scope
- dependencies
- acceptance criteria
- verification expectation
- linked milestone
- `Durable Context` with the canonical SPEC URL and exact URLs for applicable ARCH, ADR, GOV, and runbook notes; use `Not applicable — reason` when absent
- open decisions with owner and blocking status
- role owner

Avoid giant issues that hide multiple major decisions. A builder starts from the issue and follows its Durable Context URLs; it must not need to reconstruct requirements from chat or conduct a broad vault search.

## Project States

Canonical happy path:

- `Open`
- `Backlog`
- `Ready`
- `In Progress`
- `In Review`
- `Ready to Merge`
- `Done`

Exception states:

- `Need attentions` — founder-only decision state, entered only after strategist and tech-lead review
- `Blocked` — exception state after tech-lead/strategist resolution failed; any state may enter it, typically `In Progress` or `In Review`

The canonical board field is `Workflow State`. Legacy option names such as `Inbox` (now `Open`) and `Shaping` (now `Backlog`) may still exist on the remote board; do not rename remote options without explicit founder-approved handling.

If the repository already uses equivalent project states, preserve the established system rather than inventing a competing one.

## Labels

Recommended labels:

- `role:strategist`
- `role:tech-lead`
- `role:builder`
- `role:reviewer`
- `type:feature`
- `type:bug`
- `type:debt`
- `risk:high`
- `status:blocked`
- `security`

Use labels to improve filtering and routing, not as a substitute for clear issue content.

## Comments

Use issue comments for:

- concise handoffs at meaningful role boundaries or state changes
- task decisions, blocker and escalation status, and founder decision requests
- current owner, next action, closure, and completion confirmations
- links to durable Obsidian documentation when it constrains the task

Use PR descriptions for implementation summaries, verification evidence, known risks or skipped checks, review focus, and the builder-to-reviewer delegation. Use PR comments for code-specific findings, review threads, responses, approval evidence, reviewer-to-builder rework delegation, and merge confirmation.

Use the standard `## Delegation — <source> → <target>` format from `agent-communication-log`. The direct sub-agent instruction must include the same issue/PR URL, purpose, authoritative context URLs, expected action, and expected GitHub record; GitHub stores the durable handoff, not a copy of the entire runtime prompt.

The GitHub issue, linked pull request, and Project `Workflow State` are the Collaboration Record. They must let the next role continue without a chat transcript or separate Obsidian event file. Record review-loop history, if needed, in the issue or PR.

When strategist and tech-lead discuss a spec during shaping, record the actionable conclusion, owner, and next action in the milestone or shaping issue. Update Obsidian only when the conclusion changes a curated spec, architecture reference, ADR, governance policy, runbook, or other reusable durable knowledge.

## Source Of Truth Rules

- Keep curated product specs, architecture notes, ADRs, governance, lifecycle, runbooks, and reusable project knowledge in the central Obsidian vault.
- Keep code-adjacent implementation detail in the project repository and pull request.
- Link the canonical SPEC from the milestone and every execution issue. Link each applicable ARCH, ADR, GOV, and runbook directly from the issue's `Durable Context`; GitHub links use normal URLs because it cannot resolve Obsidian wikilinks.
- Keep task-local discussion, handoffs, blockers, escalation requests, review outcomes, and ownership decisions in GitHub.
- Keep GitHub Project status fields authoritative for workflow state.
- Do not create an Obsidian issue vault, per-task communication-event mirror, or routine task note.
- Create or update an Obsidian document only for durable knowledge that meets GOV-001's write threshold.
- Role memory is event-triggered and contains only reusable lessons; do not create `No new durable memory` entries.
- Keep code-specific review on the pull request.
- Reconcile GitHub artifacts and durable documentation if they drift.

## Usage Guidance

- Use this skill when creating or reviewing GitHub workflow structure.
- Use this skill before defining milestone, issue, project, or label conventions.
- Use this skill with `github-agentic-delivery-flow` when designing the overall delivery system.
