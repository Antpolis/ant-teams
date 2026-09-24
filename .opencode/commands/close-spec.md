---
description: Close and release a completed SPEC: reconcile milestone issues and board state, create the GitHub Release/tag, close the milestone, and safely clean merged task workspaces.
agent: orchestrator
---

Close the completed spec or milestone: $ARGUMENTS

Use `spec-closeout` as the canonical procedure. Use `release-management`, `task-completion`, `state-transitions`, `github-issues-projects-cli`, and `github-conventions` for the detailed release, completion, board, and GitHub mechanics.

Rules:

1. Resolve the canonical `SPEC-###`, its GitHub milestone, and the production base branch from the SPEC/milestone record; do not infer them from chat.
2. Orchestrator invokes tech-lead to reconcile all milestone issues, PRs, release readiness, and safe workspace cleanup candidates. Invoke strategist only if business acceptance against the SPEC is not already evidenced in GitHub.
3. Do not close the milestone, create a release/tag, or delete any workspace while a required issue is not `Done`, a PR is unmerged, or a release gate is unresolved. Record an approved deferral and follow-up issue in GitHub instead.
4. Tech-lead creates the GitHub Release using `"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" release-create`; the GitHub Release creates the tag. Do not create an ad hoc local tag.
5. Tech-lead posts the `spec-closeout` milestone comment, closes the milestone with `milestone-close`, and verifies the closed state.
6. Keep completed project items in `Done`. Do not archive or remove them from the board: `Done` is the auditable delivery history. Close invalidated issues and route approved follow-up work to its active milestone/state instead.
7. Tech-lead removes only merged, no-longer-needed local task worktrees and branches via `"$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh"`. Never force-delete a branch or worktree, delete remote branches, or clean unrelated work.
8. Keep routine closeout evidence in the GitHub release and milestone comment. Update Obsidian only if a durable SPEC, ARCH, ADR, GOV, runbook, or reusable-lesson change is genuinely needed.

Finish with the release URL/tag, milestone status, issue disposition, verification evidence, cleanup results, and remaining risks.
