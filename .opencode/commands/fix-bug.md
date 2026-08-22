---
description: Investigate and fix bugs or regressions.
agent: builder
---

Investigate and fix the bug or regression described by: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Find the relevant spec, GitHub issue, GitHub collaboration record, and docs for the affected area. If the bug is clearly within an existing approved task, continue that issue. If it is out of scope or needs separate handling, create a bug spec and GitHub task issue first.
2. Reproduce the bug or confirm the failure mode.
3. Use builder agents to make the smallest fix that addresses the defect.
4. Use reviewer to verify the fix.
5. Update the GitHub issue or PR handoff notes, project status, and role memory.
6. If the fix reveals broader scope or architecture changes, stop and convert the work into a new spec or defer task.

Do not widen the fix beyond the bug unless necessary and approved.
