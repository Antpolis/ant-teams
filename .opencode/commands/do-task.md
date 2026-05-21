---
description: Continue or finish existing approved tasks.
agent: builder
---

Continue the existing task work for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Find the relevant approved spec and single task file. Read the task scope, dependencies, definition of done, acceptance tests, verification commands, and communication log.
2. If work is already in progress, continue the current task branch. If no task branch exists yet, create one from the production base branch.
3. Use the builder agent to implement only the remaining task scope. Keep the change small and task-focused.
4. Use the validator agent to validate the task after development.
5. Update the communication log, task status, and role memory after each loop or handoff.
6. If the task is already approved and only remains to be finished, do the remaining work, verify it, and close it according to the task workflow.

Do not start a new spec unless the remaining work changes scope.
