# Skill Delegation Table

Metadata:

| Field | Value |
|---|---|
| ID | ARCH-001 |
| Type | arch |
| Domain | agentic workflow |
| Status | active |
| Owner | one-person-company |
| Applies To | all agents |
| Keywords | skill delegation, global skills, role-targeted skills, agent scope, workflow policy |
| Related Docs | agentic-flow-terms, github-agentic-delivery-flow, docs/DOCUMENT_INDEX.md |
| Supersedes |  |
| Last Updated | 2026-05-23 |

## Summary

This document defines the company-wide skill delegation policy for the one-person-company workflow.

## Context

The company uses reusable skills to steer agent behavior. Some skills are intentionally global and may be used by any role. Others are intentionally role-targeted and should only be used by specific agents.

## Decision

This company adopts the following skill delegation table:

| Skill | Scope | Primary roles |
|---|---|---|
| `agentic-flow-terms` | Global | All roles |
| `github-agentic-delivery-flow` | Global | orchestrator, strategist, tech-lead, builder, reviewer |
| `github-conventions` | Global | orchestrator, strategist, tech-lead, builder, reviewer |
| `state-transitions` | Global | orchestrator, tech-lead, builder, reviewer |
| `approval-and-escalation` | Global | orchestrator, strategist, tech-lead, builder, reviewer |
| `agent-communication-log` | Global | orchestrator, strategist, tech-lead, builder, reviewer |
| `role-memory` | Global | orchestrator, tech-lead, builder, reviewer |
| `orchestrator-task-done` | Global | orchestrator |
| `pr-review-flow` | Global | builder, reviewer |
| `how-to-create-task` | Role-targeted | strategist, tech-lead |
| `task-development` | Role-targeted | builder |
| `task-completion` | Role-targeted | reviewer |
| `documentation-standard` | Role-targeted | orchestrator, strategist, tech-lead |
| `development-hygiene` | Role-targeted | tech-lead, builder, reviewer |
| `release-management` | Role-targeted | orchestrator, tech-lead |
| `security-review` | Role-targeted | orchestrator, tech-lead, builder, reviewer |
| `platform-engineering` | Role-targeted | tech-lead, builder |

The company installation model is also split into two layers:

- Global company install: `~/.config/opencode` holds the company defaults, agents, skills, plugin, and enterprise docs.
- Project docs scaffold: each project repo keeps its own `docs/` or `.docs/` tree for local documentation, governance, and durable memory or retrospective artifacts.
- GitHub is the collaboration system of record for milestone state, issue state, handoffs, blockers, review findings, approvals, and cross-role coordination.
- When both exist, project docs take precedence over global enterprise defaults for that repo.

## Consequences

- Global skills are available to all roles, but agents should still prefer the most specific allowed skill for the work.
- Role-targeted skills should stay confined to the listed roles unless this decision is updated.
- Orchestrator may use only the workflow, reconciliation, escalation, and documentation skills needed to move a queue pass forward; it should not drift into general implementation work.
- Builder and reviewer should remain the primary implementation and review roles even when orchestration is aggressive.
- Release tags, GitHub releases, and milestone release references should be normalized through `release-management` so sprint reconciliation does not leave post-cleanup release fixes behind.

## Enforcement

- Keep agent prompts aligned with this table.
- Update this document before changing role boundaries in prompts or skills.
- If a new skill is added, classify it as global or role-targeted here first.

## Related Documents

- `docs/DOCUMENT_INDEX.md`
- `one-person-company/skills/agentic-flow-terms/SKILL.md`
- `one-person-company/skills/github-agentic-delivery-flow/SKILL.md`
