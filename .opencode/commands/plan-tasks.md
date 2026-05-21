---
description: Turn an approved spec into GitHub milestone and builder-ready task issues.
agent: tech-lead
---

Turn this approved spec or deliverable into builder-ready execution tasks: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Find the approved spec, related docs, communication log, and any tech-lead or architecture guardrails relevant to this work.
2. Use the github-agentic-delivery-flow skill to confirm the spec is past shaping and should now enter execution setup.
3. Use the how-to-create-task skill to split the spec into scoped GitHub task issues linked to a single GitHub milestone.
4. Use the github-issues-projects-cli skill and repo GitHub config to create or update the milestone, create the task issues, and attach them to the project board.
5. For every issue, include outcome, scope, dependencies, acceptance criteria, verification, and current responsible role.
6. Move executable issues to `Ready`. If a task is not executable yet, leave it `Shaping` or `Blocked` and record exactly why.
7. Ensure at least one non-blocked issue is explicitly builder-ready when the spec is approved to proceed. Do not stop at comments alone.
8. Add a durable handoff note that tells the builder the next issue to pick up and why it is ready.
9. Recommend `do-task <issue>` as the next command once a builder-ready issue exists.

Do not stop after commentary if the spec is approved for execution. The expected outcome is milestone plus concrete GitHub task issues, not just planning notes.
