---
description: Run full spec, architecture, planning, development, review, and validation flow.
agent: strategist
---

Run the full delivery workflow for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Ask the strategist agent to research repository documents relevant to this deliverable and produce a technical product/enhancement spec. Search by topic, feature name, domain terms, paths, module names, and synonyms. Do not rely on document numbering.
2. Ask the strategist agent to review the product direction and spec correctness before architecture or task planning begins.
3. Ask the tech-lead agent to review the technical viability of the spec after strategist approval and before architecture or task planning begins.
4. Create or update the spec communication log using the agent-communication-log skill. This log is the durable handoff space for all agents.
5. Ask the tech-lead agent to review viability, architecture fit, risks, and builder guardrails using the relevant docs, spec, communication log, and role memory after strategist approval.
6. Ask the tech-lead agent to use the how-to-create-task skill and create builder-ready GitHub tasks for this spec. The tasks must contain scope, dependencies, definition of done, acceptance tests, and verification commands, and must link to the communication log.
7. Implement tasks with builder agents. Builders must use the task-development skill, start from the production base branch, create a new task branch before editing, and read the task issue, communication log, role memory, strategist findings, tech-lead guardrails, and task-specific referenced docs before editing.
8. After development, run validator review. Validator must read role memory and communication log first. If review has findings, return to builder on the same task branch. Repeat development-review until validator clears the development, a hard blocker appears, or 8 loops are reached.
9. After every task or review loop, builder, validator, strategist, and tech-lead should review the communication log and update role memory using the role-memory skill when relevant.
10. If a hard blocker appears, stop for human intervention with a blocker entry in the communication log. If 8 loops are reached and architecture issues remain, escalate to tech-lead. Tech-lead must read role memory before deciding and may clear a stopper by creating a defer task for ADR, GOV, ARCH, future implementation, or technical debt.
11. Do not merge the task branch back until validator approves the code review and smoke verification outcome is acceptable.
12. Ask the validator agent to verify the app can still run and confirm task acceptance tests or verification evidence where relevant.
13. Fix issues found by review and repeat verification until each task is completed, blocked, deferred by tech-lead, or user input is required.

Do not stop after planning if implementation was requested. Do not stop after the first error. Continue until the requested outcome is implemented and verified or a real blocker is reached.
