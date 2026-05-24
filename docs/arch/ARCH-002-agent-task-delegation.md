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
| Last Updated | 2026-05-23 |

## Summary

This document defines which agents may invoke which other agents through the Task tool.

## Context

The company uses primary agents for all roles. Task permissions should keep each role on its intended path while still allowing the orchestrator to own queue-driven execution from start to stop.

## Decision

This company adopts the following agent task delegation table:

| Agent | May Invoke | Must Not Invoke Directly |
|---|---|---|
| `orchestrator` | `strategist`, `tech-lead`, `builder`, `reviewer` | none |
| `strategist` | `tech-lead`, `builder`, `reviewer` | `orchestrator` |
| `tech-lead` | `strategist`, `builder`, `reviewer` | `orchestrator` |
| `builder` | `strategist`, `tech-lead`, `reviewer` | `orchestrator` |
| `reviewer` | `strategist`, `tech-lead`, `builder` | `orchestrator` |

## Consequences

- The orchestrator is the only role that owns a queue pass from start to stop.
- Strategist, tech-lead, builder, and reviewer may still hand work between each other when the runtime allows it, but they do not replace orchestrator ownership of the overall pass.
- The workflow stays centrally coordinated while still allowing the implementation and review loop to proceed without unnecessary founder interruptions.

## Enforcement

- Keep `permission.task` in `.opencode/opencode.json` aligned with this table.
- Update this document before changing call paths.
- Do not shift queue ownership away from `orchestrator` without updating this policy and the command layer.

## Related Documents

- `docs/DOCUMENT_INDEX.md`
- `docs/arch/ARCH-001-skill-delegation.md`
- `one-person-company/skills/agentic-flow-terms/SKILL.md`
