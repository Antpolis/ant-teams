---
name: fix-bug
description: Run the full fast-lane workflow for a bounded bug fix or regression. Use when reproducing and correcting an existing defect without expanding product behavior, including when the user invokes /fix-bug.
disable-model-invocation: true
argument-hint: <bug description or GitHub issue>
---

# Fix a bug

Use this skill for the complete delivery of a bounded bug fix. It does not replace the repository's role ownership, GitHub delivery flow, communication governance, approval gates, or documentation policy. Read the assigned GitHub issue and its Durable Context first. Use `agentic-flow-terms` as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, role memory, collaboration record, and approval gate.

## Fast-lane boundary

A bounded fix corrects an existing behavior that is demonstrably broken or regressed. It does not add new product behavior, settle a product decision, or change architecture, API, or schema contracts.

Fast lanes skip only initial spec-shaping and milestone creation. A bounded fix requires a GitHub task issue with no milestone; do not create a milestone or attach the task issue to one. The issue must define the defect, expected behavior, acceptance criteria, verification evidence, scope, and applicable Durable Context:

- Reuse the assigned issue when the bug falls within its approved scope.
- If no suitable issue exists, ask the tech-lead to create a standalone task issue without a milestone. Do not create a spec or milestone for an otherwise bounded fix.
- Do not begin implementation while expected behavior or acceptance is ambiguous. Route technical or verification ambiguity to the tech-lead.

## Workflow

1. **Confirm scope and ownership.** Read the issue, acceptance criteria, guardrails, and applicable Durable Context. Confirm the defect fits the issue and the fast-lane boundary. Keep the issue as the Collaboration Record. Follow the existing task-branch and project-state rules.
2. **Establish evidence.** Reproduce the defect or confirm the failure mode with an existing failing test, trace, or other observable evidence. Record the observed behavior and the expected behavior from the issue. If evidence is unavailable or expected behavior is unclear, stop and ask the tech-lead to resolve it before coding.
3. **Tech-lead readiness confirmation.** Before builder starts, tech-lead confirms the issue is ready: applicable architecture and durable requirements/context are identified and consistent; scope and non-goals are bounded; risk and guardrails are understood; acceptance criteria are testable; and the verification plan is adequate. Record readiness in the GitHub issue. If any item is missing or ambiguous, resolve it or stop before implementation.
4. **Make the smallest correction.** Trace the failure to its root cause, then change only what is needed to restore the accepted behavior. Do not widen the fix beyond the bug unless necessary and approved. Add or update a behavior-focused regression test when practical.
5. **Verify the fix.** Run the targeted regression test and relevant checks for the affected area. Confirm the reproduction now passes and the expected behavior holds. Report exact commands and outcomes. Disclose skipped or unavailable checks and any remaining risk; do not claim success without evidence.
6. **Prepare the review handoff.** Open or update the task PR under the existing builder workflow. Include the issue link, root cause, implementation summary, reproduction evidence, verification results, skipped checks, known risks, and reviewer focus. Move the issue to the appropriate review state using the established project workflow. Keep task status, handoffs, blockers, and review discussion in GitHub.
7. **Complete the existing review and merge gates.** The reviewer independently checks scope, correctness, acceptance evidence, and lightweight smoke verification, then records approval or actionable findings on the PR. The tech-lead performs the final issue alignment check and merge. These are the default gates.

## Founder override

For a named task only, a founder may explicitly waive reviewer approval and/or the tech-lead final alignment check. Before proceeding when practical, record the waived gate or gates, rationale, scope, and founder decision in a GitHub issue comment. Safety and legal constraints remain in force. Tech-lead remains the sole merge actor and must record the override, residual risk, verification performed or skipped, and merge confirmation on the PR.

## Escalate out of the fast lane

Stop implementation and route the decision through the existing roles when any of these apply:

- Expected behavior or acceptance is ambiguous.
- The fix requires new product behavior or a material scope expansion.
- The change affects architecture, an API contract, or a schema.
- Risk is elevated enough that the issue's guardrails or verification are insufficient.
- A required reproduction or verification step is blocked.

Ask the tech-lead to resolve technical scope, architecture, risk, or verification questions. If the work needs product shaping, route it into the normal strategist and tech-lead flow. Do not automatically create a spec or milestone as an escalation response. Record the blocker, reason, decision owner, and next action in the GitHub issue or PR.

## Communication and records

- Keep durable operational communication—coordination, status, handoffs, blockers, and decisions—in GitHub issue comments. PR descriptions and review threads/comments are for implementation handoff and code-specific review; link significant review or merge outcomes to the issue when appropriate.
- Do not create routine Obsidian notes or communication-event records for a bug fix. Add or update Obsidian only if the result meets the durable-knowledge threshold in the applicable governance.
- Add role memory only when the task produces a reusable lesson. Do not create a no-op memory entry.
