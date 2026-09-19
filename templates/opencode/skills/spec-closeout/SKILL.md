---
name: spec-closeout
description: Use when a completed SPEC or GitHub milestone needs final delivery closeout: validate the remaining issues and board state, create the GitHub Release and tag, close the milestone, and safely clean merged issue worktrees and branches.
---

# SPEC Closeout

Use this skill only after delivery work for one canonical `SPEC-###` is complete and ready to ship. It closes a **spec**, not an individual issue. Use `task-completion` for individual issue completion and `release-management` for release-note and release-readiness details.

GitHub remains the operational closeout record. The canonical Obsidian SPEC, ARCH, ADR, GOV, and runbook notes remain durable knowledge. Do not create a vault closeout transcript.

## Ownership

- **Orchestrator** drives the closeout pass and keeps the next safe action moving.
- **Tech-lead** owns the technical release decision, GitHub Release/tag, milestone closure, and safe cleanup of merged worktrees and local branches.
- **Strategist** confirms that the delivered scope satisfies the SPEC's business acceptance criteria when that has not already been recorded.
- **Builder** supplies missing implementation or verification evidence only; it does not self-close the spec.
- **Reviewer** supplies missing review evidence only; it does not create releases or close milestones.

## Hard Closeout Gate

Do not create a release, tag, close a milestone, or clean a task workspace until all required milestone issues are in `Done` and each has a merged PR or an explicit, approved non-code completion record.

For every issue not in `Done`:

- keep the milestone open; or
- have tech-lead create and link a follow-up issue, record the deferral and risk in GitHub, then move the deferred issue out of the closing milestone (or to its approved follow-up milestone) with explicit approval.

Never force an open, blocked, or unreviewed issue to `Done` merely to close a milestone.

## Closeout Procedure

1. **Resolve the target.** Read the canonical SPEC, its GitHub milestone, milestone description, completed issues, linked PRs, and the latest GitHub issue/PR comments. Confirm the milestone links to the exact Obsidian SPEC URL.
2. **Reconcile scope.** Confirm every required issue is `Done`; every merged PR is on the production base branch; and every SPEC acceptance criterion has shipped or has an approved, linked deferral. Record any reconciliation decision in the milestone closeout comment.
3. **Confirm durable documentation.** If delivery changed durable product intent, architecture, governance, runbooks, or created a reusable lesson, ensure the responsible strategist or tech-lead updated the appropriate Obsidian note and linked it from GitHub. Do not create a closeout note when nothing durable changed.
4. **Run release gates.** Follow `release-management`: run the repository's required release verification, collect results, reviewer approval, PR checks, and deployment evidence. Stop on a failed required gate unless an explicit human release decision is recorded in GitHub.
5. **Create the release and tag.** Tech-lead chooses the next repository-valid tag under `release-management`, writes release notes with the SPEC/milestone, resolved issues, verification results, and evidence, then runs:
   ```sh
   "$ANT_TEAM_SCRIPTS/gh_project_helper.sh" release-create TAG --title "TAG" --notes-file /tmp/release-notes.md
   ```
   The GitHub Release is the canonical shipped-release record and creates the tag. Re-read it with `release-view TAG`.
6. **Record and close the milestone.** Confirm one final time that every issue still attached to the milestone is `Done`; deferred work must already have been moved to its follow-up milestone or removed from this milestone. Add a milestone comment linking the release URL/tag, completed issues, test evidence, any deferred work, and cleanup result. Then close it:
   ```sh
   "$ANT_TEAM_SCRIPTS/gh_project_helper.sh" milestone-close MILESTONE_NUMBER
   ```
   Re-read the milestone and verify `state: "closed"`.
7. **Clean the board correctly.** Keep completed items in GitHub Project `Done`; that is the auditable history and the clean board state. Do **not** archive or remove Project items merely because the spec is closed. Close invalidated issues or move approved follow-up work to the appropriate active milestone/state with an explanatory GitHub comment.
8. **Clean local workspaces safely.** For every merged task branch no longer needed for review, rollback, or follow-up fixes, tech-lead runs:
   ```sh
   "$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh" issue-123 BASE_BRANCH BRANCH_NAME WORKTREE_PATH
   ```
   This helper refuses unmerged branches. Do not use `git branch -D`, `git worktree remove --force`, or broad branch-pruning commands. Keep the production base worktree and any active/unmerged task workspace.
9. **Report closeout.** Post the final closeout summary to the GitHub milestone and report the release URL/tag, milestone state, completed/deferred issues, cleanup outcomes, verification evidence, and any remaining risks.

## Milestone Closeout Comment

```md
## SPEC Closeout — <SPEC-###>

- Canonical SPEC: <Obsidian URL>
- GitHub Release: <URL>
- Release tag: `<TAG>`
- Milestone: <URL> — closed

### Delivered

- #<issue> — <title>

### Deferred or Follow-up

- #<issue> — <reason and approved risk>, or None

### Verification

- <command> — pass

### Workspace Cleanup

- `issue-123` — worktree and local branch removed, or retained with reason

### Remaining Risks

- None, or <risk and owner>
```

## Rules of Restraint

- A GitHub Release/tag is optional only when the repository or milestone explicitly says the deliverable is not released. Record that decision in the milestone comment.
- The release tag must be created through `release-create`, never by an ad hoc local `git tag` command.
- Closing a milestone does not erase GitHub history. Keep its issues, PRs, comments, and `Done` project items available for traceability.
- Do not delete remote branches unless a repository-specific policy explicitly requires it. This closeout flow only removes safe local task branches and worktrees.
- Do not touch unrelated specs, milestones, issues, worktrees, or branches.
