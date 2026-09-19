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
**Task outcome:** <one sentence>
**Why this role:** <decision or action owned by target>

**Authoritative context:**
- SPEC: <URL or none>
- ARCH / ADR / GOV / runbook: <exact applicable URLs or Not applicable — reason>
- GitHub evidence: <relevant issue comment, PR thread, check, or none>

**Constraints / open risk:** <none or specific risk>
**Expected action:** <exact action and owner>
**Expected record:** <issue comment, PR description/review thread, state change, or durable-doc update if required>
```

The direct sub-agent instruction should carry the same essentials: issue/PR URL, task outcome, reason for delegation, authoritative context URLs, constraints, expected action, and expected GitHub record.
