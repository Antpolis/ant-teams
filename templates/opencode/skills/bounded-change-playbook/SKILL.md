---
name: bounded-change-playbook
description: Use when the user asks you to implement a small, bounded code change, such as a bug fix, minor enhancement, or urgent fix. The user-selected agent triages the request and chooses direct implementation or a tech-lead/builder/reviewer loop based on blast radius, risk, and uncertainty. Do not use for read-only debugging, broad product work, or approved spec queues.
argument-hint: <change request>
---

# Bounded Change Playbook

Use this playbook when the user asks to make a contained change and wants development to start. It combines the former `fix-bug` and `hotfix` lanes. It does not enter the `/do-tasks` spec queue and does not require a GitHub milestone or issue. The user's request and the active conversation are the task context; use a PR when the repository's contribution process or selected specialist route calls for one.

The agent the user selected to start the work owns triage, route selection, coordination, and completion checks. Do not select a different agent for triage. Read `github-agentic-delivery-flow` for shared role ownership, collaboration, review, and merge conventions when those conventions apply. Do not load `do-tasks` for standalone bounded changes.

## 1. Qualify and classify

The user-selected agent first establishes the intended outcome, affected behavior, scope, acceptance signal, and constraints from the user and repository. Inspect the relevant code and tests before deciding the route.

Classify the request as one or more of:

- **Bug fix:** restore existing behavior that is demonstrably broken or regressed. Reproduce it or establish the failure with a failing test, trace, or other observable evidence before changing code.
- **Small enhancement:** add or adjust behavior that the user has clearly requested, with limited scope and no unresolved product decision.
- **Hotfix:** a bug or bounded change whose material user, operational, security, or data-integrity impact makes waiting for ordinary planning harmful. Urgency is based on impact, not a deadline or desire for speed.

If a critical requirement or expected behavior is unclear, investigate what can be learned from the repository or runtime first. Ask the user only for a product or preference decision that cannot be resolved from evidence. Do not invent new behavior.

## 2. Select the execution route

Choose the lightest route that safely completes the request. A blast radius of roughly four to five files, classes, or methods is a useful direct-work boundary, not a strict count. Risk, uncertainty, cross-component coupling, and ability to verify matter more than the raw number. Record the route and concise reason in the runtime handoff or PR when one is used.

### Direct route

The user-selected agent may implement and verify the change directly when all are true:

- scope and expected behavior are clear;
- the root cause or implementation path is straightforward;
- the change is localized and low-risk;
- no product, architecture, API, schema, security, or data-integrity decision is needed;
- The selected agent can perform meaningful verification within the task.

Make the smallest complete change, add or update a focused regression check when practical, run relevant checks, and report exact evidence and any limits. Do not dispatch a specialist merely to repeat routine coordination. Follow repository branch, commit, and PR requirements; this route does not waive them.

### Specialist development loop

Use the specialist loop when the change exceeds the direct-work boundary, spans coupled components, has an uncertain root cause, needs technical judgment, carries meaningful risk, or requires independent implementation review. The user-selected agent remains the coordinator and works with tech-lead to create and maintain a task list using the active harness's native task-list tool. Follow the portability contract below; do not assume a tool name or API. The list decomposes the bounded change into actionable steps and tracks completion against the requested outcome and acceptance criteria. It is not a GitHub issue queue. Invoke roles in this order:

### Portable task-list contract

- Discover and use the task-list capability exposed by the active harness. Use its documented tool name, arguments, and status values; never guess a tool call from another harness.
- Represent each step as one concise, actionable unit with a completion check. Preserve dependencies and order where they affect safe execution.
- Keep task state current as work proceeds, and make blocked steps and their unblocking condition visible.
- If the harness exposes no task-list tool, keep the same checklist in the active conversation. Do not create a repository task file, GitHub issue, or milestone just to emulate the missing tool.

1. **Tech-lead** analyzes the change, confirms technical direction and guardrails, and proposes ordered tasks with dependencies, acceptance coverage, and verification steps. The selected agent puts them in the native task list and checks they cover the user's full request before implementation.
2. **Builder** implements the listed tasks on the assigned workspace/branch and records implementation and verification evidence in the PR handoff when a PR is used.
3. **Reviewer** independently tests and reviews the implementation against the request and task list, recording approval or actionable findings.
4. **Tech-lead** resolves technical review findings, performs the final alignment check, and merges when the shared managed-delivery gates apply.

Use strategist only when the user's product intent or acceptance is genuinely unclear and cannot be resolved from the request or evidence. Keep dependent role handoffs synchronous and give each role the relevant decisions, constraints, evidence, checklist, and exact next action. A specialist route does not require a milestone or issue; use a PR and its review record as appropriate to the repository's contribution process.

## 3. Keep the change bounded

- Fix the demonstrated cause or implement the requested enhancement, not adjacent hypothetical problems.
- Preserve existing behavior outside the accepted scope.
- Add a focused regression test when practical; otherwise use the closest useful executable verification and explain why.
- Do not introduce a new product direction, materially expand scope, or make an unapproved contract change under this playbook.
- Keep task status and coordination in the active conversation for ad hoc work. Use the PR for implementation and review details when a PR exists. Do not create an issue, milestone, Obsidian event note, or other tracking artifact solely to log a direct request.

## 4. Stop or reroute

Pause the bounded change if evidence shows that safe completion requires substantial new behavior, unresolved product intent, a material architecture/API/schema change, broader planning, or verification unavailable under the current constraints. Explain the finding and smallest decision needed. Ask the user before switching into spec shaping or `/do-tasks`; do not silently start another managed workflow.

If a hotfix request does not have material impact, continue only if it qualifies as an ordinary bounded change; do not label it urgent or bypass relevant review. If risk is elevated or the change cannot be safely verified, do not use the direct route.

## 5. Verify and report

Run the targeted reproduction or acceptance check and relevant tests for the affected area. Report what changed, the route used, exact verification commands and outcomes, any skipped checks, and remaining risk. Do not claim success without evidence. For a specialist PR, verify the required handoffs and approval records before reporting completion.
