---
description: Migrate an existing spec into the current project-management format.
agent: tech-lead
---

Migrate the following spec or legacy workflow into the current project-management format: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Find the existing spec, task artifacts, communication logs, and any legacy project-management docs for this work.
2. Map the current content into the new structure: one spec file, one task file, one communication log, and the project board entry.
3. Use the strategist agent to identify any related ADR, GOV, or ARCH docs that should be linked or updated and to normalize the spec into the current implementation-ready format.
5. Use the tech-lead agent to split the work into the new task structure if tasks are missing or outdated.
6. Use the workflow tools to update the document index, board, task file, communication log, and any status fields.
7. Mark any replaced legacy docs as deprecated or superseded instead of silently deleting them.
8. Preserve meaning, but rewrite content into the current project-management format.

Do not drop history unless the migration explicitly says to remove it.
