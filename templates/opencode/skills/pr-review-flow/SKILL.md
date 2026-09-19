---
name: pr-review-flow
description: Use when creating pull requests, starting code review, responding to review comments, running review loops, or syncing builder and reviewer conversation. Enforces PR-created review start and PR comments or review threads as the canonical code-review conversation record.
---

# PR Review Flow

Use this skill whenever development is ready for reviewer review.

If `agentic-flow-terms` is available, use it as the canonical glossary for development loop, review loop, approval gate, task branch, GitHub collaboration record, and role memory. If it is not available, the definitions below are sufficient to execute this skill.

**Key terms used in this skill:**
- **review loop** — one pass by the reviewer followed by builder response; loops are counted from PR creation
- **loop-breaker** — an escalation that exits the review loop because progress is blocked (hard blocker, unresolvable disagreement, loop cap hit)
- **defer task** — work explicitly deferred out of scope and tracked for a future issue
- **task branch** — the git branch carrying the work for a single task or issue
- **collaboration record** — the GitHub issue plus its linked PR; issue comments carry task-level delegation, clarification, blockers, and founder requests, while PR comments and review threads carry code-review conversation

## Record Authority

The PR is the canonical code-review surface: PR comments and review threads carry review findings, builder responses, rework reasoning, verification results, approvals, and merge reasoning. The GitHub issue carries task-level delegation, blockers, founder requests, and concise state summaries.

The issue and PR together are the authoritative record. Chat history is not. Any decision, finding, or escalation that matters must appear in one or both before the loop closes. Obsidian may be linked only for durable specs, architecture, ADRs, GOV, runbooks, or exceptional decisions.

## Reviewer context discovery

Before reviewing code, read the GitHub issue and PR. From the issue's `Durable Context`, open the canonical SPEC and every applicable ARCH, ADR, GOV, and runbook URL. The linked SPEC is authoritative for durable product intent; the issue defines the scoped implementation slice; the PR supplies implementation and review evidence.

Do not search the vault broadly or reconstruct requirements from chat. If a required durable-context URL is missing, ambiguous, stale, or conflicts with the issue or PR, do not approve the PR: record the gap in the GitHub issue and route it to tech-lead.

## Core Rule

The review loop starts when the builder creates a pull request from the task branch.

Builder and reviewer conversation during review must be recorded in PR comments or review threads, including code-specific findings, responses, approvals, and merge confirmations.

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

- Canonical SPEC: <URL, or Not applicable — reason>
- Durable Context: <issue link; canonical documentation remains in the issue rather than duplicated here>
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

## Review Delegation — builder → reviewer

- Why reviewer is needed: <review the scoped implementation and listed risks>
- Expected action: <review the PR against issue scope, Durable Context, and verification evidence>
- Expected record: <PR review approval or actionable PR findings; issue summary when state changes>

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

Before judging placement, read the central Obsidian project architecture documents under `ANT_TEAM_DOCS_PROJECT_PATH`; source `./.github-project.env` once only if a direct command needs that variable. The project-defined structure takes precedence over generic language conventions. Do not apply Java, .NET, or TypeScript defaults if the project has its own documented layer definitions.

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

Use PR comments and review threads for the full code-review conversation:

- Reviewer submits blocking findings with `$ANT_TEAM_SCRIPTS/gh_project_helper.sh pr-review <PR> --request-changes --body-file <file>` when appropriate, or uses PR review threads/comments for individual code-specific findings.
- Reviewer submits a GitHub-native approval with `$ANT_TEAM_SCRIPTS/gh_project_helper.sh pr-review <PR> --approve --body-file <file>`, then moves the issue to `Ready to Merge`. The review body must state that no blockers remain.
- Hard blockers and loop-breaker outcomes are summarized in PR comments and cross-linked from the GitHub issue.

- builder records the implementation handover and each fix summary in the PR, with commit references
- reviewer records each pass, verification re-run results, and disagreement rationale in PR comments or review threads
- unresolved findings stay visible in the PR conversation until explicitly cleared
- the loop count per review pass is tracked in the PR conversation and summarized in the issue when the review state changes

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
- If the PR or issue needs founder input before it can proceed or merge, confirm strategist and tech-lead review were both attempted, record the reasoning in the PR and a founder-addressed GitHub issue comment, then move the issue to `Need attentions` instead of posting an approval.

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

The detailed review discussion lives in PR comments and review threads. The issue receives a concise summary whenever the review state materially changes so queue-level roles can continue from the issue alone.

## Role Memory Sync

After each review loop, update project-specific role memory when there is a durable lesson. Role memory is a persistent record per role (builder, architect, reviewer) in the central Obsidian project folder. Do not use it as a routine review-event log or write it to repository-local memory files.

- Builder memory captures implementation lessons and recurring review fixes.
- Architect memory captures architecture constraints, accepted tradeoffs, defer tasks, and loop-breaker rationale.
- Reviewer memory captures verification behavior and runtime gaps found during review.
