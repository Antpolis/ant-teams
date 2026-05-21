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
| Last Updated | 2026-05-19 |

## Summary

This document defines the company-wide skill delegation policy for the one-person-company workflow.

## Context

The company uses reusable skills to steer agent behavior. Some skills are intentionally global and may be used by any role. Others are intentionally role-targeted and should only be used by specific agents.

## Decision

This company adopts the following skill delegation table:

| Skill | Scope | Primary roles |
|---|---|---|
| `agentic-flow-terms` | Global | All roles |
| `github-agentic-delivery-flow` | Global | workflow-design roles, strategist, tech-lead, architect |
| `github-conventions` | Global | workflow-design roles, delivery-manager, architect |
| `state-transitions` | Global | delivery-manager, architect, validator |
| `approval-and-escalation` | Global | architect, validator, tech-lead |
| `agent-communication-log` | Global | architect, delivery-manager, developer, architect-reviewer, QA |
| `role-memory` | Global | architect, developer, architect-reviewer, QA |
| `pr-review-flow` | Global | developer, architect-reviewer |
| `how-to-create-task` | Role-targeted | delivery-manager |
| `task-development` | Role-targeted | developer |
| `task-completion` | Role-targeted | architect-reviewer, QA |
| `documentation-standard` | Role-targeted | architect |
| `release-management` | Role-targeted | architect |
| `security-review` | Role-targeted | developer, architect, architect-reviewer |
| `platform-engineering` | Role-targeted | developer, architect |

The company installation model is also split into two layers:

- Global company install: `~/.config/opencode` holds the company defaults, agents, skills, plugin, and enterprise docs.
- Project docs scaffold: each project repo keeps its own `docs/` or `.docs/` tree for local documentation, governance, and durable memory or retrospective artifacts.
- GitHub is the collaboration system of record for milestone state, issue state, handoffs, blockers, review findings, approvals, and cross-role coordination.
- When both exist, project docs take precedence over global enterprise defaults for that repo.

## Consequences

- Global skills are available to all roles, but agents should still prefer the most specific allowed skill for the work.
- Role-targeted skills should stay confined to the listed roles unless this decision is updated.
- Governance roles must not drift into implementation-only skills.

## Enforcement

- Keep agent prompts aligned with this table.
- Update this document before changing role boundaries in prompts or skills.
- If a new skill is added, classify it as global or role-targeted here first.

## Related Documents

- `docs/DOCUMENT_INDEX.md`
- `one-person-company/skills/agentic-flow-terms/SKILL.md`
- `one-person-company/skills/github-agentic-delivery-flow/SKILL.md`
