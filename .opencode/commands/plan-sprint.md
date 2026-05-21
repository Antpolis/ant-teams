---
description: Prioritize and prepare the next builder-ready execution batch from a cleaned task set.
agent: tech-lead
---

Prioritize and prepare the next sprint or execution batch for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Assume the board, tasks, and docs have already been reconciled recently. If they may be stale, run `sprint-clean` first.

Flow:
1. Start from the tech-lead role and inspect the relevant spec, milestone, communication log, open tasks, and current GitHub project board state.
2. Use the github-agentic-delivery-flow, state-transitions, and github-conventions skills to confirm what work is still in shaping, what is blocked, what is ready, and what can reasonably enter the next execution batch.
3. Use the github-issues-projects-cli skill, `gh`, `jq`, the repo GitHub wrapper, and `./.github-project.json` to review issues, milestone linkage, project-board status, dependencies, and missing execution metadata.
4. Prioritize the active work:
   - identify the smallest high-value tasks that should move first
   - surface blockers and sequencing constraints
   - move only truly executable tasks to `Ready`
5. Ensure the planning outcome is handoff-ready:
   - at least one issue should be explicitly builder-ready if execution can proceed
   - the next issue to pick up should be named clearly
   - each ready issue should point to the right spec, milestone, and supporting docs
6. Add a durable handoff note for the builder that says what to pick up next, why it is the priority, what guardrails apply, and what evidence or dependencies matter.
7. Recommend `do-task <issue>` as the next command once the sprint plan results in a builder-ready issue.

Do not stop at commentary or reprioritization alone. The expected outcome is a prioritized execution batch with explicit builder-ready handoff.
