---
name: task-completion
description: Use when reviewing, closing, marking complete, or validating an implementation task represented by a GitHub issue and PR. Enforces definition of done, acceptance tests, verification evidence, approval gates, and GitHub workflow state updates.
---

# Task Completion

Use this skill whenever completing, reviewing, closing, or validating a task represented by a GitHub issue and PR.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use the GitHub workflow skills for state, review, blocker, defer, and approval behavior.
Use role-memory for project-specific durable lessons in the central Obsidian project folder after GitHub collaboration is updated.

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
- Reviewer has approved the code review and smoke verification outcome.
- Individual Obsidian communication event files record builder handoff, reviewer findings, and loop context.
- The GitHub issue and PR contain the final closing message, verification result, and approval state.
- Builder, reviewer, and architect role memories have been reviewed and updated after the task or explicitly marked as having no new durable memory.

## Required Review Steps

1. Read the GitHub issue.
2. Read the linked PR and review discussion.
3. Read the relevant Obsidian communication event files and GitHub status/final-closure records using agent-communication-log.
4. Read the parent spec and relevant central Obsidian project docs if referenced.
5. Confirm documentation changes were made in the resolved Obsidian project folder, not repository `docs/` or `.docs/`.
6. Inspect changed files.
7. Compare implementation against scope, definition of done, and acceptance tests.
8. Run or verify evidence for required commands.
9. Confirm the implementation branch has not been merged back without reviewer approval.
10. Append review, verification, approval, blocker, or defer-task notes to the GitHub issue or PR.
11. Use role-memory to update project-specific builder, reviewer, and architect memory in the central Obsidian project folder, or record that there is no new durable memory for a role.
12. Update the GitHub issue state and completion notes if editing is allowed.

## Task Status Rules

- Use `Done` only when the completion gate passes.
- Use `Blocked` when a dependency, missing access, unresolved decision, or failing required verification prevents completion.
- Keep `In Progress` if implementation exists but verification or review is incomplete.
- Do not mark complete based only on intent or partial implementation.
- Do not approve merge until reviewer has approved the issue for completion.
- If code review finds issues, keep the task `In Progress` and return it to development unless a stop condition is reached.

## Review-Development Loop

- After development finishes, reviewer performs code review and lightweight smoke verification.
- If review finds issues, builder fixes them on the same task branch.
- Repeat the loop until reviewer clears the development, a hard blocker is found, or the loop reaches 8 iterations.
- Track each loop in the GitHub issue or PR discussion.
- Do not exceed 8 review-development loops.
- If 8 loops are reached and architecture issues remain, escalate to tech-lead.
- If a hard blocker appears at any time, stop and request human intervention with a precise blocker entry in GitHub.
- After each loop, builder, reviewer, and tech-lead or architect memory owner must review the GitHub collaboration record and update role memory before the next loop starts.

Use the GitHub workflow skills to record review results, verification outcomes, defer decisions, blocker state, and completion decisions.

## Optional Complexity Checks (ponytail-review, ponytail-audit, ponytail-debt)

Before marking a task `Done`, the reviewer may optionally:

- run `ponytail-review` on the task diff to surface over-engineering in the changed code
- run `ponytail-audit` for broader task- or milestone-level cleanup context
- use `ponytail-debt` to harvest deliberate simplification markers left in the work

All three are one-shot, read-only reports per their own skill definitions; none of them writes code automatically.

- Record results only when they affect a completion decision; otherwise no record is required.
- Any warranted follow-up becomes a GitHub issue or defer task only through the existing tech-lead ownership of defer decisions.
- These checks do not block completion unless the existing completion criteria require it or a real risk demands it.
- The definition of done, acceptance gates, 8-loop cap, role memory rules, and GitHub-only rules stay unchanged.

## Tech-Lead Escalation

When escalated after 8 loops or persistent architecture conflict:

- Tech-lead reviews the task, spec, docs, guardrails, review findings, and GitHub collaboration record.
- Tech-lead reads architect memory before deciding how to break the loop.
- Tech-lead determines whether the task/spec conflict is real, the architecture guidance is incomplete, or the implementation direction is wrong.
- Tech-lead may unblock by creating a defer decision in GitHub and linking any follow-up issue.
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
- [ ] Reviewer approved
- [ ] Branch not merged before approval
- [ ] GitHub collaboration record updated
- [ ] Builder memory reviewed/updated
- [ ] Reviewer memory reviewed/updated
- [ ] Architect memory reviewed/updated
- [ ] Review loop count is 8 or less
```

## Final Completion Summary

Report:

- Issue ID and title
- Completion decision: Done/Blocked/In Progress
- Branch and base branch
- Merge approval: approved/not approved
- Review loop count
- Role memory update status
- Evidence used
- Verification result
- Acceptance test result
- Open risks or follow-up tasks

## GitHub-Only Rule

- Treat GitHub issue state, GitHub Project Workflow State, final decision and closure comments, and PR code-review results as the authoritative task workflow surface; the full working record lives in the Obsidian collaboration record.
- Do not close or validate work based on local task-file state alone.
- Use the central Obsidian project folder for canonical spec and architecture context that GitHub issues and milestones link back to.
