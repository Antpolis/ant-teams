---
description: Sync provided local specs and plans into GitHub milestones and task issues, then complete the handoff state.
agent: strategist
---

Sync the provided local specs and plans into GitHub and complete the handoff flow end-to-end for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Read all local spec files, plans, or planning inputs provided in `$ARGUMENTS`.
2. For each spec or plan, sync it into GitHub as the correct execution structure.
3. Confirm the canonical Obsidian SPEC is stable, has a normal URL that GitHub can link to, and lists every open decision with owner and blocking status. Record the strategist-to-tech-lead planning handoff in GitHub.
4. Create or update the GitHub milestone for the spec only when no planning-blocking decision remains open.
5. Create all required GitHub task issues under that milestone.
6. Ensure each task has the correct title, bounded scope, non-goals, dependencies, acceptance criteria, verification, current responsible role, and `Durable Context` with exact URLs to the canonical SPEC and applicable ARCH, ADR, GOV, and runbook notes.
7. Assume issue-to-project linking is automatic in this repository workflow. Do not manually link an issue unless auto-linking failed or the user explicitly asks for manual linking.
8. Update task status on the GitHub Project item itself, using the canonical `Workflow State` field. Do not treat issue body text as the source of task status.
9. If the spec already exists in GitHub, reconcile instead of duplicating.
10. If tasks already exist, fix titles, descriptions, milestone linkage, and project statuses instead of recreating them blindly.
11. Use the repository workflow conventions, GitHub workflow skills, and the GitHub wrapper/scripts where applicable. Invoke centralized helpers directly because they load `.github-project.env` themselves. Source the env once only when a direct command must expand an `ANT_TEAM_*` value.
12. Use tech-lead only when technical details, sequencing, or guardrails need to be added or corrected.
13. Use strategist review for product-facing corrections to spec wording or task meaning.
14. Continue until every provided spec or plan has been fully synced into GitHub and its task set is in a handoff-ready state.

Rules:
- This is a handoff process, not just a documentation pass.
- Do not stop at comments or recommendations alone.
- Set a task to `Ready` only when it has all builder-ready fields and exact Durable Context URLs, and no unresolved decision blocks scope, acceptance criteria, architecture, dependency, security, or verification.
- If a task is not ready, set its `Workflow State` to `Backlog`, `Need attentions`, or `Blocked` as appropriate, and record the actionable reason in a GitHub issue comment. Update Obsidian only when the outcome changes durable product, architecture, governance, or runbook knowledge.
- `Workflow State` must be updated on the GitHub Project item, not only described in the issue body.
- If milestone, issue, or board data is missing, use repo GitHub config and workflow tools to infer or create the right structure.
- Do not start implementation.

Required outcome for each provided spec or plan:
1. GitHub milestone exists and is correctly titled.
2. All related task issues exist with proper titles and descriptions.
3. Each issue is linked to the milestone.
4. Each task has the correct `Workflow State` set on the GitHub Project board.
5. At least one next actionable handoff is explicit where execution can proceed.
6. A summary is provided showing:
   - spec or plan synced
   - milestone created or updated
   - tasks created or updated
   - `Workflow State` values updated
   - blockers or backlog items if any
   - next recommended command, usually `plan-sprint` or `do-tasks <issue>`
