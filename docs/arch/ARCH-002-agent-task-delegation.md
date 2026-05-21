# Agent Task Delegation

Metadata:

| Field | Value |
|---|---|
| ID | ARCH-002 |
| Type | arch |
| Domain | agentic workflow |
| Status | active |
| Owner | one-person-company |
| Applies To | all agents |
| Keywords | task permissions, agent call graph, subagent delegation, workflow routing |
| Related Docs | ARCH-001, agentic-flow-terms, docs/DOCUMENT_INDEX.md |
| Supersedes |  |
| Last Updated | 2026-05-19 |

## Summary

This document defines which agents may invoke which other agents through the Task tool.

## Context

The company uses primary agents for all roles. Even so, task permissions should keep each role on its intended path and prevent product governance roles from directly invoking implementation or review roles.

## Decision

This company adopts the following agent task delegation table:

| Agent | May Invoke | Must Not Invoke Directly |
|---|---|---|
| `product-owner` | `cpo`, `cto`, `architect` | developer, architect-reviewer, qa-smoke, delivery-manager |
| `cpo` | `product-owner`, `cto`, `architect` | `developer`, `architect-reviewer`, `qa-smoke` |
| `cto` | `product-owner`, `cpo`, `architect` | `developer`, `architect-reviewer`, `qa-smoke` |
| `delivery-manager` | none | developer, architect-reviewer, qa-smoke |
| `architect` | `product-owner`, `cpo`, `cto`, `delivery-manager`, `developer`, `architect-reviewer`, `qa-smoke` | none |
| `developer` | `architect`, `architect-reviewer`, `qa-smoke` | cpo, cto |
| `architect-reviewer` | `architect`, `developer`, `qa-smoke` | cpo, cto |
| `qa-smoke` | `architect`, `developer`, `architect-reviewer` | cpo, cto |

## Consequences

- Product governance roles go through `architect` instead of calling delivery or review roles directly.
- Implementation and review roles can escalate to `architect` and hand work directly between each other.
- The workflow stays centrally coordinated while allowing the worker loop to proceed without governance handoff friction.

## Enforcement

- Keep `permission.task` in agent frontmatter aligned with this table.
- Update this document before changing call paths.
- Do not add direct calls from `cpo` or `cto` to `developer` or `architect-reviewer` without updating this policy.

## Related Documents

- `docs/DOCUMENT_INDEX.md`
- `docs/arch/ARCH-001-skill-delegation.md`
- `one-person-company/skills/agentic-flow-terms/SKILL.md`
