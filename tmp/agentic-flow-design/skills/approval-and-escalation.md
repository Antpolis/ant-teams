# Approval And Escalation

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
