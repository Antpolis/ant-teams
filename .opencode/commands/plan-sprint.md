---
description: Review attention items and milestones with the founder to choose the next sprint issues.
agent: strategist
---

Prioritize and prepare the next sprint or execution batch for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.
Do not use the `do-task` skill as the main pattern for this command. `plan-sprint` is a planning conversation and prioritization pass, not a queue-driven delegation loop.
Do not use `founder-escalation-preflight` for normal sprint planning. Founder participation is expected here.

Assume the board, tasks, and docs have already been reconciled recently. If they may be stale, run `sprint-clean` first.

Flow:
1. Start from the strategist role and own the sprint-planning conversation from start to stop with the founder.
2. Review the current GitHub project board state with emphasis on:
   - issues in `Need attentions`
   - existing milestones and the issues linked to them
   - issues already in `Ready`, `Blocked`, `Shaping`, or `In Progress` when they affect what can fit in the sprint
3. Use the github-agentic-delivery-flow, state-transitions, and github-conventions skills to confirm what work is still shaping, what is blocked, what needs clarification, and what is realistically selectable for the sprint.
4. Use the github-issues-projects-cli skill, `gh`, `jq`, the repo GitHub wrapper, and `./.github-project.json` to inspect milestone linkage, project-board status, issue dependencies, and missing planning metadata.
5. Work through past or current `Need attentions` issues first:
   - read the durable GitHub comment that explains why the issue was moved to `Need attentions`
   - identify whether the issue needs product clarification, scope clarification, sequencing help, acceptance clarification, or a decision to defer
   - use strategist judgment to suggest the cleanest resolution path
   - bring the founder into the decision when prioritization, product intent, or sprint tradeoffs need founder input
   - when safe, recommend how the issue should move next, including whether it should return to `Ready`, stay out of the sprint, or be reshaped first
6. Review milestones as sprint containers:
   - identify which milestones have enough clear issues to support sprint progress
   - call out milestones with thin, stale, blocked, or overly large issue sets
   - suggest which milestone the founder and strategist should focus on this sprint
7. Propose the sprint issue set:
   - suggest the highest-value issues to do next
   - keep the suggested sprint focused and realistically sized
   - explain why each suggested issue belongs in the sprint now
   - call out issues that should explicitly wait until a later sprint
8. If needed, ask tech-lead for a targeted feasibility or sequencing read, but only to support the planning decision rather than turning the command into an orchestration handoff.
9. End with a clear sprint recommendation:
   - suggested milestone to focus on
   - suggested issues to include this sprint
   - issues that still need clarification before inclusion
   - the next practical command, usually `do-tasks <issue>` only after the founder agrees on the sprint choice

Expected behavior:
- strategist owns the sprint-planning pass from start to stop
- treat founder participation as part of the normal planning process, not as an escalation
- inspect `Need attentions` issues before selecting new sprint work
- review milestones and their linked issues before suggesting sprint scope
- suggest which milestone and which issues the sprint should focus on
- keep the result decision-oriented and planning-focused rather than handoff-oriented

Do not turn this command into a delegation theater loop. The expected outcome is a founder-supported sprint recommendation grounded in `Need attentions`, milestone health, and a clear suggestion of which issues should be done in the sprint.
