---
description: Prioritize and prepare the next builder-ready execution batch from a cleaned task set.
agent: tech-lead
---

Prioritize and prepare the next sprint or execution batch for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Assume the board, tasks, and docs have already been reconciled recently. If they may be stale, run `sprint-clean` first.

Sprint planning is a business decision. Do not finalize sprint scope, priority order, or builder handoff without checking the user's business preference.

Flow:
1. Start from the tech-lead role and inspect the relevant milestones, specs, and communication logs first.
2. Review milestone-level intent before issue-level detail:
   - confirm which milestones/specs are still active
   - confirm which milestones/specs are candidates for the next sprint
   - confirm whether any milestone is complete, blocked, or no longer aligned with business direction
3. Check with the user and decide which milestone or milestones are actually in scope for this sprint planning pass.
   - do not assume the sprint milestone set alone
   - treat milestone selection as a business decision owned by the user
   - if multiple milestones compete for attention, surface the tradeoffs and let the user choose
4. Use the github-agentic-delivery-flow, state-transitions, and github-conventions skills to confirm what milestone-level work inside the selected milestone set is still in shaping, what is blocked, what is ready for execution planning, and what can reasonably enter the next execution batch.
5. After milestone scope is confirmed by the user, use the github-issues-projects-cli skill, `gh`, `jq`, the repo GitHub wrapper, and `./.github-project.json` to review the issues inside those milestones, including project-board status, dependencies, project item IDs, and missing execution metadata.
6. Prioritize the active work:
   - identify the smallest high-value tasks that should move first
   - inspect issues already in `Ready` and treat them as backlog candidates rather than automatically assuming they stay in the sprint
   - surface blockers and sequencing constraints
   - propose, but do not yet finalize, which tasks should move first
7. Check with the user on business preference before acting on the final sprint selection:
   - confirm which proposed issues should actually enter the sprint
   - explicitly review issues already in `Ready` and ask whether they should stay in the sprint or move back to backlog
   - confirm tradeoffs when there are competing priorities
   - treat user direction as the final tie-breaker on scope and ordering
8. Update GitHub as the operational source of truth after user preference is confirmed:
    - move builder-ready issues to `Ready` on the GitHub Project board
    - move previously `Ready` issues back to backlog or shaping if the user does not want them in the sprint
    - ensure blockers and dependencies are reflected in the GitHub issue itself
    - record per-issue discussion as comments on the GitHub issue rather than only in local docs
    - keep task status on the GitHub Project item, not in issue body prose
9. Create or update a sprint planning documentation file under the docs root, preferably in `docs/proj-management/`, for this planning pass.
    - use it as the durable handoff companion for agents
    - explain which milestones are in scope for the sprint and why
    - explain why the selected issues are in the sprint/project batch
    - record important business decisions made with the user during sprint planning
    - include all selected issues with their issue number, title, milestone, current project status, blockers, dependencies, and GitHub Project item ID
    - include enough cached issue/project detail that future agents do not need to re-query GitHub for basic issue and item metadata unless they suspect drift
10. Ensure the planning outcome is handoff-ready:
    - at least one issue should be explicitly builder-ready if execution can proceed
    - the next issue to pick up should be named clearly
    - each ready issue should point to the right spec, milestone, and supporting docs
    - the sprint planning documentation file should be referenced in the handoff
11. Add a durable handoff note for the builder that says what to pick up next, why it is the priority, what guardrails apply, and what evidence or dependencies matter.
12. Recommend `do-task <issue>` as the next command once the sprint plan results in a builder-ready issue.

Do not stop at commentary or reprioritization alone. The expected outcome is:

- a prioritized execution batch
- milestone scope explicitly chosen with the user before issue-level planning
- user business preference explicitly checked before final sprint selection
- pre-existing `Ready` issues reviewed with the user as possible backlog items
- builder-ready issues moved to `Ready` on the project board
- blockers and dependencies reflected in GitHub issues
- issue-level discussion recorded as GitHub comments
- a sprint planning documentation file in the docs root
- explicit builder-ready handoff
