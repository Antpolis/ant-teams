---
name: agentic-flow-terms
description: Use when running, planning, reviewing, developing, completing, or discussing the custom agentic delivery flow. Defines shared metadata terms such as loop-breaker, review loop, defer task, role memory, collaboration record, and approval gates.
---

# Agentic Flow Terms

Use this skill whenever an agent participates in the custom delivery workflow.

These terms are specific to this repository's agentic flow. Agents must use these meanings consistently in specs, GitHub milestones, GitHub issues, PR reviews, role memory, reviews, reviewer notes, and final responses.

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
| Handoff | A durable transfer of context from one agent to another, recorded in the Obsidian collaboration record. |
| Approval Gate | A required approval checkpoint before merge or completion. The current gate is reviewer approval covering code review and lightweight smoke verification. |

## Review Loop Terms

| Term | Meaning |
|---|---|
| Development Loop | The broader task execution lifecycle: understand the assigned task, develop the implementation, prepare evidence, then enter the review loop. The development loop is done only when the review loop clears the work and no blocking issues remain. |
| Review Loop | The nested review-fix cycle inside the development loop: builder sends implementation for reviewer review, reviewer reviews it, and if findings remain, the work returns to builder on the same task branch for re-development. |
| Loop Count | The number of review loops already completed for a task/spec. It is tracked in the Obsidian collaboration record. |
| Max Review Loops | The maximum allowed review-development iterations before escalation. The value is `8`. |
| Loop Breaker | A custom agentic-flow decision point triggered when review loops reach the limit or a persistent architecture issue blocks progress. The tech-lead must inspect the task, spec, docs, guardrails, the Obsidian collaboration record, and architect memory to decide how to proceed. |
| Loop Breaker Decision | The tech-lead's decision at a loop breaker. Possible outcomes include approve with constraints, return to development, block for human intervention, create a defer task, or require spec/task/doc changes. |
| Clear The Development | Reviewer confirms there are no blocking correctness, guardrail, definition-of-done, acceptance-test, or lightweight smoke-verification issues for the implementation. |
| Clear The Stopper | Tech-lead resolves a loop-breaker stopper by making a decision, updating guidance, creating a defer task, or requesting human intervention. |
| Stopper | A blocking issue that prevents normal review-development flow from continuing. It may be a hard blocker, architecture conflict, unclear spec, missing decision, or unresolved guardrail issue. |
| Hard Blocker | A blocker requiring human intervention, missing access, missing credentials, destructive action approval, unresolved product decision, or another issue agents cannot safely resolve alone. |

## Memory And Logging Terms

| Term | Meaning |
|---|---|
| Collaboration Record | The full agent communication history for a spec or task, stored as individual event files in the central Obsidian project folder (agent-communication notes). It is the canonical record for handoffs, delegation reasoning, findings, review-loop history, and coordination context. |
| GitHub Collaboration Record | The GitHub-side execution trail: issue state, project Workflow State, milestone status, final decision comments, closure comments, PR code-review results, and approval evidence. GitHub comments carry only final decisions, status, closure, and code-review results — not working agent conversation. |
| Role Memory | Durable role-specific memory extracted from the collaboration record after tasks or loops, stored in the central Obsidian project folder. It is not a raw transcript. |
| Builder Memory | Role memory for implementation lessons, pitfalls, file/module patterns, verification commands, and reusable development constraints. |
| Reviewer Memory | Role memory for startup behavior, runtime dependencies, smoke-test commands, known verification gaps, and recurring review or verification failures. |
| Architect Memory | Role memory for architecture constraints, accepted tradeoffs, defer tasks, technical debt, guardrail decisions, and loop-breaker rationale. |
| Durable Memory | Information likely to matter for future tasks, reviews, reviewer work, architecture decisions, or loop breakers. |
| No New Durable Memory | A required explicit note when a role reviewed the collaboration record but found nothing useful to store in role memory. |

## Architecture And Defer Terms

| Term | Meaning |
|---|---|
| Guardrail | A rule or constraint builders must follow, usually created by tech-lead or documented in ADR/GOV/ARCH docs. |
| Architecture Conflict | A mismatch between implementation, spec, task, existing docs, guardrails, or architecture direction. |
| Defer Task | A tech-lead-created task that intentionally postpones architecture cleanup, ADR/GOV/ARCH updates, future implementation, or technical debt. It must include reason, risk, target follow-up, and invalidation conditions. |
| Accepted Tradeoff | A known compromise explicitly accepted by tech-lead, usually recorded in architect memory and the collaboration record. |
| Technical Debt | Work intentionally postponed and tracked so it can be addressed later. Technical debt must not be used to hide unresolved blockers. |
| ADR | Architecture Decision Record. Stored in the central Obsidian project folder or governance area. |
| GOV | Governance, standards, policies, conventions, or required process docs. Stored in the central Obsidian governance area. |
| ARCH | Repository-specific architecture guidance or customized architecture decisions. Stored in the central Obsidian project or shared-architecture area. |

## Completion Terms

| Term | Meaning |
|---|---|
| Definition Of Done | The task-specific observable conditions required before a task can be considered done. |
| Acceptance Tests | Task-specific behavior checks, test cases, or commands proving the implementation satisfies the task. |
| Reviewer Verification | Reviewer-owned code review plus lightweight verification that the app can still build, start, or run at a basic health level. It is not full feature QA unless explicitly requested. |
| Merge Approval | Permission to merge a task branch after reviewer approval passes. |
| Completed Task | A task whose definition of done, acceptance tests, verification, reviewer gate, collaboration record, and role-memory updates are all satisfied. |

## Usage Rules

- Read this terminology before interpreting loop-breaker, stopper, defer task, role memory, approval gate, collaboration record, or GitHub collaboration record instructions.
- Use these terms exactly in GitHub milestones, GitHub issues, PR comments, role memory, review findings, reviewer notes, and final summaries.
- If a term is ambiguous in a task, resolve it using this skill before proceeding.
- If the workflow needs a new term, add it here and use it consistently across related skills and agents.
