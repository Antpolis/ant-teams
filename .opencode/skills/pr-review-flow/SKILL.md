---
name: pr-review-flow
description: Use when creating pull requests, starting code review, responding to review comments, running review loops, or syncing builder and reviewer conversation. Enforces PR-created review start, Obsidian event files as the working review conversation record, and PR comments for code-specific findings and final code-review results.
---

# PR Review Flow

Use this skill whenever development is ready for reviewer review.

If `agentic-flow-terms` is available, use it as the canonical glossary for development loop, review loop, approval gate, task branch, GitHub collaboration record, and role memory. If it is not available, the definitions below are sufficient to execute this skill.

**Key terms used in this skill:**
- **review loop** — one pass by the reviewer followed by builder response; loops are counted from PR creation
- **loop-breaker** — an escalation that exits the review loop because progress is blocked (hard blocker, unresolvable disagreement, loop cap hit)
- **defer task** — work explicitly deferred out of scope and tracked for a future issue
- **task branch** — the git branch carrying the work for a single task or issue
- **collaboration record** — the Obsidian communication event files for the issue plus the GitHub issue and linked PR; the Obsidian events carry the working conversation, GitHub carries final decisions, status, closure, and code-review results

## Record Authority

The Obsidian communication event files are the detailed working review conversation between builder and reviewer. PR comments carry code-specific findings, review threads, and the final code-review result. The GitHub issue is the task-level summary.

These three together are the authoritative record. Chat history is not. Any decision, finding, or escalation that matters must appear in at least one of them before the loop closes.

## Core Rule

The review loop starts when the builder creates a pull request from the task branch.

Builder and reviewer working conversation during review must be recorded as individual Obsidian communication event files. Code-specific findings, approvals, and merge confirmations stay in PR comments.

The GitHub issue, the PR, and the Obsidian communication events together must make the review loop understandable without chat context. Do not rely only on chat history.

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

Before judging placement, read the central Obsidian project architecture documents under `ANT_TEAM_DOCS_PROJECT_PATH` (source `./.github-project.env` — the sole committed project config source). The project-defined structure takes precedence over generic language conventions. Do not apply Java, .NET, or TypeScript defaults if the project has its own documented layer definitions.

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

## Optional Over-Engineering Check (ponytail-review)

After or beside the mandatory correctness, architecture, security, scope, and KISS review, the reviewer may optionally run `ponytail-review` as a separate pass.

- It is a one-shot, read-only report per its own skill definition; it never writes code automatically.
- It reports over-engineering only, in its one-line findings/net metric format.
- It cannot override acceptance criteria, tech-lead guardrails, security requirements, required tests, reviewer approval, or merge gates.
- It does not add a review loop or an approval gate.
- If a finding affects a review or merge decision, record it in PR comments and reflect it in the GitHub issue summary.

## PR Comment Rules

Use PR comments for the code-review result only:

- Reviewer posts code-specific findings as PR review comments or PR discussion comments.
- Reviewer posts the explicit approval comment stating no blockers remain before moving the issue to `Ready to Merge`.
- Hard blockers and loop-breaker outcomes are summarized in PR comments and cross-linked from the GitHub issue.

Working review conversation lives in the Obsidian communication event files for the issue:

- builder records the implementation handover and each fix summary as Obsidian events with commit references
- reviewer records each pass, verification re-run results, and disagreement rationale as Obsidian events
- unresolved findings stay visible in the PR conversation until explicitly cleared
- the loop count per review pass is tracked in the Obsidian events

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
- If the PR or issue needs founder input before it can proceed or merge, confirm strategist and tech-lead review were both attempted, record the reasoning in an Obsidian event file, then move the issue to `Need attentions` with a founder-addressed GitHub comment instead of posting an approval.

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
- Summary of PR code-review findings
- Builder response summary
- Reviewer verification result if available
- Approval state
- Blocker, stopper, loop-breaker, or defer-task state

The detailed working discussion lives in Obsidian communication events. PR comments carry the code-review result, and the issue receives a concise summary whenever the review state materially changes so queue-level roles can continue from the issue alone.

## Role Memory Sync

After each review loop, create the required Obsidian communication event file and update project-specific role memory. Role memory is a persistent record per role (builder, architect, reviewer) in the central Obsidian project folder. Do not write it to repository-local memory files.

- Builder memory captures implementation lessons and recurring review fixes.
- Architect memory captures architecture constraints, accepted tradeoffs, defer tasks, and loop-breaker rationale.
- Reviewer memory captures verification behavior and runtime gaps found during review.
