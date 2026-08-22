---
description: Continue or finish existing approved tasks.
agent: orchestrator
---

Drive the next approved task work from the project issue queue for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.
Use the `do-task` skill as the canonical workflow for queue-driven task execution.
Use `founder-escalation-preflight` before asking the founder for a decision.

Run the `do-task` skill end to end for this request.

Expected behavior:
- orchestrator owns queue-driven execution
- reconcile `Ready to Merge` issues first — route to tech-lead for final spec-alignment check and merge before pulling fresh work
- reconcile active `In Progress` and `In Review` work next
- route all `Need attentions` issues to tech-lead first; tech-lead resolves or communicates with strategist, then moves back to `Ready`; escalate to founder only if tech-lead and strategist cannot resolve
- always get the ordered issue list and execution priorities from tech-lead before starting fresh queue work
- invoke tech-lead, builder, reviewer, or strategist as needed
- treat `do-tasks` as continuation of an existing task, not as a branch-reset flow
- builder should prefer one dedicated git worktree per active issue so tasks can run in parallel safely
- builder should continue in the existing issue worktree when it already exists
- builder should continue on the existing task branch and existing PR when they already exist
- builder must not start a fresh worktree, fresh branch, or open a replacement PR during normal `do-tasks` execution unless the old worktree, branch, or PR is unusable and the recovery reason is recorded in GitHub
- after merge or explicit issue completion, clean up the no-longer-needed issue worktree and local branch
- do not rely on tech-lead to delegate onward if the orchestrator can invoke the next role directly
- if builder, reviewer, or strategist can be invoked in this runtime, invoke them immediately instead of stopping at a status update or GitHub comment
- use `handoff` wording only when returning control to the founder
- do not return early while safe internal next steps remain
- keep the response short when internal delegation is already active
