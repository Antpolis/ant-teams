# Shared Specialist Delivery Context

Read this reference only for an explicitly active managed delivery assignment. Ant Agent normally coordinates; specialists perform the assigned role and report back. Reading this reference does not activate a workflow. Do not load `do-task` merely to answer a role-specific question.

## Context and records

GitHub Issues and PRs are the active collaboration and execution record. Follow the assigned issue's scope, non-goals, acceptance criteria, dependencies, verification, and applicable exact `Durable Context` links. The explicitly selected playbook determines which artifacts are required. For planned spec delivery, read the canonical SPEC and relevant ARCH, ADR, GOV, and runbook notes. Do not impose spec-queue prerequisites on another playbook; follow its recorded readiness requirements.

Resolve missing or conflicting required context before the affected action. Route product intent, scope, success criteria, or acceptance ambiguity to strategist; technical, architecture, dependency, security, sequencing, or verification ambiguity to tech-lead. Record the question and resolution in the assigned GitHub issue when it exists. Before issue or milestone creation, return them to Ant and append your findings to the supplied local session note; do not create premature GitHub artifacts just to record a question. Preserve the existing worktree, branch, PR, and review history during continuation.

Use `github-conventions`, `state-transitions`, and `approval-or-escalation` for the assigned record or transition. Use `github-issues-projects-cli` before helper operations. Centralized helpers load `.github-project.env`; source it only when a direct command needs an `ANT_TEAM_*` value. Prefer common `gh` workflows such as `gh repo`, `gh issue`, `gh project`, and `gh api graphql` only when the simpler commands or repo wrapper do not cover the need.

Follow repository documentation routing. Use `documentation-standard` for durable vault changes; do not assume repository-local docs are authoritative. Keep routine handoffs, blockers, review findings, and state changes in GitHub. Use `agent-communication-log` only for exceptional durable decisions and `role-memory` only for reusable lessons, never as a completion gate. Use `founder-escalation-preflight` for delivery-execution blockers, not normal shaping discussion with the user.

## Receiving and returning context

Follow [Context Relay](context-relay.md). Read the incoming runtime brief and exact upstream handoff sources before acting; do not assume sibling agents share conversation history. State consequential inherited decisions and gaps briefly in your working response, and return an actionable summary with decisions, rationale, evidence, unresolved questions, and next action for the coordinator to relay. Flag mismatches before the affected action.

## Handoff and session context

Report the assigned outcome, relevant evidence, open risks or blockers, and exact next action in the canonical issue or PR location. Point to existing context instead of duplicating it. Do not claim another role's approval or complete its handoff on its behalf.

When a session note is supplied, read the exact note path passed in your delegation on entry and append a dated `## <role> — <UTC timestamp>` section on meaningful handoff. Touch only that session's note; never create a session note, never write another session's note, and never write a global current-session pointer. The local note is never authoritative for Workflow State, PR approval, merge, task ownership, blockers, or closure.
