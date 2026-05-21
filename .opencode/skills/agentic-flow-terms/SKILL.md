---
name: agentic-flow-terms
description: Use when running, planning, reviewing, developing, completing, or discussing the custom agentic delivery flow. Defines shared metadata terms such as loop-breaker, review loop, defer task, role memory, GitHub collaboration record, and approval gates.
---

# Agentic Flow Terms

Use this skill whenever an agent participates in the custom delivery workflow.

These terms are specific to this repository's agentic flow. Agents must use these meanings consistently in specs, GitHub milestones, GitHub issues, PR reviews, role memory, reviews, QA notes, and final responses.

## Core Workflow Terms

| Term | Meaning |
|---|---|
| Deliverable | The requested product spec, enhancement, fix, architecture change, or implementation outcome being delivered. |
| Spec | The technical product or enhancement specification that defines goals, non-goals, requirements, constraints, and acceptance criteria. |
| Milestone | The GitHub milestone used as the delivery container for one spec or deliverable. It groups related GitHub issues and points to the canonical repo spec. |
| Task | A scoped unit of development work represented by a GitHub issue. Each task should have a stable issue ID and a clear issue title. |
| Project Board | The GitHub Project board used to track workflow state across milestones, issues, and approvals. |
| Production Base Branch | The branch that represents runnable production code, usually `main`, `master`, `production`, or the repo's documented release branch. |
| Task Branch | A working branch created from the production base branch for a specific task or spec. It must not be merged until approval gates pass. |
| Handoff | A durable transfer of context from one agent to another, recorded in the GitHub collaboration record. |
| Approval Gate | A required approval checkpoint before merge or completion. Current gates are architect-reviewer approval and QA smoke approval. |

## Review Loop Terms

| Term | Meaning |
|---|---|
| Development Loop | The broader task execution lifecycle: understand the assigned task, develop the implementation, prepare evidence, then enter the review loop. The development loop is done only when the review loop clears the work and no blocking issues remain. |
| Review Loop | The nested review-fix cycle inside the development loop: developer sends implementation to architect-reviewer, architect-reviewer reviews it, and if findings remain, the work returns to developer on the same task branch for re-development. |
| Loop Count | The number of review loops already completed for a task/spec. It is tracked in the GitHub collaboration record. |
| Max Review Loops | The maximum allowed review-development iterations before escalation. The value is `8`. |
| Loop Breaker | A custom agentic-flow decision point triggered when review loops reach the limit or a persistent architecture issue blocks progress. The architect must inspect the task, spec, docs, guardrails, GitHub collaboration record, and architect memory to decide how to proceed. |
| Loop Breaker Decision | The architect's decision at a loop breaker. Possible outcomes include approve with constraints, return to development, block for human intervention, create a defer task, or require spec/task/doc changes. |
| Clear The Development | Architect-reviewer confirms there are no blocking architecture, guardrail, definition-of-done, or acceptance-test issues for the implementation. |
| Clear The Stopper | Architect resolves a loop-breaker stopper by making a decision, updating guidance, creating a defer task, or requesting human intervention. |
| Stopper | A blocking issue that prevents normal review-development flow from continuing. It may be a hard blocker, architecture conflict, unclear spec, missing decision, or unresolved guardrail issue. |
| Hard Blocker | A blocker requiring human intervention, missing access, missing credentials, destructive action approval, unresolved product decision, or another issue agents cannot safely resolve alone. |

## Memory And Logging Terms

| Term | Meaning |
|---|---|
| GitHub Collaboration Record | The shared GitHub execution history for a spec or task, usually spread across milestone descriptions, issue comments, PR comments, review threads, linked issues, and approval evidence. |
| Role Memory | Durable role-specific repository memory extracted from the GitHub collaboration record after tasks or loops. It is not a raw transcript. |
| Developer Memory | Role memory for implementation lessons, pitfalls, file/module patterns, verification commands, and reusable development constraints. |
| QA Memory | Role memory for startup behavior, runtime dependencies, smoke-test commands, known verification gaps, and recurring QA failures. |
| Architect Memory | Role memory for architecture constraints, accepted tradeoffs, defer tasks, technical debt, guardrail decisions, and loop-breaker rationale. |
| Durable Memory | Information likely to matter for future tasks, reviews, QA, architecture decisions, or loop breakers. |
| No New Durable Memory | A required explicit note when a role reviewed the GitHub collaboration record but found nothing useful to store in role memory. |

## Architecture And Defer Terms

| Term | Meaning |
|---|---|
| Guardrail | A rule or constraint developers must follow, usually created by architect or documented in ADR/GOV/ARCH docs. |
| Architecture Conflict | A mismatch between implementation, spec, task, existing docs, guardrails, or architecture direction. |
| Defer Task | An architect-created task that intentionally postpones architecture cleanup, ADR/GOV/ARCH updates, future implementation, or technical debt. It must include reason, risk, target follow-up, and invalidation conditions. |
| Accepted Tradeoff | A known compromise explicitly accepted by architect, usually recorded in architect memory and the GitHub collaboration record. |
| Technical Debt | Work intentionally postponed and tracked so it can be addressed later. Technical debt must not be used to hide unresolved blockers. |
| ADR | Architecture Decision Record. Stored under `docs/adr/` or `.docs/adr/` when applicable. |
| GOV | Governance, standards, policies, conventions, or required process docs. Stored under `docs/gov/` or `.docs/gov/` when applicable. |
| ARCH | Repository-specific architecture guidance or customized architecture decisions. Stored under `docs/arch/` or `.docs/arch/` when applicable. |

## Completion Terms

| Term | Meaning |
|---|---|
| Definition Of Done | The task-specific observable conditions required before a task can be considered done. |
| Acceptance Tests | Task-specific behavior checks, test cases, or commands proving the implementation satisfies the task. |
| QA Smoke | Lightweight verification that the app can still build, start, or run at a basic health level. It is not full feature QA unless explicitly requested. |
| Merge Approval | Permission to merge a task branch after architect-reviewer and QA smoke approval gates both pass. |
| Completed Task | A task whose definition of done, acceptance tests, verification, review gates, QA gate, GitHub collaboration record, and role-memory updates are all satisfied. |

## Usage Rules

- Read this terminology before interpreting loop-breaker, stopper, defer task, role memory, approval gate, or GitHub collaboration record instructions.
- Use these terms exactly in GitHub milestones, GitHub issues, PR comments, role memory, review findings, QA notes, and final summaries.
- If a term is ambiguous in a task, resolve it using this skill before proceeding.
- If the workflow needs a new term, add it here and use it consistently across related skills and agents.
