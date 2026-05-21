---
description: Reconcile recent delivered work against specs, tasks, board state, and docs before sprint planning.
agent: tech-lead
---

Clean and reconcile the current sprint or delivery state for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Assume this command is part of a recurring weekly cleanup pass unless the user says otherwise.

Interpret `$ARGUMENTS` like this:

- if the user gives only the cleanup topic or scope, use a default lookback window of 1 week
- if the user includes a number of weeks, use that as the lookback window
- if the requested lookback window is ambiguous, prefer the safest plain interpretation and state it in the summary

Flow:
1. Start from the tech-lead role and inspect the relevant spec, milestone, communication log, completed tasks, open tasks, key repository docs, relevant `ARCH` docs, relevant `ADR` docs, and current GitHub project board state.
2. Inspect the last lookback window of development that landed on the default branch. Use `git` to review recent merged or landed work so cleanup is based on what actually changed.
3. Review all tasks completed in that same lookback window. Use GitHub issue and project data to confirm what was marked done, what actually landed, and whether any completed-task records drift from reality.
4. Review whether the spec and supporting docs still match reality after the work already completed. Check for drift between:
   - the original spec intent
   - supporting docs, `ADR` docs, `ARCH` docs, governance notes, and operational guidance
   - completed implementation work
   - tasks completed in the lookback window
   - current open issues
   - current project-board states
5. Use the github-agentic-delivery-flow, state-transitions, and github-conventions skills to confirm what work is still in shaping, what is blocked, what is ready, and what has drifted.
6. Use the github-issues-projects-cli skill, `gh`, `jq`, the repo GitHub wrapper, and `./.github-project.json` to review issues, milestone linkage, project-board status, dependencies, completion state, and missing metadata.
7. Reconcile the system of record:
   - confirm completed tasks are actually reflected in the spec and task set
   - compare recent default-branch changes from the lookback window against task closure and board status
   - compare tasks completed in the lookback window against the code and spec reality
   - review key docs, especially relevant `ADR` and `ARCH` docs, to confirm they are still accurate after recent completed work
   - identify docs that are stale, incomplete, or contradicted by the code or board state
   - close, defer, or rewrite stale tasks that were invalidated by completed work
   - identify missing follow-up tasks created by what has already been built
   - update task scope when the implementation reality has changed sequencing or assumptions
   - call out any spec or supporting-doc sections that are now outdated and need correction
   - route product-facing spec or narrative doc corrections through strategist review before treating them as finalized
8. Clean the board and task set:
   - close or defer stale work that should not remain active
   - split oversized issues when they are not builder-usable
   - clarify acceptance criteria, verification, and dependencies where missing
   - make sure each issue has the right current responsible role
   - create documentation follow-up tasks when important docs are no longer current
   - if a doc update changes product framing, scope, promise, or success criteria, assign strategist as the reviewing role for that doc correction
   - if all tasks under a milestone are actually complete and no required follow-up work remains open, close the milestone
9. Produce a reconciliation summary that says:
   - what landed in the lookback window
   - what completed-task records were accurate or inaccurate
   - what stale tasks were closed, deferred, or rewritten
   - what docs need updates
   - what milestones were closed because all work was complete
   - whether the board is now clean enough for sprint planning
10. If documentation corrections are needed, add a parallel handoff for strategist when the affected docs change product meaning rather than just technical detail.
11. If the board is now trustworthy, recommend `plan-sprint` as the next command.

Do not stop at observation alone. The expected outcome is a cleaned and reconciled system of record that is trustworthy enough for planning, with completed milestones closed when appropriate.
