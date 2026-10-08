# Delegation Comment Template

Use this template for a meaningful role boundary, task-level decision, clarification, blocker, or state-changing next action.

- **Issue comment:** strategist ↔ tech-lead planning, tech-lead → builder, task-level clarification, blocker, or escalation.
- **PR description:** builder → reviewer implementation handoff.
- **PR review thread/comment:** reviewer → builder code-specific rework.

Do not paste the full runtime prompt, chat transcript, or full SPEC. Link the authoritative GitHub and Obsidian records instead.

```md
## Delegation — <source> → <target>

**State:** <Workflow State>
**GitHub issue:** <URL>
**PR:** <URL or none>
**Session context:** $ANT_TEAM_DOCS_PROJECT_PATH/session-context/<session_id>.md  (session_id: <session_id>; orchestrator omits this line only when no session note exists)
**Task outcome:** <one sentence>
**Why this role:** <decision or action owned by target>

**Authoritative context:**
- SPEC: <URL or none>
- ARCH / ADR / GOV / runbook: <exact applicable URLs or Not applicable — reason>
- GitHub evidence: <relevant issue comment, PR thread, check, or none>

**Upstream context:** <source role, actionable findings, accepted decisions and rationale, exact handoff link>
**User direction:** <relevant confirmations or corrections, or none>
**Open questions:** <decision, owner, blocking status, or none>
**Constraints / open risk:** <none or specific risk>
**Expected action:** <exact action and owner>
**Expected record:** <issue comment, PR description/review thread, state change, or durable-doc update if required>
```

The direct sub-agent instruction carries the actionable upstream context and user direction as well as issue/PR URLs, scope, expected action, and expected record. Agents do not share history automatically. Follow `github-agentic-delivery-flow/references/context-relay.md`; links alone are not a context relay. During early shaping, identify records not yet created and supply the confirmed brief directly.
