---
name: agentic-flow-terms
description: Use when running, planning, reviewing, developing, completing, or discussing the custom agentic delivery flow. Defines shared metadata terms such as loop-breaker, review loop, defer task, role memory, collaboration record, and approval gates.
---

# Agentic Flow Terms

Use this skill whenever participating in the repository’s agentic delivery workflow.

All named agents must use these terms consistently in:

- GitHub milestones;
- GitHub issues;
- pull requests;
- Obsidian communication records;
- role memory;
- review findings;
- handoffs;
- final summaries.

## Core terms

| Term | Meaning |
|---|---|
| Deliverable | The requested product spec, enhancement, fix, architecture change, or implementation outcome. |
| Spec | The technical product or enhancement specification defining goals, non-goals, requirements, constraints, and acceptance criteria. |
| Milestone | The GitHub milestone containing one spec or deliverable. |
| Task | A scoped unit of development work represented by a GitHub issue. |
| Project Board | The GitHub Project used to track workflow state. |
| Production Base Branch | The branch containing runnable production code. |
| Task Branch | The branch created for one task or spec. |
| Handoff | A durable transfer of context between agents recorded in Obsidian. |
| Approval Gate | A required approval checkpoint before merge or completion. The current approval gate is reviewer approval plus lightweight smoke verification. |

## Development and review terms

| Term | Meaning |
|---|---|
| Development Loop | Understand the task, implement it, prepare evidence, and enter review. |
| Review Loop | Builder-reviewer development and review cycle for one task. |
| Loop Count | Number of completed review loops. |
| Max Review Loops | Maximum allowed review loops: `8`. |
| Loop Breaker | Decision point reached after the limit or when a persistent blocker prevents normal review flow. |
| Loop Breaker Decision | Tech-lead’s decision to approve with constraints, return to development, block, defer, or require spec/task/doc changes. |
| Clear The Development | Reviewer confirms no blocking correctness, scope, guardrail, acceptance, or verification findings remain. |
| Clear The Stopper | Tech-lead resolves a loop-breaker stopper. |
| Stopper | Any blocker preventing normal workflow. |
| Hard Blocker | A blocker requiring human input, access, credentials, approval, or unresolved product direction. |

## Memory and logging terms

| Term | Meaning |
|---|---|
| Collaboration Record | Full agent communication history stored as individual Obsidian event files. |
| GitHub Collaboration Record | GitHub-side status, decisions, closure, review findings, and approval evidence. |
| Role Memory | Durable role-specific lessons extracted from collaboration records. |
| Builder Memory | Implementation patterns, pitfalls, and verification lessons. |
| Reviewer Memory | Review and smoke-verification lessons. |
| Architect Memory | Architecture constraints, tradeoffs, defer decisions, and loop-breaker rationale. |
| Durable Memory | Information likely to matter for future work. |
| No New Durable Memory | Explicit note that no durable role memory was discovered. |

## Architecture and planning terms

| Term | Meaning |
|---|---|
| Guardrail | A rule or constraint that implementation must follow. |
| Architecture Conflict | A mismatch between implementation, spec, docs, guardrails, or architecture direction. |
| Defer Task | Tech-lead-created task that intentionally postpones work. |
| Accepted Tradeoff | A documented compromise accepted by tech-lead. |
| Technical Debt | Intentionally postponed work that remains tracked. |
| ADR | Architecture Decision Record. |
| GOV | Governance or standards documentation. |
| ARCH | Repository-specific architecture guidance. |

## Completion terms

| Term | Meaning |
|---|---|
| Definition Of Done | Observable task-specific completion conditions. |
| Acceptance Tests | Tests or commands proving acceptance criteria. |
| Reviewer Verification | Reviewer-owned code review and lightweight smoke verification. |
| Merge Approval | Permission to merge after reviewer approval. |
| Completed Task | A task satisfying definition of done, acceptance tests, reviewer gate, communication logging, and role-memory requirements. |

## Required usage

- Use the exact terms above.
- Resolve ambiguous workflow language using this glossary.
- Do not invent synonyms for loop-breaker, stopper, handoff, approval gate, or completed task.
- If a new workflow term is required, add it to this skill before using it elsewhere.