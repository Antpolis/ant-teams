---
name: approval-and-escalation
description: Use when the GitHub delivery flow is already in place and the agent needs the specific approval, rework, blocker, defer, or escalation rules across strategist, tech-lead, builder, and validator. Prefer `github-agentic-delivery-flow` for the overall workflow model; use this skill for decision and escalation mechanics.
---

# Approval And Escalation

Use this skill whenever the agent needs to decide whether work can move forward, must return for rework, should be blocked, or needs escalation.

This skill defines the approval model for the multi-agent delivery loop. It helps prevent premature completion, unclear review ownership, and endless rework without decision.

## Approval Gates

Treat these as the minimum workflow approvals:

1. Product direction approved by founder
2. Technical direction approved by tech-lead
3. Implementation reviewed by validator
4. Lightweight smoke verification accepted by validator

The builder does not self-approve final readiness.

## Rework Loop Rules

- A validator finding sends the issue back to builder.
- Rework should stay within approved scope unless the founder or tech-lead expands it.
- Repeated findings of the same kind are a signal that the spec, task, or guardrails are weak.
- If the loop stops producing meaningful progress, escalate instead of forcing more churn.
- Track each review-development loop in the GitHub issue or PR discussion.
- Do not exceed 8 review-development loops before forcing an escalation decision.

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

## Escalate To Tech-Lead

Use when:

- architecture guidance is missing or conflicting
- the implementation path is riskier than expected
- the validator keeps finding the same structural problem
- the task needs to be re-sequenced or decomposed
- 8 review loops have been reached and a technical decision is required

## Escalate To Founder

Use when:

- tradeoffs affect product direction
- time, cost, or quality goals conflict
- access, permission, or destructive action requires explicit human approval
- a blocker cannot be resolved safely by agents alone

## Defer Instead Of Thrash

Create a defer decision when:

- the current task can ship safely without the deferred improvement
- the remaining issue is real but not worth blocking the current value
- the follow-up condition and risk are clearly recorded

## Required Blocker Note

Every blocker should say:

- what is blocked
- why it is blocked
- who must decide or act
- what the smallest unblocking step is

## Usage Guidance

- Use this skill when deciding whether work is approved, rework, blocked, deferred, or escalated.
- Use this skill when defining approval gates in prompts, issue templates, or workflow docs.
- Use this skill with `state-transitions` so approval decisions map cleanly to board movement.
