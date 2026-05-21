---
name: pr-review-flow
description: Use when creating pull requests, starting code review, responding to review comments, running review loops, or syncing developer and architect-reviewer conversation. Enforces PR-created review start and PR comments as the review conversation record.
---

# PR Review Flow

Use this skill whenever development is ready for architect-reviewer review.

Use `agentic-flow-terms` as the canonical glossary for development loop, review loop, approval gate, task branch, GitHub collaboration record, and role memory.

## Core Rule

The review loop starts when the developer creates a pull request from the task branch.

Developer and architect-reviewer conversation during review must be recorded in PR comments.

The GitHub issue and PR together must make the review loop understandable without chat context. Do not rely only on chat history.

## PR Creation Requirements

Before asking architect-reviewer to review, developer must create or prepare a PR with:

- Task ID and title
- Spec ID
- PM ticket if available
- GitHub issue link
- Branch name and production base branch
- Summary of implementation
- Verification commands and results
- Acceptance test evidence
- Known risks or skipped checks

## PR Title Format

Use this format when possible:

```text
<PM-ID optional> <TASK-ID>: <short task title>
```

Examples:

```text
TASK-001: Add pgvector-backed search
ENG-123 TASK-001: Add pgvector-backed search
```

## PR Body Template

```md
## Task

- Spec: <SPEC-ID or path>
- Task: <TASK-ID>
- PM Ticket: <ticket or none>
- GitHub Issue: <link>
- Branch: <branch>
- Base Branch: <production base branch>

## Summary

<What changed and why.>

## Scope

- <implemented scope>

## Out Of Scope

- <explicitly excluded work>

## Verification

- [ ] `<command>` - <pass/fail/not run with reason>

## Acceptance Tests

- [ ] <acceptance test> - <pass/fail/not run with reason>

## Review Notes

- Architect guardrails followed: <yes/no/details>
- Known risks: <risks or none>
- Deferred work: <defer task or none>

## Approval Gates

- [ ] Architect-reviewer approved
- [ ] QA smoke approved
- [ ] Merge allowed
```

## PR Comment Rules

Use PR comments for review conversation between developer and architect-reviewer:

- Architect-reviewer posts findings as PR review comments or PR discussion comments.
- Developer responds to each finding in PR comments with fix summary, commit reference, or reason for disagreement.
- Architect-reviewer resolves or reopens findings in PR comments.
- QA smoke result may be posted as a PR comment.
- Hard blockers and loop-breaker escalations must be mentioned in PR comments and cross-linked from the GitHub issue.

## Review Loop Rules

- Creating the PR starts the review loop.
- Each architect-reviewer pass increments the loop count.
- If findings remain, developer fixes them on the same task branch and comments on the PR with the response.
- Repeat until architect-reviewer approves, a hard blocker appears, or 8 loops are reached.
- Do not merge until architect-reviewer and QA smoke approval gates pass.

## GitHub Sync

After every PR review pass, update the GitHub issue or PR summary with:

- PR URL or identifier
- Current loop count
- Review result
- Summary of PR comments/findings
- Developer response summary
- QA smoke result if available
- Approval state
- Blocker, stopper, loop-breaker, or defer-task state

The GitHub issue is the task-level summary and the PR comments are the detailed review conversation.

## Role Memory Sync

After each review loop, update role memory using `role-memory`:

- Developer memory captures implementation lessons and recurring review fixes.
- Architect memory captures architecture constraints, accepted tradeoffs, defer tasks, and loop-breaker rationale.
- QA memory captures smoke verification behavior and runtime gaps.
