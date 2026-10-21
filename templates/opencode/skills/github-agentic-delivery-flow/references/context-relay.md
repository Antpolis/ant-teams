# Context Relay Between Agents

Use when a delegated task depends on another agent's work or on decisions made in the parent conversation. This communication procedure does not activate a delivery workflow or authorize a new task. Ant is responsible for relaying the context; siblings must not be assumed to share chat history, filesystems, or runtime memory. It applies to both issue-backed work and ad hoc assistance without a GitHub issue.

## Session context before GitHub artifacts exist

Ant creates or reuses exactly one local session note for the root conversation before the first delegation, including early `new-spec` shaping before any SPEC, milestone, or issue exists. Resolve `ANT_TEAM_DOCS_PROJECT_PATH` from `.github-project.env` and use `$ANT_TEAM_DOCS_PROJECT_PATH/session-context/ctx-<uuid-v4>.md`. Generate a UUID-v4-strength ID, check for a path collision before creation, and retain that exact ID and path throughout the conversation. Do not create a file per handoff or a global current-session pointer.

Keep the note concise and current:

- Founder intent, desired outcome, constraints, and corrections.
- Strategist and tech-lead findings, evidence, and consequential rationale.
- Accepted decisions, proposals, rejected options, and assumptions, clearly distinguished.
- Open questions, their owners and blocking status, plus the next action.
- Exact available draft/spec/source links; mark issues and milestones as not yet created.

Ant records the initial brief, updates the note after meaningful founder corrections and completed agent results, and reconciles changed or conflicting conclusions before the next dependent delegation. Preserve dated history and mark superseded conclusions; never present a proposal as approved. Before a context compaction or session continuation, preserve the latest decisions and next action in this same note, then reread it on resumption.

Every delegation includes the exact session ID and note path plus an actionable summary. Delegates read the note on entry and append only their own dated findings to that same note at meaningful handoff. If the note is inaccessible in a child runtime, Ant supplies the relevant excerpt inline and incorporates the returned findings itself. Do not create a second note as a fallback.

When the spec is approved and GitHub artifacts are created, the responsible roles carry accepted intent, decisions, rationale, and applicable unresolved questions into the canonical SPEC and milestone/issues. Ant verifies that transfer; the local note never grants approval or replaces the GitHub operational record. Keep session notes local-only: never stage, commit, or push them. Archive the note under `session-context/archive/` on root-conversation close; never automatically delete it.

## Before delegating dependent work

1. Wait for the upstream agent's completed response. Read it and the relevant handoff artifacts; verify recorded decisions and evidence instead of forwarding an unchecked status summary.
2. Consolidate the outcome with subsequent user corrections and approved scope changes. Distinguish accepted decisions from proposals, assumptions, and unresolved questions. Preserve the reasoning behind consequential choices and alternatives rejected for a concrete reason.
3. Send the next agent a self-contained, detailed-but-concise brief using the communication type below. Exact record links carry full evidence; they do not replace the actionable summary. Do not send only "review the spec" or "implement issue N".
4. Identify the exact source comment, review thread, document section, report path, or parent-conversation decision. Include a supplied session ID and note path, and verify the child can access local context. If it cannot, inline the relevant excerpt or use an accessible GitHub record; never assume a parent-local path exists in a child runtime.
5. If essential context is missing or conflicting, obtain it from the responsible role or existing record before dispatching dependent work. Do not invent approval or silently resolve an undecided product or architecture choice.

## Runtime delegation templates

Choose the template matching the requested communication. Keep applicable sections and omit irrelevant ones; do not compress away information the receiver needs. The brief is the actual instruction to the child agent, not merely a pointer to GitHub.

### Task or implementation delegation

- **Assignment:** active stage, target role, desired outcome, and exact requested action.
- **Scope and constraints:** approved boundaries, non-goals, guardrails, dependencies, and workspace/branch when applicable.
- **Decision context:** relevant tech-lead, reviewer, strategist, or founder findings; identify the author, decision versus proposal, rationale, and implication. Note superseded guidance.
- **Sources of truth:** issue/PR and direct links to relevant comments or review threads; applicable durable-context links; exact user-request/conversation context for ad hoc work with no issue. Mark unavailable artifacts as not created—do not invent an issue just to delegate.
- **Open questions and risks:** unresolved question, owner, blocking status, and assumptions to validate.
- **Execution and return:** verification expectations, expected output/record, and who needs the result next.

### Review delegation

- **Review target:** exact PR, head/commit, and linked issue if one exists.
- **Review question:** what to assess against scope, acceptance criteria, decisions, guardrails, or requested risk areas.
- **Decision context:** direct links to relevant approval/decision comments and any superseding direction.
- **Evidence and boundaries:** checks already run, known gaps, and what is outside this review.
- **Return:** required finding format, severity/actionability, evidence, and canonical place to record findings.

### Rework or continuation delegation

- **Current state:** task/PR, branch/worktree, exact head, and prior agent's completed work.
- **Required next action:** specific findings or remaining work, with direct links to each source finding.
- **Resolved context:** decisions already made, rationale, user corrections, and superseded guidance.
- **Boundaries and verification:** approved scope, required checks, and what must not be changed.
- **Return:** expected update to the canonical GitHub record when one exists, evidence, remaining risks, and next owner.

For ad hoc work without a GitHub issue, the user's request and relevant parent-conversation decisions are the task context. Include concise excerpts or a session-note pointer that the child can access. Do not claim a GitHub handoff exists; the runtime delegation and returned response carry the coordination unless the work is explicitly moved into managed GitHub delivery. If an issue/PR exists, GitHub remains the operational record and the brief links exact relevant comments/threads rather than duplicating whole discussions.

During early shaping, a SPEC, issue, or milestone may not exist. Relay the founder's brief, confirmed understanding, and strategist's completed findings directly; do not create premature artifacts merely to supply URLs. During managed execution, decisions and approvals remain authoritative in GitHub; a runtime summary or session note does not replace them.

## Role boundaries

| Boundary | Context the coordinator relays |
|---|---|
| Strategist → tech-lead | Founder problem and outcome, confirmed scope/non-goals, success criteria, product constraints, rationale, rejected options, unresolved product decisions, and the current draft or handoff. |
| Tech-lead → strategist | Feasibility findings, concrete constraints, alternatives and tradeoffs, proposed scope changes, and the product decision required. |
| Tech-lead → builder | Approved implementation slice, architecture decisions and rationale, guardrails, dependencies, selected approach, acceptance/verification expectations, exact readiness/handoff record, and provisioned workspace. |
| Builder → reviewer | Change summary, PR/head/branch, acceptance evidence, checks actually run and skipped, deviations, risks, and review focus. |
| Reviewer → builder | Exact actionable findings and thread links, impact and severity, requested corrections, decisions already resolved, and re-verification expectations. |

## Receiving and returning work

Read the runtime brief and the exact cited sources before acting. Briefly state the consequential inherited decisions and open questions in your working response; this demonstrates understanding, not a new user approval gate. If the brief conflicts with a source, report the mismatch to the coordinator before the affected action.

Return an actionable summary: findings, accepted versus proposed decisions, rationale, evidence and artifact links, changes to prior assumptions, unresolved questions, and the exact next action. Keep verification and approval claims tied to evidence. The coordinator relays relevant answers back to the prior role when a clarification changes its work.

For issue-backed work, keep the GitHub handoff and runtime brief consistent. Summarize the context needed for execution; do not paste whole transcripts or documents. For ad hoc work, make the runtime brief self-contained and consistent with the originating request and session context. A record's existence alone does not prove the next agent received or understood its relevant content.
