---
name: role-memory
description: Use after a meaningful delivery event to capture a new, durable, reusable role-specific lesson for builder, reviewer, or architect roles from the GitHub operational collaboration record and curated project documentation. Do not use for routine per-task, per-loop, or no-op updates.
---

# Role Memory

Use this skill only after a meaningful delivery event reveals a new durable, reusable lesson for a future builder, reviewer, or architect decision. Do not run it automatically after every task, review loop, verification, blocker, escalation, or defer-task step.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by role memory.

## Purpose

Role memory is curated, durable, project-specific knowledge stored in the central Obsidian vault and read before future work.

GitHub Issues, Pull Requests, comments, and Project Workflow State are the operational collaboration record. Extract role memory from that record and, where relevant, curated project documentation; do not create Obsidian communication-event records for routine work. Role memory stores important information relevant to each role:

- Builder implementation lessons
- Reviewer runtime and verification lessons
- Architect constraints, decisions, risks, and loop-breaker context

This memory helps future agents continue without relying on chat context and helps tech-lead make loop-breaker decisions.

## File Locations

When a direct command needs `ANT_TEAM_DOCS_PROJECT_PATH`, source `./.github-project.env` once—the sole committed project config source—and resolve the path. Before creating memory, inspect and use the approved Agent Memory template and Base in the central vault. If no suitable template exists, stop and request one. Store memory only in the project-specific Obsidian folder:

- `<project-doc-path>/agent-memory/<role>-memory.md`

Use separate project notes for `builder`, `reviewer`, and `architect` memory. Do not write role memory to repository `docs/` or `.docs/` folders. Use the project-specific Agent Memory Base in the central vault when filtering memory.

## Required Behavior

- Trigger an update only when a meaningful event produces a new lesson likely to affect future implementation, review, verification, or architecture decisions.
- Read the relevant GitHub issue, PR discussion and review results, milestone decisions, and linked evidence before recording a lesson.
- Do not copy the full collaboration record into memory.
- Store only durable, reusable, role-relevant information.
- Prefer concise bullets with links to relevant GitHub issues, PRs, milestones, curated docs, files, and decisions.
- Do not create per-task, per-review-loop, or no-op entries. If there is no new durable lesson, do not update role memory.

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

1. Confirm that a new durable, reusable lesson exists; otherwise stop without updating memory.
2. Read the relevant GitHub issue, PR code-review results, milestone decisions, linked evidence, and curated docs where applicable.
3. Check whether the lesson is already captured.
4. Append one concise entry to the appropriate role memory file.
5. Link back to the relevant spec, milestone, issue, PR, branch, and curated docs where useful.
6. Keep any operational handoff, status, decision, blocker, or closure in GitHub. Add a GitHub link to memory only when the lesson materially affects future work.

## Use Procedure

Before future work, agents must read the relevant role memory:

- Builder reads builder memory before implementation.
- Reviewer reads reviewer memory before review and lightweight smoke verification.
- Tech-lead reads architect memory before escalation, defer-task creation, or loop-breaker decisions.

Role memory complements the central Obsidian project docs. It does not replace ADR, GOV, ARCH, spec, milestone, issue, or PR records.
