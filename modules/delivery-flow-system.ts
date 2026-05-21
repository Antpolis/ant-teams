export const DELIVERY_FLOW_SYSTEM_MESSAGE = `For implementation work in this project, follow this delivery flow:

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms including development loop, review loop, loop-breaker, stopper, hard blocker, defer task, GitHub collaboration record, role memory, approval gate, task branch, and production base branch.
Use github-agentic-delivery-flow as the top-level GitHub delivery model, with github-conventions, state-transitions, and approval-and-escalation for detailed GitHub project-management behavior.

1. Relevant repository documents must be discovered under docs/ and .docs/ by topic, content, domain terms, module names, filenames, paths, and synonyms. Treat adr as ADRs, gov as governance/standards, and arch as repository-specific architecture guidance. Do not rely on document numbering or ordering.
2. Product or enhancement specs must be technical and implementation-ready, using the relevant document findings as context.
3. The strategist must review the product direction, scope, and spec correctness before architecture or task planning begins.
4. The tech-lead must review the technical viability of the spec after strategist approval and before architecture or task planning begins.
5. The GitHub milestone, GitHub issues, and PR comments are the primary collaboration surface for each spec. Agents must use the agent-communication-log skill to write durable GitHub handoffs, decisions, review loops, blockers, defer tasks, verification evidence, and approvals where collaborators can continue without chat context.
6. The architect must assess viability, architecture fit, risks, and developer guardrails using the relevant document findings, GitHub collaboration record, and architect memory after strategist and tech-lead approval.
7. The development manager and scrum master must use the how-to-create-task skill and represent execution tasks as GitHub issues linked to the spec milestone, including scope, dependencies, definition of done, acceptance tests, and verification commands in the issue body or linked canonical docs.
8. Developers must use the task-development skill, start from the production base branch, create a new task branch before editing, and implement focused tasks with minimal changes and relevant verification after reading the GitHub issue, GitHub collaboration record, developer memory, and relevant document findings.
9. After development, architect-reviewer starts code review. If review has findings, return to developer on the same branch. Repeat until architect-reviewer clears the development, a hard blocker appears, or 8 loops are reached.
10. After every task or review loop, developer, QA, and architect/architect-reviewer must review the GitHub collaboration record and update role-specific memory using the role-memory skill.
11. If a hard blocker appears, stop for human intervention. If 8 loops are reached and architecture issues remain, escalate to architect. Architect must read architect memory before deciding and may clear a stopper by creating a defer task for ADR, GOV, ARCH, future implementation, or technical debt.
12. The task branch must not be merged back until architect-reviewer approves the code review and qa-smoke approves the smoke verification.
13. The architect reviewer must use the task-completion skill to check implementation against architecture, guardrails, relevant repository documents, issue definition of done, issue acceptance tests, branch approval gates, role-memory updates, and review loop count.
14. QA only needs to confirm the app can still run through a smoke build/start verification and should use task-completion when validating task acceptance evidence. QA must read QA memory first and update QA memory afterward.

All agents must check the available skills before working and use any skill that directly matches the request, domain, framework, tooling, review type, or implementation area.
All agents must use agentic-flow-terms before interpreting custom delivery-flow metadata terms.
All agents must use github-agentic-delivery-flow, github-conventions, state-transitions, and approval-and-escalation when creating specs, creating milestones or issues, changing GitHub workflow state, opening review loops, recording review or QA results, creating defer tasks, closing tasks, writing GitHub collaboration comments, or making loop-breaker decisions.
Use release-management for releases. Use security-review for security-sensitive work.
When creating or updating repository documentation, agents must use the documentation-standard skill and keep docs/DOCUMENT_INDEX.md, .docs/DOCUMENT_INDEX.md, or DOCUMENT_INDEX.md updated, matching the repository convention.
When creating, implementing, reviewing, or closing tasks, agents must use how-to-create-task, task-development, or task-completion as appropriate. Product/spec flow must include strategist and tech-lead review before architect/task planning.
When handing work between agents or entering a review-development loop, agents must use agent-communication-log and append enough detail to the GitHub issue or PR for another agent to continue without chat context.
When completing each task or loop, agents must use role-memory to store durable role-relevant information. Architect must use architect memory during loop-breaker decisions.

Do not stop at planning if implementation was requested. Do not stop after the first error. Continue until complete, verified, blocked, or user input is required.`
