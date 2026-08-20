---
name: role-memory
description: Use after each task, review loop, reviewer verification, architecture escalation, or blocker to extract durable role-specific memory for builder, reviewer, and architect roles from the GitHub collaboration record.
---

# Role Memory

Use this skill whenever a task finishes a development, review, reviewer verification, blocker, escalation, or defer-task step.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by role memory.

## Purpose

Role memory is durable, project-specific knowledge stored in the central Obsidian vault and read before future work.

It is extracted from the GitHub collaboration record and stores important information relevant to each role:

- Builder implementation lessons
- Reviewer runtime and verification lessons
- Architect constraints, decisions, risks, and loop-breaker context

This memory helps future agents continue without relying on chat context and helps tech-lead make loop-breaker decisions.

## File Locations

Read `.github-project.json` and resolve `documentation.projectPathTemplate`. Store memory only in the project-specific Obsidian folder:

- `<project-doc-path>/agent-memory/<role>-memory.md`

Use separate project notes for `builder`, `reviewer`, and `architect` memory. Do not write role memory to repository `docs/` or `.docs/` folders. Use the project-specific Agent Memory Base in the central vault when filtering memory.

## Required Behavior

- After every task, builder, reviewer, and tech-lead must review the relevant GitHub issue, PR discussion, and linked GitHub evidence.
- Each role must update its role memory with information that will matter for future tasks, reviews, reviewer work, or architecture decisions.
- Do not copy the full GitHub collaboration record into memory.
- Store only durable, reusable, role-relevant information.
- Prefer concise bullets with links to spec IDs, task IDs, branches, docs, files, and decisions.
- If there is no new durable information, append a short `No new durable memory` entry with the spec/task ID and date.

## Memory Quality Bar

Only store information that is likely to be useful later:

- Repeated failure patterns
- Non-obvious implementation constraints
- Architecture tradeoffs and accepted deviations
- Runtime startup requirements
- Fragile areas of the codebase
- Verification commands that proved useful
- Test gaps or smoke-test limitations
- Deferred architecture decisions
- Technical debt accepted by tech-lead
- Integration assumptions
- Human decisions or blocker resolutions

Do not store:

- Temporary progress updates
- Raw chat transcript
- Obvious facts already in code
- One-off command output unless it changes future behavior
- Duplicate entries already captured

## Builder Memory Template

```md
# Builder Memory

## Active Lessons

### <YYYY-MM-DD> - <SPEC-ID> / <TASK-ID>

- Context: <short context>
- Implementation Lesson: <what future builders should know>
- Files/Modules: `<path>`, `<module>`
- Verification: `<command>`
- Avoid: <pitfall or none>
- Related Docs: <doc IDs or paths>
```

Builder memory should capture implementation constraints, file/module patterns, pitfalls, verification commands, and useful coding decisions.

## Reviewer Memory Template

```md
# Reviewer Memory

## Active Lessons

### <YYYY-MM-DD> - <SPEC-ID> / <TASK-ID>

- Context: <short context>
- Smoke Result: <pass/fail/blocker>
- Runtime Requirement: <env/config/service requirement>
- Verification Command: `<command>`
- Known Gap: <gap or none>
- Related Docs: <doc IDs or paths>
```

Reviewer memory should capture app startup requirements, smoke-test commands, runtime dependencies, known verification gaps, and recurring failures.

## Architect Memory Template

```md
# Architect Memory

## Active Decisions And Constraints

### <YYYY-MM-DD> - <SPEC-ID> / <TASK-ID>

- Context: <short context>
- Architecture Constraint: <constraint or decision>
- Accepted Tradeoff: <tradeoff or none>
- Deferred Work: <defer task ID or none>
- Risk: <risk and impact>
- Loop Breaker Notes: <why tech-lead allowed, blocked, or deferred>
- Related Docs: <ADR/GOV/ARCH/spec/task paths>
```

Architect memory should capture constraints, accepted tradeoffs, defer tasks, technical debt, guardrail updates, and loop-breaker rationale.

## Update Procedure

1. Read the relevant GitHub issue, PR discussion, and linked evidence.
2. Identify entries since the last role-memory update for the spec/task.
3. Extract durable information relevant to the role.
4. Append concise entries to the appropriate role memory file.
5. Link back to the spec, milestone, issue, PR, branch, and related docs where useful.
6. Update the GitHub issue or PR with a note that role memory was reviewed and updated when that handoff matters for the next role.

## Use Procedure

Before future work, agents must read the relevant role memory:

- Builder reads builder memory before implementation.
- Reviewer reads reviewer memory before review and lightweight smoke verification.
- Tech-lead reads architect memory before escalation, defer-task creation, or loop-breaker decisions.

Role memory complements the central Obsidian project docs. It does not replace ADR, GOV, ARCH, spec, milestone, issue, or PR records.
