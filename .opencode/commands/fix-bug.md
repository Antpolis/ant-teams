---
description: Investigate and fix bugs or regressions.
agent: builder
---

Investigate and fix the bug or regression described by: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Find the relevant spec, task file, communication log, and docs for the affected area. If the bug is clearly within an existing approved task, continue that task. If it is out of scope or needs separate handling, create a bug spec/task first.
2. Reproduce the bug or confirm the failure mode.
3. Use builder agents to make the smallest fix that addresses the defect.
4. Use validator to verify the fix.
5. Update the communication log, task status, and role memory.
6. If the fix reveals broader scope or architecture changes, stop and convert the work into a new spec or defer task.

Do not widen the fix beyond the bug unless necessary and approved.
