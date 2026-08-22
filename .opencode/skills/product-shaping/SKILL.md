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
- handoff notes for tech-lead or builder

If shaping is happening inside the GitHub delivery workflow, also record the shaping discussion in the central Obsidian communication record (see the agent-communication-log skill) so the next role can continue without chat context.

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
- if strategist and tech-lead discuss scope, tradeoffs, risks, or sequencing in-agent, record the resolved outcome in the central Obsidian communication record and post only the concise final decision to the GitHub milestone or issue when one exists
- do not let meaningful shaping decisions live only in transient chat if the work will continue in the delivery flow
