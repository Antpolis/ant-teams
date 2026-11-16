---
name: founder-escalation-preflight
description: Use when the active workflow coordinator, strategist, or another execution-role agent is about to interrupt the founder with a blocker, escalation, or approval request during delivery work. Run this skill before founder escalation to re-check repository docs, GitHub issue or spec conversation history, relevant role memory, prior handoffs, and safe internal next steps so agents do not escalate early when the answer is already in the repo or can still be resolved internally. Do not use this for normal founder collaboration during spec shaping, planning, or sprint discussion.
---

# Founder Escalation Preflight

These rules apply within an explicitly activated managed delivery workflow. The coordinator is normally Ant Agent (`ant`); each specialist keeps its assigned responsibilities. Loading this skill does not activate a workflow or transfer coordination ownership.

Use this skill immediately before escalating to the founder from orchestrated delivery execution, blocker resolution, or approval flow.

The goal is to prevent avoidable founder interruptions. Treat founder escalation as the last step after repository guidance, GitHub history, memory, and safe internal delegation paths have been re-checked by the active workflow coordinator, strategist, or current execution role.

Do not use this skill to police normal founder collaboration during shaping or planning. Founder participation in spec review, planning, prioritization, and sprint discussion is expected and should stay conversational.

Use the agentic-flow-terms skill as the canonical glossary for workflow terms.
Use github-agentic-delivery-flow for the overall operating model.
Use approval-or-escalation for the approval gate and escalation rules.
Use GitHub Issues, Pull Requests, milestone comments, and Project Workflow State as the operational collaboration record.
Use role-memory only when an existing reusable lesson is relevant before deciding the founder is needed.

## Purpose

Before asking the founder for help, determine whether the answer already exists or whether another safe internal step should happen first.

This is a delivery-execution guardrail, not a planning-session gate.

This preflight should answer:

- Is the blocker really product-level, or is it already answered in repo docs?
- Is the blocker really human-only, or can the coordinator, strategist, tech-lead, builder, or reviewer still act safely?
- Is the current issue/spec history already enough to choose the next step?
- Has relevant role memory been read before escalating?

## Required Preflight Pass

Apply this pass only when the founder is being asked to unblock or approve delivery work.

Before escalating, do all of the following:

1. Read the current task, issue, milestone, PR, or spec that triggered the escalation thought.
2. Read relevant curated project documentation when it may answer the question. When a direct command needs `ANT_TEAM_DOCS_PROJECT_PATH`, source `./.github-project.env` once; centralized helpers load it themselves. Search by topic, feature name, domain terms, file paths, module names, and synonyms; do not rely on document numbers alone.
3. Read the relevant GitHub operational collaboration record:
   - issue comments
   - PR comments or review threads if code exists
   - prior handoffs or blocker notes
4. Read relevant role memory:
   - builder memory before implementation ambiguity escalation
   - reviewer memory before runtime or verification escalation
   - architect memory before architecture, loop-breaker, or repeated-conflict escalation
5. List the safe internal next steps that have already been attempted.
6. Decide whether any safe internal next step still remains.
7. If the active workflow coordinator owns this pass, confirm the active workflow coordinator has no safe remaining role invocation to attempt before escalating.
8. If the strategist is deciding whether founder input is needed, confirm the strategist has narrowed the request to a true product, scope, prioritization, or business decision rather than an answer already recoverable from docs, GitHub history, or another safe internal role.
9. Investigate plausible ways to clear the blocker using available evidence. Check feasibility, constraints, risks, and who controls each option; record sources and distinguish verified facts from assumptions or untested options. Do not claim an option works without evidence.
10. Identify a recommended feasible path and the smallest founder decision, permission, or action it requires. If no option can be verified, say what is unknown and recommend a realistic next investigation or decision rather than inventing a solution.
11. Prepare an unblock plan before escalating: identify the next actionable steps, their owners and dependencies, the expected evidence or condition that clears the blocker, and when to check progress. Include what happens if the preferred path fails or an external party does not respond. If the final resolution is unknown, plan the investigation and its next decision point; do not promise an unverified outcome.
12. Obtain both `tech-lead` and `strategist` input before founder escalation. Give each the blocker, evidence, attempts, constraints, and proposed options. Tech-lead assesses technical resolvability, ownership, feasibility, and workarounds; strategist assesses product impact, scope trade-offs, and whether a founder decision is truly needed. Record their suggestions and reasoning in the GitHub operational record and use them to refine the unblock plan. If either review is unavailable, report the missing review and why; do not claim it occurred or silently bypass an existing gate.

Do not escalate until this pass is complete.

## Safe Internal Next-Step Check

Before founder escalation, actively check whether one of these is still possible:

- return the resolution to the coordinator of the active queue pass
- clarify product meaning through `strategist`
- clarify technical direction through `tech-lead`
- continue implementation through `builder`
- complete review or smoke verification through `reviewer`
- triage or restructure project tasks without changing product direction
- update issue wording, handoff detail, or verification detail from existing repo guidance

If one of these remains safe and plausible, take that step instead of escalating.

For dependencies on external parties, distinguish an action the team can take (such as requesting an upstream change) from an outcome it cannot guarantee. Do not ask the founder to make an independent maintainer release or pin a version. First investigate alternatives under the team's control, such as a local dependency pin, a compatible version, or replacement, where applicable; verify compatibility before recommending one. An external request is an uncertain dependency, not a guaranteed resolution. If no founder decision is needed, report the dependency and the owner and next check instead of presenting it as a founder escalation.

Classify the blocker as resolvable under team control, dependent on an external party, or not yet determined, with supporting evidence. When direct resolution is not under team control or is infeasible, investigate a feasible workaround and its risks, cost, and impact on scope. Do not suggest managing or changing an external repository as an action the team or founder controls unless access and authority are verified. If no workaround is verified, state that and plan the next investigation rather than inventing one.

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
- spec-shaping or sprint discussion
- normal prioritization discussion
- early shaping conversations where gathering more founder context is the point

## Output Format

When preflight says escalation is still needed, report with this structure:

### Founder Escalation Check

- Blocker and impact: <what cannot proceed and the consequence>
- Work completed and attempts: <what was done, results, and evidence links; distinguish failed, untried, and unknown>
- Why this is escalated: <why safe internal paths are exhausted and why the founder specifically must decide or act>
- Options: <each viable option, feasibility evidence or uncertainty, trade-offs, and who controls it; label external dependencies and rejected options>
- Resolvability and specialist input: <classification and evidence; tech-lead and strategist suggestions, reasoning, and links to their GitHub record, or explicitly identify a missing review>
- Recommendation: <preferred realistic option and why; or the next investigation if no option is verified>
- Exact founder decision or action: <a specific, achievable request; include choices when applicable>
- After your decision: <who will do what next and how the blocker will be checked or cleared>
- Unblock plan: <ordered steps and owners; dependencies, progress check, clear exit condition, and fallback or next decision if the preferred path fails>
- Docs checked: <paths or none>
- GitHub history checked: <issue, PR, milestone, or spec references>
- Memory checked: <builder, reviewer, architect, or none>
- Remaining safe internal step: <step or none>

Use plain language and put the actionable summary first. Link supporting evidence in the relevant GitHub operational record and in the founder-facing escalation; explicitly mark unavailable evidence. If escalation is not needed, say what internal step should happen next and who should do it.

## Quality Bar

Good preflight outcomes are:

- specific about what was checked
- explicit about why internal options are exhausted
- explicit that the active workflow coordinator has no safe remaining role invocation to attempt when the active workflow coordinator owns the pass
- explicit that strategist-originated escalation is truly about product, scope, prioritization, or business direction
- narrow about the founder decision requested
- grounded in repo evidence instead of chat memory
- actionable: the founder can see what was done, compare feasible options, and answer a specific decision
- includes an unblock plan with named ownership, an observable exit condition, a progress check, and a fallback even when the solution is not yet known
- honest about uncertainty and external control; no recommendation depends on a third party acting as if that outcome were guaranteed

Bad preflight outcomes are:

- "needs founder input" without naming the exact decision
- escalating after reading only the latest message
- escalating because the queue looks empty
- escalating without checking docs, GitHub history, and memory
