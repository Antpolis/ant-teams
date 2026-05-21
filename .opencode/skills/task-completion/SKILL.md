---
name: task-completion
description: Use when reviewing, closing, marking complete, or validating an implementation task represented by a GitHub issue and PR. Enforces definition of done, acceptance tests, verification evidence, approval gates, and GitHub workflow state updates.
---

# Task Completion

Use this skill whenever completing, reviewing, closing, or validating a task represented by a GitHub issue and PR.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use the GitHub workflow skills for state, review, blocker, defer, and approval behavior.
Use role-memory for local durable lessons after GitHub collaboration is updated.

## Completion Gate

A task can be marked `completed` only when all are true:

- The implementation satisfies the task scope.
- Out-of-scope work was avoided or justified.
- The task-specific definition of done is met.
- The task-specific acceptance tests pass or have an explicit accepted reason for not running.
- Required verification commands pass or blockers are documented.
- Related docs/configuration were updated if required.
- Architecture guardrails were followed.
- No known severe review findings remain open.
- The implementation is on a working branch created from the production base branch.
- Architect-reviewer has approved the code review.
- QA smoke has confirmed the app can still run.
- The relevant GitHub issue or PR records the development handoff, review findings, QA result, and approval state.
- Developer, QA, and architect role memories have been reviewed and updated after the task or explicitly marked as having no new durable memory.

## Required Review Steps

1. Read the GitHub issue.
2. Read the linked PR and review discussion.
3. Read the GitHub collaboration record using agent-communication-log.
4. Read the parent spec and relevant docs if referenced.
5. Inspect changed files.
6. Compare implementation against scope, definition of done, and acceptance tests.
7. Run or verify evidence for required commands.
8. Confirm the implementation branch has not been merged back without architect-reviewer and qa-smoke approval.
9. Append review, QA, approval, blocker, or defer-task notes to the GitHub issue or PR.
10. Use role-memory to update developer, QA, and architect memory from the GitHub collaboration record, or record that there is no new durable memory for a role.
11. Update the GitHub issue state and completion notes if editing is allowed.

## Task Status Rules

- Use `completed` only when the completion gate passes.
- Use `blocked` when a dependency, missing access, unresolved decision, or failing required verification prevents completion.
- Keep `in-progress` if implementation exists but verification or review is incomplete.
- Do not mark complete based only on intent or partial implementation.
- Do not approve merge until architect-reviewer and qa-smoke both approve.
- If code review finds issues, keep the task `in-progress` and return it to development unless a stop condition is reached.

## Review-Development Loop

- After development finishes, architect-reviewer performs code review.
- If review finds issues, developer fixes them on the same task branch.
- Repeat the loop until architect-reviewer clears the development, a hard blocker is found, or the loop reaches 8 iterations.
- Track each loop in the GitHub issue or PR discussion.
- Do not exceed 8 review-development loops.
- If 8 loops are reached and architecture issues remain, escalate to architect.
- If a hard blocker appears at any time, stop and request human intervention with a precise blocker entry in GitHub.
- After each loop, developer, QA, and architect/architect-reviewer must review the GitHub collaboration record and update role memory before the next loop starts.

Use the GitHub workflow skills to record review results, QA outcomes, defer decisions, blocker state, and completion decisions.

## Architect Escalation

When escalated after 8 loops or persistent architecture conflict:

- Architect reviews the task, spec, docs, guardrails, review findings, and GitHub collaboration record.
- Architect reads architect memory before deciding how to break the loop.
- Architect determines whether the task/spec conflict is real, the architecture guidance is incomplete, or the implementation direction is wrong.
- Architect may unblock by creating a defer decision in GitHub and linking any follow-up issue.
- A defer task may target an ADR, GOV, ARCH update, future implementation task, or technical debt cleanup.
- Defer tasks must include risk, why deferral is acceptable, and conditions that would invalidate the deferral.

## Completion Checklist

Add or verify this checklist in the GitHub issue or PR summary when closing it:

```md
#### Completion Checklist

- [ ] Scope implemented
- [ ] Out-of-scope work avoided or documented
- [ ] Definition of done met
- [ ] Acceptance tests passed or exception documented
- [ ] Verification commands passed or blocker documented
- [ ] Docs/config updated if needed
- [ ] Architecture guardrails satisfied
- [ ] Review findings resolved or documented
- [ ] Working branch created from production base
- [ ] Architect-reviewer approved
- [ ] QA smoke approved
- [ ] Branch not merged before approval
- [ ] GitHub collaboration record updated
- [ ] Developer memory reviewed/updated
- [ ] QA memory reviewed/updated
- [ ] Architect memory reviewed/updated
- [ ] Review loop count is 8 or less
```

## Final Completion Summary

Report:

- Issue ID and title
- Completion decision: completed/blocked/in-progress
- Branch and base branch
- Merge approval: approved/not approved
- Review loop count
- Role memory update status
- Evidence used
- Verification result
- Acceptance test result
- Open risks or follow-up tasks
