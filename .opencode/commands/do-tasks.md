---
description: Continue or finish existing approved tasks.
agent: tech-lead
---

Drive the next approved task work from the project issue queue for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.
Use the `do-task` skill as the canonical workflow for queue-driven task execution.
Use `founder-escalation-preflight` before asking the founder for a decision.

Run the `do-task` skill end to end for this request.

Expected behavior:
- tech-lead owns queue-driven execution
- reconcile active `In Progress` and `In Review` work first
- delegate builder, validator, or strategist as needed
- use `handoff` wording only when returning control to the founder
- do not return early while safe internal next steps remain
- keep the response short when internal delegation is already active
