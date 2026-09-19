---
name: agent-communication-log
description: Use only for exceptional architecture decisions, blockers, loop-breakers, founder escalations, or other durable collaboration records that cannot be kept in GitHub and project-folder docs. Routine task communication stays in GitHub.
---

# Agent Communication Log

Use this skill only when routine GitHub issue/PR communication and project-folder documentation are insufficient.

## Canonical record boundary

Obsidian stores curated durable knowledge: specs, architecture references, ADRs, governance, runbooks, and exceptional decisions or lessons that remain useful beyond a task. It is not the routine collaboration record.

The Collaboration Record is the GitHub issue, linked pull request, and GitHub Project `Workflow State`. GitHub issue and PR comments carry routine discussion, handoffs, status, blockers, review findings, approvals, and closure.

GitHub Issues and PRs are the active collaboration record for:

- task discussion, ownership, and decisions;
- status, blockers, handoffs, and escalations;
- implementation evidence, review findings, and approval;
- closure, merge state, and workflow state.

The existing project folder is the curated durable knowledge base. Add or consolidate only durable context into its established spec, architecture, ADR, governance, runbook, or memory documentation.

## Exceptional records

Create or update an Obsidian document only when the final result is durable knowledge, such as:

- an architecture conflict or ADR-worthy decision;
- a founder product, priority, budget, security, or risk decision that guides future work;
- a reusable runtime prerequisite, verification method, integration constraint, or recurring failure pattern;
- a change to a spec, runbook, architecture reference, or governance policy;
- a reusable cross-project lesson or accepted tradeoff.

A loop-breaker, founder escalation, or hard blocker remains actionable in GitHub; document it in Obsidian only when its resolved outcome meets this durable-knowledge threshold. Do not create an event file for every delegation, handoff, review loop, ordinary status update, or no-op memory update.

## Location

When a direct documentation command must expand the configured project path, source `./.github-project.env` once in that command or shell session; centralized helpers already load it themselves. Store qualifying durable documentation in the existing project folder using its established naming and template conventions. Do not create a per-task communication-event mirror or Obsidian issue vault.


## Routine GitHub handoff format

Routine handoffs do not create Obsidian event files. Record one concise GitHub issue or PR comment at each meaningful role boundary or state change:

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

Use the issue for task-level ownership, scope, blockers, decision clarifications, and state changes. Use the PR description for the builder-to-reviewer implementation handoff and PR comments/review threads for code-specific review and rework.

Send the target role a direct runtime delegation containing the same essentials—issue/PR URL, task outcome, authoritative context URLs, constraints, exact expected action, and expected GitHub record—but do not copy the complete prompt verbatim into GitHub. The GitHub delegation is the durable collaboration record; the runtime instruction is the concise execution cue.

For the strategist-to-tech-lead planning handoff, record the canonical SPEC URL, whether the SPEC is ready for planning, any open decision with its owner and blocking status, evidence, and the exact next action. For the tech-lead-to-builder handoff, the issue's `Durable Context` section is the canonical documentation handoff; do not duplicate the linked documents in comments.

## Role memory

Role memory is event-triggered, not task-triggered. Add a concise entry only when an event produces a reusable lesson, recurring constraint, or cross-task tradeoff. Do not create `No new durable memory` or other no-op entries; task-local details remain in the Collaboration Record.
