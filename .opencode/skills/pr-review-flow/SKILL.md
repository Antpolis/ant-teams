---
name: pr-review-flow
description: Use when creating pull requests, starting code review, responding to review comments, running review loops, or syncing builder and reviewer conversation. Enforces PR-created review start and PR comments as the review conversation record.
---

# PR Review Flow

Use this skill whenever development is ready for reviewer review.

If `agentic-flow-terms` is available, use it as the canonical glossary for development loop, review loop, approval gate, task branch, GitHub collaboration record, and role memory. If it is not available, the definitions below are sufficient to execute this skill.

**Key terms used in this skill:**
- **review loop** — one pass by the reviewer followed by builder response; loops are counted from PR creation
- **loop-breaker** — an escalation that exits the review loop because progress is blocked (hard blocker, unresolvable disagreement, loop cap hit)
- **defer task** — work explicitly deferred out of scope and tracked for a future issue
- **task branch** — the git branch carrying the work for a single task or issue
- **GitHub collaboration record** — the GitHub issue plus its linked PR, which together must tell the full story of the work

## Record Authority

The PR comments are the detailed review conversation. The GitHub issue is the task-level summary.

These two together are the authoritative record. Chat history is not. Any decision, finding, or escalation that matters must appear in one or both before the loop closes.

## Core Rule

The review loop starts when the builder creates a pull request from the task branch.

Builder and reviewer conversation during review must be recorded in PR comments.

The GitHub issue and PR together must make the review loop understandable without chat context. Do not rely only on chat history.

Builder owns moving work into review. Reviewer owns sending it back with findings or approving it forward. Other roles may inspect or coordinate, but they should not impersonate builder or reviewer by posting their role-specific review-loop decisions in place of them during normal flow.

## PR Creation Requirements

Before asking reviewer to review, builder must create or prepare a PR with:

- Task ID and title
- Spec ID (if a spec exists)
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

Builder fills this in before requesting review.

```md
## Task

- Spec: <SPEC-ID, path, or none>
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

## Builder Notes

- Tech-lead guardrails followed: <yes/no/details>
- Known risks: <risks or none>
- Deferred work: <defer task or none>

## Approval Gates

- [ ] Reviewer approved
- [ ] Merge allowed
```

## Review Criteria

Reviewer must check all of the following on every pass. These are not optional opinions — they are mandatory findings if violated. Leniency here is a reviewer failure, not discretion.

### KISS — Keep It Simple

Flag as a finding if:

- the implementation is more complex than the simplest change that solves the problem
- a new abstraction has only one caller or one use case at the time of review
- indirection was added where a direct implementation would be clearer
- a helper hides business logic that should be visible at the call site
- speculative generalization or future-proofing was added that the task did not require
- cleanup or architectural redesign was bundled silently into a feature change

The test: can a reviewer understand the change without asking what the author was thinking? If not, it is not simple enough.

### Separation of Concerns

Flag as a finding if:

- a single file or class accumulates unrelated responsibilities
- a shared utility contains feature-specific logic
- a function both decides policy and performs side effects in ways that are hard to separate
- business logic leaks into infrastructure, transport, or persistence layers (or vice versa)
- a module that should own one thing is being stretched to own a second thing for convenience

When raising a concern about separation, name the two concerns that are mixed and where each belongs.

### Folder, Package, and Namespace Structure

Flag as a finding if new code is placed in the wrong layer, namespace, or package.

Before judging placement, read the repository architecture documents under `docs/arch/`. The project-defined structure takes precedence over generic language conventions. Do not apply Java, .NET, or TypeScript defaults if the project has its own documented layer definitions.

If no project-specific architecture document covers the placement question, fall back to language conventions as a secondary guide:

**Java:** class should be in the package that matches its architecture layer (domain, application, infrastructure, etc.)

**.NET / C#:** class should be in the namespace and assembly that matches its layer; assembly boundaries should match solution layer boundaries

**TypeScript / JavaScript:** file should be in the module folder that matches its responsibility (component, service, lib, shared types, etc.)

When raising this finding, state: where the file lives now, where the architecture document says it belongs, and which document you are citing. If no architecture document covers it, state which language convention you applied and why.

### How to Raise These Findings

- State the principle being violated (KISS, separation of concerns, wrong package/namespace).
- Quote or cite the specific code location.
- Name the concrete impact: harder to test, misleading location, responsibility creep, etc.
- Suggest the simplest fix that resolves the violation.

Do not soften these findings with "consider" or "might want to." If it violates a principle, state it as a finding. Builder may disagree and argue for keeping it — that disagreement should be explicit and recorded, not avoided by the reviewer hedging.

## PR Comment Rules

Use PR comments for review conversation between builder and reviewer:

- Reviewer posts findings as PR review comments or PR discussion comments.
- Builder responds to each finding in PR comments with fix summary, commit reference, or reason for disagreement.
- Reviewer resolves or reopens findings in PR comments.
- After responding to findings, reviewer re-runs the verification commands from the PR body and posts the result as a PR comment.
- Hard blockers and loop-breaker escalations must be mentioned in PR comments and cross-linked from the GitHub issue.

Every review pass should leave a durable trace:

- reviewer states approval, blocker, or findings clearly
- builder replies with fix summary, disagreement rationale, or follow-up question
- unresolved findings stay visible in the PR conversation until explicitly cleared

## Review Loop Rules

- Creating the PR starts the review loop.
- Each reviewer pass increments the loop count.
- If findings remain, builder fixes them on the same task branch and comments on the PR with the response.
- Repeat until reviewer approves, a hard blocker appears, or 8 loops are reached. (The cap prevents unbounded rework; 8 passes is enough for any well-scoped task.)
- If 8 loops are reached without approval, treat it as a loop-breaker: record the state in the PR and GitHub issue, and escalate to `tech-lead` to decide whether to continue, reframe, or close the task.
- When reviewer approves with no blockers, reviewer must:
  1. Post an explicit approval comment on the PR stating the issue is clear with no blockers and the PR is ready to merge.
  2. Move the GitHub issue to `Ready to Merge`.
- Do not merge until the issue is in `Ready to Merge` and the approval comment is on the PR.
- If the PR or issue needs founder input before it can proceed or merge, move the issue to `Need attentions` with a founder-addressed GitHub comment instead of posting an approval.

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

After every PR review pass, update the GitHub issue with:

- PR URL or identifier
- Current loop count
- Review result
- Summary of PR comments/findings
- Builder response summary
- Reviewer verification result if available
- Approval state
- Blocker, stopper, loop-breaker, or defer-task state

The detailed discussion lives in PR comments. The issue receives a concise summary whenever the review state materially changes so queue-level roles can continue from the issue alone.

## Role Memory Sync

After each review loop, update role memory. Role memory is a persistent record per role (builder, architect, reviewer) that accumulates lessons across tasks. If a `role-memory` skill is available, invoke it. Otherwise write the updates directly into the relevant role memory file.

- Builder memory captures implementation lessons and recurring review fixes.
- Architect memory captures architecture constraints, accepted tradeoffs, defer tasks, and loop-breaker rationale.
- Reviewer memory captures verification behavior and runtime gaps found during review.
