---
name: orchestrator-task-done
description: Use when the orchestrator has just seen one issue reach done, blocked, or another local stopping point during `do-task` execution and must decide whether to continue with the next pending issue, resolve `Need attentions`, or escalate. This skill is specifically for preventing queue passes from ending early after one issue is finished. Trigger whenever the orchestrator is about to end a `do-task` pass because a single issue looks complete, because an escalation happened mid-pass, or because the queue state needs a post-completion continuation decision.
---

# Orchestrator Task Done

Use this skill when the orchestrator reaches the end of one issue's active loop and needs to decide whether the overall queue pass should continue.

The goal is simple: finishing one issue is not the same as finishing the pass.

Use the agentic-flow-terms skill as the canonical glossary for workflow terms.
Use github-agentic-delivery-flow for the overall GitHub operating model.
Use do-task for the full queue-driving behavior before and around this decision point.
Use state-transitions, approval-or-escalation, and founder-escalation-preflight for board movement and escalation decisions.
Use agent-communication-log and role-memory when durable context needs to be checked before routing the next step.

## Core Rule

When one issue is done, blocked, or paused, the orchestrator must explicitly decide what happens to the rest of the queue before ending the pass.

Do not treat issue completion as permission to return to the user.
Treat it as a checkpoint:

1. verify whether another pending issue can move now
2. verify whether any `Need attentions` issue can be resolved internally
3. verify whether any escalation already in motion is actually blocking the next pending issue
4. only then decide whether founder escalation or user return is truly needed

## Continuation Order

Apply this order every time an issue leaves the active loop:

1. Confirm the just-finished issue is actually settled for this pass.
2. Check whether any issue is in `Ready to Merge`. If yes, route it to `tech-lead` for the final spec-alignment check and merge decision before doing anything else.
3. Check whether any other issue is already pending and executable (`Ready`, `In Progress`, `In Review`).
4. If yes, continue directly to that pending issue.
5. If no pending executable issue exists, check whether any issue is in `Need attentions`.
6. If a `Need attentions` issue exists, inspect the GitHub comment to determine the recipient:
   - Internal: route to `strategist` for product/scope/prioritization ambiguity, or `tech-lead` for technical/architecture ambiguity.
   - Founder-facing: run `founder-escalation-preflight` then escalate if confirmed.
7. After the responsible role responds, decide whether the issue can return to `Ready`, must move to `Blocked`, or truly needs founder escalation.
8. Only after `Ready to Merge`, pending issues, and `Need attentions` issues are all exhausted should the orchestrator consider ending the pass.

## Pending-Issue Rule

If at least one pending issue is executable, keep going.

Executable means:

- the issue is in `Ready to Merge`, `Ready`, `In Progress`, or `In Review`, or can safely be returned to one of those states
- dependencies are not blocking
- the next responsible role is clear
- the required internal delegation can happen now

`Ready to Merge` issues are always the highest-priority executable work. Route them to `tech-lead` immediately — do not start fresh `Ready` work while a `Ready to Merge` issue is waiting.

Do not pause the pass just because the previous issue required effort, produced a PR, or triggered review.

## Need-Attentions Rule

When no pending executable issue remains, inspect issues that need attention before ending the pass.

Use this routing default:

- send product meaning, scope cuts, success criteria, prioritization, or business tradeoff questions to `strategist`
- send technical direction, sequencing, feasibility, architecture, or guardrail questions to `tech-lead`

If strategist or tech-lead can resolve the issue safely, record the durable guidance and return the issue to `Ready`.
If they determine the issue is truly external or approval-bound, move it to `Blocked` or prepare escalation.

Do not escalate to the founder merely because `Need attentions` exists.

## Mid-Pass Escalation Rule

Sometimes founder escalation is activated while other queue work still exists.

When that happens, do not assume the queue pass must stop. First decide whether the escalation blocks the remaining pending issues.

Ask:

- what exact founder decision is pending?
- which issue or spec does that decision affect?
- does any other pending issue depend on that decision right now?

Then apply this rule:

- if the founder escalation does not block another pending issue, continue with the pending issue and keep the escalation tracked separately
- if the founder escalation does block the next pending issue or the active spec path, run founder-escalation-preflight and then escalate

The orchestrator should prefer continued internal execution whenever a safe pending issue still exists.

## Blocking Test For Escalations

Treat an escalation as blocking only when one of these is true:

- the next pending issue cannot be interpreted safely without the founder decision
- the next pending issue depends on access, approval, spend, timeline, or scope authority owned by the founder
- all remaining pending issues share the same unresolved founder-level dependency

Treat an escalation as non-blocking when:

- it affects only a later issue
- it affects a different spec group that is not currently the best executable path
- the remaining queue still contains safe work that can proceed under current approvals and guardrails

## Pre-Return Checklist

Before ending the call or returning control to the user, the orchestrator must explicitly confirm:

1. no issue is in `Ready to Merge` awaiting tech-lead final check
2. no executable pending issue remains (`Ready`, `In Progress`, `In Review`)
3. no `Need attentions` issue can still be routed to strategist or tech-lead internally
4. any founder escalation already opened has been tested for whether it blocks the remaining queue
5. any blocking founder escalation has passed founder-escalation-preflight
6. no safe internal delegation path remains

If any item fails, continue the pass.

## Output Format

When using this skill, conclude with a compact continuation decision:

### Queue Continuation Decision

- Just-finished issue: <id and state outcome>
- Ready to Merge issues: <ids or none>
- Pending executable issue available: yes or no
- Next pending issue: <id or none>
- Need attentions to resolve: <issue and owner role, or none>
- Founder escalation already active: yes or no
- Escalation blocking remaining work: yes or no
- Next action: <route to tech-lead for merge / continue with issue / route to strategist / route to tech-lead / run founder escalation / return to user>
- Why this is the next safe step: <one short sentence>
