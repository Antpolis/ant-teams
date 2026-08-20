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
| Agent-to-agent communication | Central Obsidian project communication notes |
| Final closing message / approval | GitHub issue and pull request comments |
| Product and architecture documentation | Central Obsidian vault project path linked from the milestone or issue |
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
- role owner

Avoid giant issues that hide multiple major decisions.

## Project States

Recommended states:

- `Inbox`
- `Shaping`
- `Ready`
- `In Progress`
- `In Review`
- `Blocked`
- `Done`

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

- agent handoffs
- shaping discussion summaries and clarified decisions
- findings
- blocker notes
- approval notes
- deferred follow-up decisions

Use PR comments for code-specific findings and review discussion.

When strategist and tech-lead discuss a spec during shaping, they may do the live reasoning in-agent, but they must post the durable result of that discussion back to the milestone or shaping issue before handing work forward.

## Source Of Truth Rules

- Keep product specs, architecture notes, ADRs, governance, lifecycle, and project memory in the central Obsidian vault.
- Keep code-adjacent implementation detail in the project repository.
- Link the central Obsidian document or Antpolis/documentation URL from the milestone.
- Keep agent-to-agent shaping and task-local execution discussion in the central Obsidian communication note.
- Keep GitHub status fields authoritative for workflow state.
- Link the Obsidian communication note from the issue or milestone when useful.
- Keep code-specific review on the pull request.
- Reconcile GitHub artifacts and repo docs if they drift.

## Usage Guidance

- Use this skill when creating or reviewing GitHub workflow structure.
- Use this skill before defining milestone, issue, project, or label conventions.
- Use this skill with `github-agentic-delivery-flow` when designing the overall delivery system.
