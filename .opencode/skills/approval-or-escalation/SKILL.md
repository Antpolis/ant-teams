---
name: approval-or-escalation
description: Use when the GitHub delivery flow is already in place and the agent needs the specific approval, rework, blocker, defer, or escalation rules across strategist, tech-lead, builder, and reviewer. Prefer `github-agentic-delivery-flow` for the overall workflow model; use this skill for decision and escalation mechanics.
---

# Approval And Escalation

Use this skill whenever the agent needs to decide whether work can move forward, must return for rework, should be blocked, or needs escalation.

This skill defines the approval model for the multi-agent delivery loop. It helps prevent premature completion, unclear review ownership, and endless rework without decision.

## Approval Gates

Treat these as the minimum workflow approvals:

1. Product direction approved by founder
2. Technical direction approved by tech-lead
3. Implementation reviewed by reviewer — all mandatory criteria satisfied (KISS, separation of concerns, correct folder/package/namespace per architecture docs)
4. Lightweight smoke verification accepted by reviewer
5. Reviewer posts an explicit approval comment on the PR stating the issue is clear with no blockers, then moves the issue to `Ready to Merge`

The builder does not self-approve final readiness. The issue does not move to `Done` until the PR is merged; `Ready to Merge` is the state between reviewer approval and confirmed merge.

## Rework Loop Rules

- A reviewer finding sends the issue back to builder.
- Rework should stay within approved scope unless the founder or tech-lead expands it.
- Repeated findings of the same kind are a signal that the spec, task, or guardrails are weak.
- If the loop stops producing meaningful progress, escalate instead of forcing more churn.
- Track each review-development loop in the GitHub issue or PR discussion.
- Do not exceed 8 review-development loops before forcing an escalation decision.

## Escalation Restraint Rules

- Exhaust the next safe internal role delegation before escalating to the founder.
- Do not escalate just because the current role is uncertain; route to `strategist` for product ambiguity or `tech-lead` for technical ambiguity first.
- Do not escalate a question that is already answerable from the spec, issue, PR, repository docs, or role memory.
- Do not escalate merely to ask the founder to restate something that can be summarized as a concrete decision request by the agents.
- If escalation is still needed, make it narrow: ask for the smallest decision that unblocks progress.

## Escalation Payload Rules

Every escalation note must include:

- current state and owning role
- what was attempted internally
- what evidence was checked
- why internal delegation is no longer sufficient
- the exact decision needed
- the next step after that decision

## Loop Breaker Rules

When review loops reach 8 attempts, or the same architecture problem keeps repeating, treat it as a loop-breaker condition.

The approving role handling the loop-breaker decision should review:

- spec
- GitHub issue
- PR review discussion
- GitHub collaboration record
- architect memory
- relevant ADR, GOV, and ARCH docs
- current code direction

Record the loop-breaker decision in the GitHub issue or PR so the next role can continue without chat context.

Possible loop-breaker decisions:

- return to development with clarified guardrails
- create blocker for human input
- create defer task
- require spec, issue, or doc update
- approve with constraints

## Escalate To Strategist

Use when:

- the user value is unclear
- the issue should be split or scope-cut
- acceptance criteria do not represent the intended product outcome
- an issue in `Need attentions` requires product, scope, or success-criteria clarification before it can return to `Ready`

When escalating to `strategist`, prefer a concrete question such as scope cut, success criteria fix, acceptance rewrite, or product tradeoff choice instead of a generic "please review."

## Escalate To Tech-Lead

Use when:

- architecture guidance is missing or conflicting
- the implementation path is riskier than expected
- the reviewer keeps finding the same structural problem
- the task needs to be re-sequenced or decomposed
- 8 review loops have been reached and a technical decision is required
- an issue in `Need attentions` requires technical clarification or guardrail correction before it can return to `Ready`

When escalating to `tech-lead`, include the current implementation direction, reviewer findings if any, and the smallest technical decision needed to continue safely.

## Escalate To Founder

Use when:

- tradeoffs affect product direction
- time, cost, or quality goals conflict
- access, permission, or destructive action requires explicit human approval
- a blocker cannot be resolved safely by agents alone

Before escalating to founder from delivery execution, use `founder-escalation-preflight`.
That preflight must re-check repo docs, GitHub issue or spec history, relevant role memory, and remaining safe internal next steps.
If the orchestrator owns the current queue pass, the orchestrator must run this preflight and confirm there is no safe remaining role invocation before founder escalation.
If the strategist is deciding that founder input is needed, the strategist must run this preflight and confirm the remaining blocker is a true product, scope, prioritization, or business decision.
Do not escalate to founder if the answer is already recoverable from repo evidence or if another safe internal delegation step still exists.
Do not treat this as a gate on normal founder collaboration during shaping or planning.

## Defer Instead Of Thrash

Create a defer decision when:

- the current task can ship safely without the deferred improvement
- the remaining issue is real but not worth blocking the current value
- the follow-up condition and risk are clearly recorded

Prefer defer over repeated low-yield review loops when the remaining gap is understood, bounded, and safe to separate from the current deliverable.

## Required Blocker Note

Every blocker should say:

- what is blocked
- why it is blocked
- who must decide or act
- what the smallest unblocking step is

## Need Attentions Rule

`Need attentions` covers two distinct cases. Always label the GitHub comment clearly so the recipient knows which case applies.

### Internal — strategist or tech-lead intervention needed

Use when an issue needs strategist or tech-lead resolution before safe execution can continue, but is not yet a true external blocker.

- leave a durable GitHub comment before moving the issue
- name the question to resolve and which role should take it (strategist for product/scope, tech-lead for technical/architecture)
- attempt strategist or tech-lead resolution before escalating to the founder
- move the issue back to `Ready` once the resolution is recorded and the next executable step is clear
- move the issue to `Blocked` instead when the remaining problem is truly external or approval-bound

### Founder-facing — founder decision needed

Use when a PR or issue requires a founder decision before it can safely proceed or merge, and internal roles cannot resolve it.

- leave a durable GitHub comment addressed to the founder before moving the issue
- explain what decision is needed, what was already attempted internally, and what the smallest unblocking answer looks like
- run `founder-escalation-preflight` before making this transition to confirm internal paths are exhausted
- move the issue back to `In Review` or `Ready` once the founder decision is recorded
- move the issue to `Blocked` if the founder decision depends on an external condition outside anyone's control

## Usage Guidance

- Use this skill when deciding whether work is approved, rework, blocked, deferred, or escalated.
- Use this skill when defining approval gates in prompts, issue templates, or workflow docs.
- Use this skill with `state-transitions` so approval decisions map cleanly to board movement.
