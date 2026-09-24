---
description: Run full spec, architecture, planning, development, review, and validation flow.
agent: strategist
---

Run the full delivery workflow for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Ask the strategist agent to research repository documents relevant to this deliverable and produce a technical product/enhancement spec. Search by topic, feature name, domain terms, paths, module names, and synonyms. Do not rely on document numbering.
2. Ask the strategist agent to review the product direction and spec correctness before architecture or task planning begins.
3. Ask the tech-lead agent to review the technical viability of the spec after strategist approval and before architecture or task planning begins.
4. Record the strategist-to-tech-lead planning handoff in GitHub. Create or update the canonical Obsidian SPEC only when the direction is stable; it must state open decisions, their owners, and whether they block planning. Keep routine shaping, delegation, status, blockers, and review communication in GitHub issues and PRs.
5. Ask the tech-lead agent to review viability, architecture fit, risks, and builder guardrails using the canonical SPEC, linked durable docs, and GitHub collaboration record. Do not create a milestone or tasks while a planning-blocking decision remains open.
6. Ask the tech-lead agent to use the how-to-create-task skill and create builder-ready GitHub tasks. Every task must contain bounded scope, non-goals, dependencies, acceptance tests, verification commands, and a `Durable Context` section with exact URLs to the canonical SPEC and every applicable ARCH, ADR, GOV, and runbook. Only then may it move to `Ready`.
7. Run execution through the `do-task` skill. Tech-lead should drive the queue, group issues by spec, clarify unclear issues when needed, and delegate technically clear issues to builder one by one.
8. After development, run reviewer review. Reviewer must read role memory and the GitHub collaboration record first. If review has findings, return to builder on the same task branch. Repeat development-review until reviewer clears the development, a hard blocker appears, or 8 loops are reached.
9. After a task or review loop, update role memory only when the GitHub collaboration record reveals a reusable lesson; do not create no-op memory entries.
10. If a hard blocker appears, stop for human intervention with a blocker entry in GitHub. If 8 loops are reached and architecture issues remain, escalate to tech-lead. Tech-lead must read role memory before deciding and may clear a stopper by creating a defer task for ADR, GOV, ARCH, future implementation, or technical debt.
11. Do not merge the task branch back until reviewer approves the code review and smoke verification outcome is acceptable.
12. Ask the reviewer agent to verify the app can still run and confirm task acceptance tests or verification evidence where relevant.
13. Fix issues found by review and repeat verification until each task is completed, blocked, deferred by tech-lead, or user input is required.
14. When every required issue for the SPEC is `Done` and the user requested shipping, invoke `close-spec` to reconcile the milestone, create the GitHub Release/tag, close the milestone, preserve `Done` board history, and safely remove merged local task workspaces.

Do not stop after planning if implementation was requested. Do not stop after the first error. Continue until the requested outcome is implemented and verified or a real blocker is reached.
