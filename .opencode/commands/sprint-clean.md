---
description: Reconcile recent delivered work against specs, tasks, board state, and docs before sprint planning.
agent: orchestrator
---

Clean and reconcile the current sprint or delivery state for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.
Use the `do-task` skill as the canonical pattern for queue-driven internal delegation.
Use `founder-escalation-preflight` before asking the founder for a decision.

Assume this command is part of a recurring weekly cleanup pass unless the user says otherwise.

Interpret `$ARGUMENTS` like this:

- if the user gives only the cleanup topic or scope, use a default lookback window of 1 week
- if the user includes a number of weeks, use that as the lookback window
- if the requested lookback window is ambiguous, prefer the safest plain interpretation and state it in the summary

Flow:
1. Start from the orchestrator role and own the cleanup pass from start to stop.
2. Reconcile active `In Progress` and `In Review` work first so the cleanup is based on the current real queue state before pulling in fresh reconciliation work.
3. Invoke `tech-lead` first to inspect the relevant spec, milestone, communication log, completed tasks, open tasks, key repository docs, relevant `ARCH` docs, relevant `ADR` docs, and current GitHub project board state, and to propose the ordered reconciliation plan and guardrails for this pass.
4. Follow the `tech-lead` ordering and invoke `strategist`, `builder`, or `reviewer` directly when the next safe internal step requires product clarification, documentation correction, board cleanup, verification, or review confirmation. Do not stop at a recorded handoff if the orchestrator can invoke the next role directly.
5. Inspect the last lookback window of development that landed on the default branch. Use `git` to review recent merged or landed work so cleanup is based on what actually changed.
6. Review all tasks completed in that same lookback window. Use GitHub issue and project data to confirm what was marked done, what actually landed, and whether any completed-task records drift from reality.
7. Review whether the spec and supporting docs still match reality after the work already completed. Check for drift between:
   - the original spec intent
   - supporting docs, `ADR` docs, `ARCH` docs, governance notes, and operational guidance
   - completed implementation work
   - tasks completed in the lookback window
   - current open issues
   - current project-board states
8. Use the github-agentic-delivery-flow, state-transitions, and github-conventions skills to confirm what work is still in shaping, what is blocked, what is ready, and what has drifted.
9. Use the github-issues-projects-cli skill, `gh`, `jq`, the repo GitHub wrapper, and `./.github-project.json` to review issues, milestone linkage, project-board status, dependencies, completion state, and missing metadata.
10. Reconcile the system of record:
   - confirm completed tasks are actually reflected in the spec and task set
   - compare recent default-branch changes from the lookback window against task closure and board status
   - compare tasks completed in the lookback window against the code and spec reality
   - review key docs, especially relevant `ADR` and `ARCH` docs, to confirm they are still accurate after recent completed work
   - review recent release tags and GitHub releases when the cleaned work shipped or should have shipped, and confirm they follow the canonical release tag format from `release-management`
   - confirm the milestone closeout or release linkage points to the correct canonical release tag, including the required `-spN` suffix
   - identify docs that are stale, incomplete, or contradicted by the code or board state
   - close, defer, or rewrite stale tasks that were invalidated by completed work
   - identify missing follow-up tasks created by what has already been built
   - update task scope when the implementation reality has changed sequencing or assumptions
   - identify merged issue worktrees and local branches that are no longer needed and queue them for cleanup
   - call out any spec or supporting-doc sections that are now outdated and need correction
   - route product-facing spec or narrative doc corrections through strategist review before treating them as finalized
11. Clean the board and task set:
   - close or defer stale work that should not remain active
   - split oversized issues when they are not builder-usable
   - clarify acceptance criteria, verification, and dependencies where missing
   - make sure each issue has the right current responsible role
   - remove stale merged issue worktrees and branches when they are safe to delete
   - create documentation follow-up tasks when important docs are no longer current
   - fix milestone metadata or release references that still point at an incorrect or obsolete release tag format
   - if a doc update changes product framing, scope, promise, or success criteria, assign strategist as the reviewing role for that doc correction
   - if all tasks under a milestone are actually complete and no required follow-up work remains open, close the milestone
12. Before returning to the founder, verify that the required GitHub records, board transitions, comments, and role handoffs for this cleanup pass have actually been recorded. If a safe internal next step still exists, invoke it instead of returning early.
13. Produce a reconciliation summary that says:
   - what landed in the lookback window
   - what completed-task records were accurate or inaccurate
   - what stale tasks were closed, deferred, or rewritten
   - what docs need updates
   - what release tags or milestone release references were corrected
   - what milestones were closed because all work was complete
   - whether the board is now clean enough for sprint planning
14. If documentation corrections are needed, ensure strategist is actually invoked or explicitly queued through a durable GitHub handoff when the affected docs change product meaning rather than just technical detail.
15. If the board is now trustworthy, recommend `plan-sprint` as the next command.

Expected behavior:
- orchestrator owns the cleanup pass from start to stop
- always invoke `tech-lead` first for ordered reconciliation priorities and guardrails
- invoke `strategist`, `builder`, or `reviewer` directly when they can safely complete the next cleanup step
- do not rely on `tech-lead` alone to carry the whole cleanup loop if the orchestrator can move the work forward
- do not stop at observation alone
- do not return early while safe internal next steps remain
- keep the response short when internal delegation is already active

Do not stop at observation alone. The expected outcome is a cleaned and reconciled system of record that is trustworthy enough for planning, with completed milestones closed when appropriate.
