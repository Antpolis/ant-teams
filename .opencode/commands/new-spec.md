---
description: Create a new technical product or enhancement spec and prepare it for task planning.
agent: strategist
---

Create a new technical product/enhancement spec for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Ask the strategist agent to research repository documents relevant to this request and turn the request plus findings into an implementation-ready spec. Search by topic, feature name, domain terms, paths, module names, and synonyms. Do not rely on document numbering.
2. Ask the strategist agent to review product direction and spec correctness.
3. Ask the tech-lead agent to review technical viability.
4. If approved, create or update the communication log and prepare the spec for architecture review and task planning.
5. Recommend `plan-tasks` as the next command if the spec should proceed into builder-facing execution.

Do not start implementation.
