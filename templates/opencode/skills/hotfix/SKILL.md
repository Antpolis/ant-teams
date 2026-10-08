---
name: hotfix
description: Coordinate the fast lane for any urgent fix where waiting for the normal delivery path would materially worsen impact, including production incidents, release blockers, and urgent pre-production issues.
disable-model-invocation: true
argument-hint: <urgent issue or GitHub issue>
---

# Hotfix Playbook

Use this playbook to route and coordinate a genuinely urgent fix. It accelerates coordination; it does not replace the existing GitHub delivery flow, role ownership, communication governance, review, approval, or merge gates. The orchestrator owns routing and must not implement or review the change itself.

## Qualification

A fix qualifies when waiting for the normal delivery path would materially worsen impact. This may include production incidents, significant user or operational harm, security or data-integrity risk, blocked critical workflows, or a release-blocking defect. Production impact is not required.

Urgency is not established merely by a requested deadline or preference for speed. The `tech-lead` confirms that the impact and scope justify this lane, and records the rationale and next action in the GitHub issue. If urgency is unclear, seek that confirmation before dispatching implementation.

## Fast-lane rules

- Use a GitHub task issue with no milestone; do not create a milestone or attach the issue to one. If no suitable issue exists, have `tech-lead` create it. No role other than `tech-lead` creates or modifies issues in normal flow. Fast lanes skip only initial spec-shaping and milestone creation.
- The issue must identify the impact and urgency rationale, observed and expected behavior, bounded scope and non-goals, acceptance criteria, verification evidence, risks, and applicable Durable Context.
- Do not require a new spec or milestone solely because the fix is urgent. If the change requires new product behavior, material scope expansion, or architecture/API/schema decisions, pause the hotfix implementation and route the broader work through the normal flow.
- Minimize delay in coordination and handoffs, not in evidence, safety, or required approval. Keep all task status, handoffs, blockers, and decisions in GitHub.

## Workflow and ownership

1. **Orchestrator — recognize and route.** When a request may qualify, load this playbook and consult `tech-lead` for the ordered queue/technical assessment before implementation work. Identify the issue and PR, urgency rationale, current state, risks, exact next owner, and any active work that must be reconciled. Do not interrupt or replace in-flight work without reconciling its GitHub record.
2. **Tech-lead — confirm readiness.** Confirm urgency and builder readiness before implementation: architecture and durable requirements/context are identified and consistent; scope and non-goals are bounded; risk and guardrails are understood; acceptance criteria are testable; and the verification plan is adequate. Ensure the issue is sequenced appropriately and in the correct project state. Provision or verify the task branch and worktree under the existing workflow. Record readiness in the GitHub issue. If anything is missing or ambiguous, resolve it or stop and record the blocker in GitHub.
3. **Builder — implement and evidence.** Make the smallest root-cause correction on the tech-lead-provided branch/worktree. Reproduce or establish the failure mode, add/update a focused regression test when practical, and run targeted checks plus relevant safety checks. Record exact commands and outcomes, skipped checks, remaining risks, and review focus in the PR handoff.
4. **Reviewer — independently verify.** Review scope, correctness, risks, acceptance evidence, and lightweight smoke verification. Record explicit approval or actionable findings in the PR. If findings require scope or technical decisions, route them to the appropriate owner rather than silently expanding the fix.
5. **Tech-lead — final gate and merge.** After reviewer approval, perform the final issue alignment and guardrail check. The default is tech-lead-only merge after reviewer approval and the final check. Record merge evidence and update the issue/project state using existing conventions.
6. **Orchestrator — continue and close the loop.** Verify the required GitHub records and gates, route any rework to builder on the same branch/PR, and ensure follow-up work is tracked separately when it falls outside the bounded urgent fix.

## Founder override

For a named task only, a founder may explicitly waive reviewer approval and/or the tech-lead final alignment check. Before proceeding when practical, record the waived gate or gates, rationale, scope, and founder decision in a GitHub issue comment. Safety and legal constraints remain in force. Tech-lead remains the sole merge actor and must record the override, residual risk, verification performed or skipped, and merge confirmation on the PR.

## Stop or leave the hotfix lane

Pause implementation and route through the existing escalation and decision process if:

- urgency is not supported by material impact;
- expected behavior, acceptance, or verification is unclear;
- the fix expands product scope or changes architecture, API, or schema contracts;
- security, data integrity, or operational risk makes the available verification insufficient;
- reproduction, access, or a required check is blocked;
- safe implementation cannot proceed within the current issue guardrails.

Record the impact, blocker, decision owner, and smallest next action in the GitHub issue or PR. Use normal strategist/tech-lead shaping for broader product work. Do not bypass review or merge approval to preserve urgency.

## Records and governance

- Keep durable operational communication—coordination, status, handoffs, blockers, and decisions—in GitHub issue comments. PR descriptions and review threads/comments are for implementation handoff and code-specific review; link significant review or merge outcomes to the issue when appropriate.
- Use the canonical handoff location and concise handoff format defined by `github-agentic-delivery-flow` and `agent-communication-log`; do not duplicate an existing handoff in another comment.
- Keep durable product, architecture, governance, or reusable knowledge in the central Obsidian project docs only when it meets the existing GOV-001 threshold. Do not create routine hotfix event notes or issue mirrors.
- Record role memory only for a reusable lesson; do not create a no-op entry.
- Preserve the existing review-loop, approval, state-transition, and tech-lead-only merge defaults, subject only to an explicit founder override recorded as above.
