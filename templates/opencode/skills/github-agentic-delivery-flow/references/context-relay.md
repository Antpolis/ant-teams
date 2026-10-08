# Context Relay Between Agents

Use when a delegated task depends on another agent's work or on decisions made in the parent conversation. This communication procedure does not activate a delivery workflow or authorize a new task. Ant is responsible for relaying the context; siblings must not be assumed to share chat history, filesystems, or runtime memory.

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
3. Send the next agent a self-contained brief with the actionable upstream summary below. Exact record links carry full evidence; they do not replace the summary. Do not send only "review the spec" or "implement issue N".
4. Identify the exact source comment, review thread, document section, or report path. Include a supplied session ID and note path, and verify the child can access local context. If it cannot, inline the relevant excerpt or use an accessible GitHub record; never assume a parent-local path exists in a child runtime.
5. If essential context is missing or conflicting, obtain it from the responsible role or existing record before dispatching dependent work. Do not invent approval or silently resolve an undecided product or architecture choice.

## Runtime brief

Use a few focused bullets for small work; expand only when the dependency requires it:

- **Assignment:** active stage (or ordinary assistance), selected spec/issue scope, target role, requested outcome, and exact action.
- **Upstream result:** source role, what it found, accepted decisions and why, relevant rejected options, and evidence. Identify proposals as proposals.
- **User direction:** relevant constraints, confirmations, and corrections since the upstream brief.
- **Open questions:** unresolved decisions, owners, blocking status, risks, and assumptions the target must validate.
- **Sources:** exact issue/PR and handoff links, applicable durable-context URLs or supplied documents, and accessible session/report pointers. Mark records not yet created as such.
- **Execution and return:** applicable worktree/base/branch/PR, verification expectations, expected output or GitHub record, and who needs the result next.

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

Keep the GitHub handoff and runtime brief consistent. Summarize the minimum context needed for execution; do not paste whole transcripts or documents. A record's existence alone does not prove the next agent received or understood its relevant content.
