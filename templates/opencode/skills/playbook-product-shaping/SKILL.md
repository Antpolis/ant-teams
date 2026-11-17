---
name: playbook-product-shaping
description: Use when a promising idea needs a practical MVP, product brief, or implementation-ready scope with success criteria and non-goals; not for a simple request that needs no product shaping.
---

# Product Shaping Playbook

Use this skill to transform a promising idea into something practical enough for technical review or implementation planning.

The user is the founder and final decision maker. Your job is to clarify the outcome, tighten scope, and prepare a clean handoff without inflating the work. Use the available idea, user context, and evidence; if a consequential assumption has not been examined, validate it or identify the gap before treating the direction as settled. Reading this playbook does not start managed delivery or require GitHub artifacts.

Apply `principle-understand-the-outcome` to define the user, outcome, and success; `principle-challenge-and-validate-assumptions` when the case for the idea is uncertain; and `principle-compare-options` when meaningful alternatives need comparison. Use `idea-challenge` when a fuller pressure test is appropriate.

## Procedure

1. Establish the target user, problem, desired outcome, available evidence, and constraints. Ask the owner about consequential product choices that cannot be resolved safely from available evidence.
2. Shape a smallest useful scope and explicit non-goals. Identify material assumptions, risks, and how success or learning can be observed. Adapt the depth to the decision; omit irrelevant fields with a reason rather than inventing facts.
3. Identify open decisions, owners, and which questions block the next planning step. Investigate what can be resolved internally and propose a practical next step for the rest.
4. Review the brief with the founder as needed. Return the agreed direction, unresolved decisions, evidence limits, and next action. A technical handoff is needed when technical planning is the next requested step, not for every ordinary discussion.

## Goals

- define the target user and core problem
- reduce the idea to the smallest useful MVP
- separate must-haves from nice-to-haves
- make success measurable
- clarify constraints, risks, and non-goals
- prepare an implementation-ready brief or spec

## Required Output

Produce:

- target user
- problem statement
- desired outcome
- MVP scope
- non-goals
- assumptions
- risks
- success metric
- rollout or validation notes
- open decisions, each with an owner and whether it blocks planning
- a planning handoff for tech-lead when technical planning is next

## Managed delivery only

When shaping is part of an explicitly active GitHub delivery workflow, keep the working discussion and resolved handoff in the GitHub Discussion, shaping issue, or milestone comment. Create or update the canonical Obsidian `SPEC` only when the direction is stable enough to guide planning; do not create an Obsidian communication record for routine shaping. Before creating a new SPEC, obtain its exact numeric-only ID with `"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" spec-next`; canonical IDs are only `SPEC-###` (zero-padded to at least three digits).

## Scope Rules

- prefer one thin vertical slice over a broad multi-part system
- cut anything that is not required to learn, validate, or deliver value
- if future phases are obvious, label them as follow-up work instead of adding them to MVP
- keep the brief concrete enough that technical review can begin

## When To Escalate

Escalate for more user input when:

- the target user is ambiguous
- success cannot be measured
- the scope includes multiple unrelated bets
- the MVP still depends on unresolved business decisions

## Rules

- optimize for speed to learning and practical delivery
- do not write production code
- do not add speculative scope to make the idea look impressive
- In managed delivery, record resolved scope, tradeoffs, risks, sequencing, and the exact next action in the GitHub Discussion, shaping issue, or milestone comment; do not let them live only in transient chat.
- In managed delivery, mark a SPEC `ready for planning` only when its problem, outcome, goals, non-goals, constraints, acceptance criteria, applicable durable-document links, and open decisions are explicit.
- An open decision blocks planning when it changes the task scope, acceptance criteria, architecture, dependency, security posture, or verification approach; otherwise record why it is non-blocking.
- In managed delivery, hand off a planning-ready SPEC to tech-lead in GitHub with its canonical vault URL, decision status, evidence, and exact next action.

## Verification and recovery

Check that the proposed scope addresses the stated problem, success is observable, and consequential unknowns have an owner and next step. If evidence or a required decision is unavailable, label the uncertainty, describe its impact on planning, and propose a feasible way to resolve it; do not claim the brief is ready or fabricate a metric. Preserve the selected workflow's ownership and approval gates when managed delivery is active.
