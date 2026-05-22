---
name: task-development
description: Use when implementing an assigned GitHub issue linked to a product spec or milestone. Enforces reading the issue, linked spec/docs, GitHub collaboration context, following acceptance criteria, using a task branch, and returning work through GitHub PR review.
---

# Task Development

Use this skill whenever implementing an assigned GitHub issue.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use the GitHub workflow skills for issue state, PR review, approvals, blockers, and escalation rules.
Use role-memory for local durable lessons after GitHub collaboration is updated.

## Required Behavior

- Read the assigned GitHub issue completely before editing.
- Read the linked milestone/spec, related docs, GitHub issue comments, and relevant PR discussion.
- Read the parent spec, related docs, architect guardrails, and dependencies referenced by the issue.
- Confirm task dependencies are completed or not required.
- Start development from the current production base branch.
- Create a new working branch before editing code.
- Do not merge the working branch back to the production base branch until both architect-reviewer and qa-smoke approve.
- Update the GitHub issue/project state to `In Progress` when starting if editing is allowed.
- Implement only the assigned task scope.
- Do not implement out-of-scope items unless required to complete the task and clearly report why.
- Run the issue's verification commands and acceptance tests when available.
- If verification fails, diagnose and fix until passing or blocked.
- Append developer handoff notes to the relevant GitHub issue or PR before sending work for validation.
- Update the GitHub issue with completion notes if editing is allowed.

## Development Loop

1. Read the assigned GitHub issue.
2. Read referenced docs and guardrails.
3. Read the relevant GitHub issue comments and PR discussion using agent-communication-log.
4. Confirm the production base branch and working tree state.
5. Create a new task branch from the production base branch before editing.
6. Inspect relevant code before editing.
7. Make the smallest correct changes.
8. Run verification commands and acceptance tests.
9. Fix failures.
10. Repeat until done or blocked.
11. Append GitHub handoff notes for the next role.
12. Push the working branch when ready if remote access is available and appropriate.
13. Update GitHub issue state and notes.

Use the GitHub workflow skills to keep issue state, PR review, blockers, and approvals synchronized.

## Branching Rules

- The production base branch is the branch that represents runnable production code, usually `main`, `master`, `production`, or the repository's documented release branch.
- If the production base branch is unclear, inspect repository docs and git branches. Ask the user only if it remains ambiguous.
- Before creating a branch, inspect the current branch and working tree.
- If unrelated uncommitted changes already exist, do not overwrite or revert them. Ask how to proceed if they conflict with the task.
- Create a branch name using this pattern when possible: `task/<issue-id>-<short-title>`.
- Keep implementation commits on the task branch.
- Do not merge, squash, rebase onto production, or delete the branch unless explicitly requested after approval.
- A task branch is eligible for merge only after architect-reviewer approves the code review and qa-smoke confirms the app can still run.

## Scope Control

Before editing, identify:

- Included scope
- Out of scope
- Expected files or modules
- Dependencies
- Definition of done
- Acceptance tests

If the issue is too vague to implement safely, stop and ask for clarification or request task refinement with `how-to-create-task`.

## GitHub-Only Rule

- Treat the GitHub issue, project status, issue comments, and PR comments as the operational task record.
- Do not rely on local markdown task files, local boards, or local communication logs as the primary execution surface.
- Use repository docs only for canonical specs, architecture guidance, ADRs, and related implementation context.

## Completion Notes Template

When updating a GitHub issue or PR after implementation, add:

```md
#### Completion Notes

- Branch: <branch name>
- Base branch: <production base branch>
- Files changed: <paths>
- Verification run: <commands>
- Acceptance tests: pass/fail/not run with reason
- Review status: pending architect-reviewer and qa-smoke approval
- GitHub issue or PR updated: yes/no
- Remaining risks: <risks or none>
- Completed by: <agent/user if known>
- Completed at: <YYYY-MM-DD>
```

## Final Response

Report:

- Issue ID and title
- Branch name and production base branch
- Files changed
- Verification commands run
- Acceptance test result
- Merge status: not merged until architect-reviewer and qa-smoke approve
- Any blocker, skipped verification, or residual risk
