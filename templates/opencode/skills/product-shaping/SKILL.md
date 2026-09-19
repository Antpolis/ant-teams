---
name: product-shaping
description: Use after an idea survives challenge and needs to be turned into a practical MVP, spec, or implementation brief with clear scope, success criteria, and non-goals.
---

# Product Shaping

Use this skill to transform a promising idea into something practical enough for technical review or implementation planning.

The user is the founder and final decision maker. Your job is to clarify the outcome, tighten scope, and prepare a clean handoff without inflating the work.

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
- a planning handoff for tech-lead

When shaping is part of the GitHub delivery workflow, keep the working discussion and resolved handoff in the GitHub Discussion, shaping issue, or milestone comment. Create or update the canonical Obsidian `SPEC` only when the direction is stable enough to guide planning; do not create an Obsidian communication record for routine shaping. Before creating a new SPEC, obtain its exact numeric-only ID with `"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" spec-next`; canonical IDs are only `SPEC-###` (zero-padded to at least three digits).

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
- record resolved scope, tradeoffs, risks, sequencing, and the exact next action in the GitHub Discussion, shaping issue, or milestone comment; do not let them live only in transient chat
- mark a SPEC `ready for planning` only when its problem, outcome, goals, non-goals, constraints, acceptance criteria, applicable durable-document links, and open decisions are explicit
- an open decision blocks planning when it changes the task scope, acceptance criteria, architecture, dependency, security posture, or verification approach; otherwise record why it is non-blocking
- hand off a planning-ready SPEC to tech-lead in GitHub with its canonical vault URL, decision status, evidence, and exact next action
