---
name: pr-review-flow
description: Use when creating pull requests, starting code review, responding to review comments, running review loops, or syncing builder and reviewer conversation. Enforces PR-created review start and PR comments as the review conversation record.
---

# PR Review Flow

Use this skill whenever development is ready for reviewer review.

Use `agentic-flow-terms` as the canonical glossary for development loop, review loop, approval gate, task branch, GitHub collaboration record, and role memory.

## Core Rule

The review loop starts when the builder creates a pull request from the task branch.

Builder and reviewer conversation during review must be recorded in PR comments.

The GitHub issue and PR together must make the review loop understandable without chat context. Do not rely only on chat history.

Builder owns moving work into review. Reviewer owns sending it back with findings or approving it forward. Other roles may inspect or coordinate, but they should not impersonate builder or reviewer by posting their role-specific review-loop decisions in place of them during normal flow.

## PR Creation Requirements

Before asking reviewer to review, builder must create or prepare a PR with:

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

- Tech-lead guardrails followed: <yes/no/details>
- Known risks: <risks or none>
- Deferred work: <defer task or none>

## Approval Gates

- [ ] Reviewer approved
- [ ] Merge allowed
```

## PR Comment Rules

Use PR comments for review conversation between builder and reviewer:

- Reviewer posts findings as PR review comments or PR discussion comments.
- Builder responds to each finding in PR comments with fix summary, commit reference, or reason for disagreement.
- Reviewer resolves or reopens findings in PR comments.
- Reviewer verification result may be posted as a PR comment.
- Hard blockers and loop-breaker escalations must be mentioned in PR comments and cross-linked from the GitHub issue.

Every review pass should leave a durable trace:

- reviewer states approval, blocker, or findings clearly
- builder replies with fix summary, disagreement rationale, or follow-up question
- unresolved findings stay visible in the PR conversation until explicitly cleared

## Review Loop Rules

- Creating the PR starts the review loop.
- Each reviewer pass increments the loop count.
- If findings remain, builder fixes them on the same task branch and comments on the PR with the response.
- Repeat until reviewer approves, a hard blocker appears, or 8 loops are reached.
- Do not merge until reviewer approval passes.

## Development Loop Rules

- One issue should normally stay on one branch through its review-development loop unless tech-lead explicitly approves a branch reset or replacement.
- Builder should not open a fresh PR to dodge review history unless the previous PR is unusable and that decision is recorded.
- During `do-tasks`, treat the existing branch and PR as the default continuation path.
- If builder must replace the branch or PR during `do-tasks`, record the recovery reason in GitHub and link the superseded artifact to the replacement so review history stays traceable.
- Reviewer findings should be actionable and scoped to the approved task or to concrete safety/architecture concerns.
- Builder should not broaden implementation scope while responding to review unless the new work is required to satisfy the reviewed issue and that scope expansion is recorded.
- If builder and reviewer disagree on product intent, route to `strategist`.
- If builder and reviewer disagree on architecture, sequencing, or technical acceptability, route to `tech-lead`.

## GitHub Sync

After every PR review pass, update the GitHub issue or PR summary with:

- PR URL or identifier
- Current loop count
- Review result
- Summary of PR comments/findings
- Builder response summary
- Reviewer verification result if available
- Approval state
- Blocker, stopper, loop-breaker, or defer-task state

The GitHub issue is the task-level summary and the PR comments are the detailed review conversation.

If the detailed discussion happened in PR comments, the issue should still receive a concise summary when the review state materially changes so queue-level roles can continue from the issue alone.

## Role Memory Sync

After each review loop, update role memory using `role-memory`:

- Builder memory captures implementation lessons and recurring review fixes.
- Architect memory captures architecture constraints, accepted tradeoffs, defer tasks, and loop-breaker rationale.
- Reviewer memory captures smoke verification behavior and runtime gaps.
