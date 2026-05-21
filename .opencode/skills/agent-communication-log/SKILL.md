---
name: agent-communication-log
description: Use when multiple agents collaborate on a spec, GitHub milestone, GitHub issue, pull request, code review, QA verification, blocker, defer decision, or review-development loop. Enforces GitHub issue comments and PR comments as the collaboration record, while keeping only durable memory and retrospective knowledge local.
---

# Agent Communication Log

Use this skill whenever work moves between agents or enters a development-review-QA loop.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use the GitHub workflow skills for milestones, issues, project states, approvals, and escalation rules.
Use role-memory for local durable memory after collaboration has been recorded in GitHub.

## Purpose

Keep all important collaboration between agents in GitHub so the workflow does not depend on one continuous chat context.

The GitHub collaboration record is the shared execution record for:

- Product/spec decisions
- Architect guardrails
- Task planning decisions
- Developer implementation notes
- Code review findings
- QA smoke results
- Review-development loop count
- Hard blockers needing human intervention
- Architect escalation decisions
- Defer tasks for architecture decisions or technical debt
- Links to role-memory or retrospective updates when durable local memory is needed

## Collaboration Location

Use GitHub as the collaboration surface.

Prefer:

- milestone description for spec summary and canonical repo-doc links
- GitHub issue comments for task collaboration, handoffs, blockers, and status discussion
- PR comments and review threads for code-review conversation
- GitHub issue or PR links when referencing follow-up work or defer decisions

Use local repo files only for durable memory and retrospective notes, not as the primary collaboration surface.

## Required Rule

Every agent handoff must be recorded in the relevant GitHub issue or PR comment thread.

Do not rely only on chat history for decisions, blockers, review comments, or QA results.

## Comment Structure

```md
## Handoff

Role: <role>
Target Role: <next role or reviewer>
State: <project state>
Spec / Milestone: <link or id>
Task / Issue: <link or id>
Branch / PR: <branch or PR link if relevant>

Summary:
- <what happened>

Evidence:
- <tests, commands, screenshots, links, or PR references>

Open Findings / Risks:
- <finding or none>

Blockers / Defer Decisions:
- <blocker, defer, or none>

Next Action:
- <what the next role should do>
```

## Review Loop Rules

- After development finishes, architect-reviewer starts code review.
- If code review has findings, return to developer with actionable findings.
- Developer fixes findings on the same task branch.
- Repeat development-review until architect-reviewer clears the code or a stop condition is reached.
- The loop must run no more than 8 times.
- Record each review-development cycle in GitHub issue comments or PR review threads so the loop history is visible in the collaboration surface.

## Stop Conditions

Stop the loop when one of these happens:

- Architect-reviewer clears the development.
- A hard blocker requires human intervention.
- The loop reaches 8 attempts and architecture issues still remain.

## Escalation Rules

If there is a hard blocker:

- Record the blocker in the relevant GitHub issue or PR thread.
- Set status to `blocked`.
- State exactly what human input, access, or decision is required.

If 8 loops are reached and architecture issues remain:

- Escalate to architect.
- Architect must review the task, spec, docs, and guardrails for conflicts.
- Architect may clear the stopper by creating a defer task.
- A defer task must say whether the issue will be resolved by an architecture decision update, a later task, or technical debt.

## Defer Task Rules

Only architect or the designated approving role should create architecture defer decisions.

A defer task must include:

- What is being deferred
- Why it is safe to defer
- Risk of deferring
- Target follow-up doc or task
- Whether an ADR, GOV, ARCH update, or technical debt item is required
- Conditions that would make the defer invalid

## Handoff Entry Quality Bar

Every handoff entry must be specific enough that the next agent can continue without chat context.

Include:

- Task IDs involved
- Files changed or reviewed
- Findings or decisions
- Verification evidence
- Next action
- Stopper or blocker state

## Comment Rules

- Keep task collaboration in the GitHub issue.
- Keep code-review discussion in the pull request.
- If a conversation affects execution, make sure the next agent can continue from GitHub alone without needing the chat transcript.
- When a durable lesson should outlive the issue or PR, record it in local role memory after the GitHub discussion is complete.

## Role Memory Rules

- After every task or review loop, developer, QA, and architect/architect-reviewer should review the GitHub collaboration record.
- Each role must update its role memory with durable information relevant to that role, using the role-memory skill.
- If there is no new durable information, record that in local role memory.
- Architect must read architect memory before making loop-breaker, blocker, defer-task, or architecture conflict decisions.
