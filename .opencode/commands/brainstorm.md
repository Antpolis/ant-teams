---
description: Explore and pressure-test an idea before committing to a spec or task plan.
agent: strategist
---

Brainstorm this idea without committing to implementation yet: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Use the strategist agent to understand the user goal, desired outcome, urgency, constraints, and likely scope.
2. Read the most relevant repository docs and code context only as needed to ground the discussion in reality.
3. Use the product-shaping skill to challenge assumptions, surface tradeoffs, identify MVP scope, and explore alternatives.
4. If the idea appears viable, summarize a recommended direction, open questions, risks, and the smallest practical next step.
5. If the user wants to proceed after brainstorming, recommend the next command explicitly: `create-spec` or `new-spec`.

Do not create implementation tasks or start coding unless the user explicitly shifts from brainstorming into execution planning.
