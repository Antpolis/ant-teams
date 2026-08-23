---
name: agent-communication-log
description: Use when multiple agents collaborate on a spec, GitHub milestone, GitHub issue, pull request, code review, reviewer verification, blocker, defer decision, or review-development loop. Uses the central Obsidian project folder for agent-to-agent communication records, while using GitHub Issues, milestones, Projects, and PRs for status, execution state, and final closing messages.
---

# Agent Communication Log

Use this skill whenever work moves between agents or enters a builder-reviewer review loop.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use the GitHub workflow skills for milestones, issues, project states, approvals, and escalation rules.
Use role-memory for project-specific durable memory in the central Obsidian project folder after collaboration has been recorded in GitHub.

After completing a communication-log task, commit and push only the communication files changed by that task to the documentation vault remote.

## Purpose

Keep agent-to-agent collaboration in the central Obsidian project folder so the workflow does not depend on one continuous chat context. Keep GitHub as the authoritative status and execution system.

The full agent communication and role-memory record is stored in Obsidian. GitHub issue and PR comments carry only:

- Final decisions (product/spec, guardrail, planning, defer, escalation outcomes)
- Status changes and closure confirmations
- Code-review results: code-specific findings, approval evidence, merge confirmation
- Concise founder decision requests
- Links to the project-specific Obsidian communication and role-memory notes for durable context

Working conversation, implementation notes, verification detail, review-loop history, and loop counts belong in the Obsidian event files, not GitHub comments.

## Collaboration Location

Use the central Obsidian project folder for agent-to-agent communication. Resolve it by sourcing `./.github-project.env` (the sole committed project config source) and using `ANT_TEAM_DOCS_PROJECT_PATH`. Before creating an event file, use the approved communication template and Base in the central vault:

- Template: `$ANT_TEAM_DOCS_VAULT_PATH/01-Architecture-Meta/Templates/Agent Communication Template.md`
- Base: `$ANT_TEAM_DOCS_VAULT_PATH/01-Architecture-Meta/Templates/Bases/Agent Communication.base`

Prefer the `record-communication.sh` helper (installed at `$ANT_TEAM_SCRIPTS`, or `templates/scripts/record-communication.sh` in the ant-teams repo) to record and list events — it fills the approved template and never writes to GitHub. If no template exists, stop and request one; do not invent the format.

Store communication records under:

- `<project-doc-path>/agent-communication/milestones/<milestone-slug>/`
- `<project-doc-path>/agent-communication/issues/issue-<number>/`

Use GitHub for:

- Project, milestone, and issue status
- Assignees, labels, dependencies, and workflow state
- Final closing messages on the issue and PR
- Code-specific review threads and approval evidence

Use Obsidian for:

- Agent-to-agent handoffs and working communication
- Shaping conclusions and technical interpretation
- Review-loop summaries and durable coordination context
- Links to the relevant GitHub issue, milestone, and PR

Do not duplicate live status in Obsidian; link to GitHub instead.

## Required Rule

Every agent delegation and agent-to-agent communication about an issue or milestone must be recorded in the relevant Obsidian communication note. The note must link to the GitHub issue or milestone. Final closing messages must still be posted to the GitHub issue and PR.

Use `handoff` only when returning control to the founder or escalating for a founder decision.

Within the build-review loop, expect the delegated agent to write its own durable note. `orchestrator` or another coordinating role may verify that the note exists, but should not impersonate builder or reviewer ownership by writing their execution handoff in place of them during normal flow.

Do not rely only on chat history for decisions, blockers, review comments, or verification results.

## Communication Rules

- If a discussion changes scope, sequencing, guardrails, acceptance, blocker state, or ownership, record the detailed agent communication in Obsidian and update GitHub status or final summary as appropriate before another role is expected to act.
- If agents reason together in chat, Obsidian needs the durable communication summary; GitHub needs only the status change, link, blocker, or final closing message required for execution traceability.
- Prefer concise decision summaries over long narrative comments, but include enough detail for the next role to continue without asking the same question again.
- Create one Obsidian Markdown file per communication event. Do not use one large issue or milestone log. Keep GitHub comments for final closure, status-critical decisions, and code-specific PR review discussion.
- Do not split one decision across scattered comments if one durable summary can carry the context more cleanly.

## Communication Event File Convention

Each agent-to-agent communication event is one Markdown file under the relevant issue or milestone folder.

Filename:

`YYYY-MM-DD-<agent-name>-<title>-<status>.md`

Rules:

- Use ISO date format `YYYY-MM-DD`.
- Use a stable lowercase agent role name.
- Keep the title to five words or fewer.
- End the filename with `open` or `closed`.
- Use matching frontmatter `status: open` or `status: closed`.
- Include `issue`, `milestone`, `project`, `from_role`, `to_role`, `communication_type`, `date`, and GitHub links.
- Link the event to the next action or closing event when applicable.

Example:

`2026-08-20-builder-handoff-open.md`

```yaml
doc_type: agent-communication
project: ant-teams
issue: 123
milestone: SPEC-001
from_role: builder
to_role: reviewer
communication_type: handoff
status: open
date: 2026-08-20
github_issue: https://github.com/Antpolis/ant-teams/issues/123
github_pr: https://github.com/Antpolis/ant-teams/pull/45
tags:
  - agent-communication
  - issue/123
```

## Comment Structure

```md
# Communication Event

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

- After development finishes, reviewer starts code review and lightweight smoke verification.
- Builder should leave a detailed implementation handover note before reviewer starts.
- If code review has findings, return to builder with actionable findings.
- Builder fixes findings on the same task branch.
- Repeat development-review until reviewer clears the code or a stop condition is reached.
- The loop must run no more than 8 times.
- Record each review-development cycle as one or more individual Obsidian communication event files. Link the issue and PR; record final approval and closure in GitHub.

## Stop Conditions

Stop the loop when one of these happens:

- Reviewer clears the development.
- A hard blocker requires human intervention.
- The loop reaches 8 attempts and architecture issues still remain.

## Escalation Rules

If there is a hard blocker:

- Record the blocker as an individual Obsidian communication event file in the relevant issue folder.
- Set GitHub status to `Blocked`.
- Add a concise GitHub link/comment when the blocker affects execution or requires founder input.
- State exactly what human input, access, or decision is required.

If 8 loops are reached and architecture issues remain:

- Escalate to tech-lead.
- Tech-lead must review the task, spec, docs, and guardrails for conflicts.
- Tech-lead may clear the stopper by creating a defer task.
- A defer task must say whether the issue will be resolved by an architecture decision update, a later task, or technical debt.

## Defer Task Rules

Only tech-lead or the designated approving role should create architecture defer decisions.

A defer task must include:

- What is being deferred
- Why it is safe to defer
- Risk of deferring
- Target follow-up doc or task
- Whether an ADR, GOV, ARCH update, or technical debt item is required
- Conditions that would make the defer invalid

## Delegation Entry Quality Bar

Every delegation entry must be specific enough that the next agent can continue without chat context.

Include:

- Task IDs involved
- Files changed or reviewed
- Findings or decisions
- Verification evidence
- Next action
- Stopper or blocker state

If the next role is expected to decide something, state the exact question. If the next role is expected to execute, state the exact action.

## Comment Rules

- Keep each agent-to-agent task communication in its own Obsidian event file inside the issue communication folder.
- Keep code-review discussion in the pull request.
- If a conversation affects execution, make sure the next agent can continue from GitHub alone without needing the chat transcript.
- When a durable lesson should outlive the issue or PR, record it in project-specific Obsidian role memory after the Obsidian communication record is complete.

## Role Memory Rules

- After every task or review loop, builder, reviewer, and tech-lead should review the GitHub collaboration record.
- Each role must update its role memory with durable information relevant to that role, using the role-memory skill.
- If there is no new durable information, record that explicitly in project-specific Obsidian role memory.
- Tech-lead must read architect memory before making loop-breaker, blocker, defer-task, or architecture conflict decisions.
