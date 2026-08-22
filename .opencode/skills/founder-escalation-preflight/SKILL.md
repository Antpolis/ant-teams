---
name: founder-escalation-preflight
description: Use when the orchestrator, strategist, or another execution-role agent is about to interrupt the founder with a blocker, escalation, or approval request during delivery work. Run this skill before founder escalation to re-check repository docs, GitHub issue or spec conversation history, relevant role memory, prior handoffs, and safe internal next steps so agents do not escalate early when the answer is already in the repo or can still be resolved internally. Do not use this for normal founder collaboration during spec shaping, planning, or sprint discussion.
---

# Founder Escalation Preflight

Use this skill immediately before escalating to the founder from orchestrated delivery execution, blocker resolution, or approval flow.

The goal is to prevent avoidable founder interruptions. Treat founder escalation as the last step after repository guidance, GitHub history, memory, and safe internal delegation paths have been re-checked by the orchestrator, strategist, or current execution role.

Do not use this skill to police normal founder collaboration during shaping or planning. Founder participation in spec review, planning, prioritization, and sprint discussion is expected and should stay conversational.

Use the agentic-flow-terms skill as the canonical glossary for workflow terms.
Use github-agentic-delivery-flow for the overall operating model.
Use approval-or-escalation for the approval gate and escalation rules.
Use agent-communication-log for Obsidian communication event files and GitHub final-closure expectations.
Use role-memory for project-specific Obsidian memory before deciding the founder is needed.

## Purpose

Before asking the founder for help, determine whether the answer already exists or whether another safe internal step should happen first.

This is a delivery-execution guardrail, not a planning-session gate.

This preflight should answer:

- Is the blocker really product-level, or is it already answered in repo docs?
- Is the blocker really human-only, or can orchestrator, strategist, tech-lead, builder, or reviewer still act safely?
- Is the current issue/spec history already enough to choose the next step?
- Has relevant role memory been read before escalating?

## Required Preflight Pass

Apply this pass only when the founder is being asked to unblock or approve delivery work.

Before escalating, do all of the following:

1. Read the current task, issue, milestone, PR, or spec that triggered the escalation thought.
2. Source `./.github-project.env` (`source ./.github-project.env` — the sole committed project config source) and resolve the central Obsidian project documentation path from `ANT_TEAM_DOCS_PROJECT_PATH`. Search that vault project folder by topic, feature name, domain terms, file paths, module names, and synonyms. Do not rely on document numbers alone.
3. Read the relevant GitHub collaboration record:
   - issue comments
   - PR comments or review threads if code exists
   - prior handoffs or blocker notes
4. Read relevant role memory:
   - builder memory before implementation ambiguity escalation
   - reviewer memory before runtime or verification escalation
   - architect memory before architecture, loop-breaker, or repeated-conflict escalation
5. List the safe internal next steps that have already been attempted.
6. Decide whether any safe internal next step still remains.
7. If the orchestrator owns this pass, confirm the orchestrator has no safe remaining role invocation to attempt before escalating.
8. If the strategist is deciding whether founder input is needed, confirm the strategist has narrowed the request to a true product, scope, prioritization, or business decision rather than an answer already recoverable from docs, GitHub history, or another safe internal role.

Do not escalate until this pass is complete.

## Safe Internal Next-Step Check

Before founder escalation, actively check whether one of these is still possible:

- continue the queue pass through `orchestrator`
- clarify product meaning through `strategist`
- clarify technical direction through `tech-lead`
- continue implementation through `builder`
- complete review or smoke verification through `reviewer`
- triage or restructure project tasks without changing product direction
- update issue wording, handoff detail, or verification detail from existing repo guidance

If one of these remains safe and plausible, take that step instead of escalating.

## What Counts As A Real Founder Escalation

This skill applies to real escalation, not normal planning collaboration.

Escalate only when the remaining blocker truly needs the founder, such as:

- product direction tradeoff
- scope, timeline, and quality conflict
- permission, access, spend, or destructive-action approval
- missing business decision that is not recoverable from docs or GitHub history

Do not escalate for:

- weak repo search
- unread issue or PR history
- missing role-memory review
- discomfort choosing between two technically safe internal steps
- queue emptiness by itself

Do not run this skill for:

- strategist-founder spec exploration
- plan-spec or plan-sprint collaboration
- normal prioritization discussion
- early shaping conversations where gathering more founder context is the point

## Output Format

When preflight says escalation is still needed, report with this structure:

### Founder Escalation Check

- Escalation needed: yes or no
- Why founder is needed: <one short sentence>
- Docs checked: <paths or none>
- GitHub history checked: <issue, PR, milestone, or spec references>
- Memory checked: <builder, reviewer, architect, or none>
- Internal steps attempted: <concise list>
- Remaining safe internal step: <step or none>
- Exact founder decision needed: <smallest decision>

If escalation is not needed, say what internal step should happen next and who should do it.

## Quality Bar

Good preflight outcomes are:

- specific about what was checked
- explicit about why internal options are exhausted
- explicit that the orchestrator has no safe remaining role invocation to attempt when the orchestrator owns the pass
- explicit that strategist-originated escalation is truly about product, scope, prioritization, or business direction
- narrow about the founder decision requested
- grounded in repo evidence instead of chat memory

Bad preflight outcomes are:

- "needs founder input" without naming the exact decision
- escalating after reading only the latest message
- escalating because the queue looks empty
- escalating without checking docs, GitHub history, and memory
