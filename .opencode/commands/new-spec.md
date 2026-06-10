---
description: Collaboratively shape a new initiative with the founder, pressure-test it with strategist and tech-lead, finalize the spec, and always update GitHub milestone and task state. Tech-lead is the sole owner of the GitHub milestone and all execution issues.
agent: orchestrator
---

Run the full collaborative spec-shaping and GitHub planning flow for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Role ownership — non-negotiable:
- Strategist owns the business sections of the spec and must produce them in enough depth that any future business question can be answered from the spec alone without re-interviewing the founder.
- Tech-lead owns the technical sections of the spec, the GitHub milestone, and every execution issue. No other role creates or modifies milestones or issues in normal flow.
- Orchestrator drives the loop and verifies each gate before the flow advances.

Flow:
1. Orchestrator drives the full shaping loop from start to stop. Do not treat the founder's first prompt as a complete spec.
2. Strategist leads: extract the founder goal, urgency, business value, success metrics, constraints, assumptions, and open questions. Do not proceed to step 3 until strategist can articulate the business problem, business value, and success metrics clearly.
3. Research the most relevant repository docs, code context, existing GitHub milestones, issues, and project history needed to ground the conversation in real repo context. Search by topic, feature name, domain terms, paths, module names, and synonyms. Do not rely on document numbering.
4. Strategist pressure-tests the idea with the founder: challenge assumptions, suggest better variants, cut scope to the smallest viable slice, and surface product tradeoffs, risks, and missing decisions.
5. Tech-lead pressure-tests before the spec is finalized: feasibility, architecture fit, integration points, sequencing, operational burden, technical tradeoffs, and risk. Tech-lead must identify gaps, not rubber-stamp the draft.
6. Any discussion between strategist and tech-lead that changes scope, assumptions, tradeoffs, sequencing, constraints, or the recommended path must be written back as a durable GitHub comment before the flow moves on. Do not leave shaping decisions only in transient chat.
7. Synthesize back to the founder with:
   - problem statement and business value
   - recommended MVP scope and explicit non-goals
   - success metrics
   - notable product and technical tradeoffs
   - key gaps or unanswered questions
   - the suggested implementation direction
8. Get explicit founder confirmation or correction before writing the spec. If material ambiguity remains, keep collaborating. Do not draft prematurely.
9. Strategist writes the business sections of the spec. Tech-lead writes the technical sections. Use `documentation-standard` SPEC type.

   GATE — the spec is not implementation-ready and the flow must not advance to step 10 unless every section below is present and complete:

   Business sections (strategist-owned):
   - Problem statement: what problem this solves, for whom, and why it matters now
   - Business value: measurable or observable outcome for the founder or users if this succeeds
   - Success metrics: specific, observable, time-bounded where possible
   - Goals: what this spec is trying to achieve
   - Non-goals: what is explicitly out of scope and why
   - Stakeholders: who is affected, who must approve, who is the primary user
   - Constraints: time, budget, team size, dependencies, non-negotiable limits

   Technical sections (tech-lead-owned — each must be present or explicitly marked "not applicable" with a reason):
   - Functional requirements: what the system must do, written as specific behavioural statements
   - Technical requirements: performance, scalability, reliability, SLA/SLO targets
   - Data model changes: new or modified tables, fields, indexes, constraints, migrations, seed data
   - API changes: new or modified endpoints, request/response contracts, breaking changes, versioning
   - Security considerations: auth changes, data sensitivity, threat model notes, secrets handling
   - Integration points: external or internal services, queues, webhooks — contract and failure behaviour for each
   - Observability requirements: logging expectations, metrics to emit, alerting thresholds, tracing needs
   - Error handling: user-facing error surfaces, retry or fallback behaviour, failure modes
   - Testing strategy: what must be tested, who writes the tests, coverage expectations
   - Architecture notes: relevant decisions or guardrails from `docs/arch/`; any new ADR or ARCH doc needed
   - Acceptance criteria: conditions that prove the spec is fully delivered; each criterion must later be traceable to at least one issue
   - Rollout and rollback plan: phasing, feature flags, migration steps, rollback procedure, and who is responsible

10. Tech-lead creates the GitHub milestone and all execution issues using the `how-to-create-task` skill.

    GATE — no issue may be moved to `Ready` until all of the following are confirmed:
    - Milestone exists with description using the `how-to-create-task` milestone template
    - Every issue follows the `how-to-create-task` issue template including Why, Tech-Lead Guardrails, Definition of Done, and Sequence Position
    - Tech-lead has worked through the Required Task Types checklist — every type either has an issue or an explicit exclusion recorded in the milestone
    - Documentation and testing/QA tasks exist unless explicitly excluded with written justification
    - Tech-lead has sequenced all issues and recorded the full sequence in the milestone
    - Every spec acceptance criterion is covered by at least one issue
    - Every functional, technical, data model, API, security, observability, and error handling requirement from the spec is addressed by at least one issue
    - Strategist has confirmed the issue set maps to the spec's business value and acceptance criteria

    If any check fails, create the missing issues or record the gap in the milestone before marking anything Ready.

11. Move confirmed executable issues to `Ready`. Leave non-executable work in `Shaping` or `Blocked` with the exact reason recorded in GitHub.
12. Confirm at least one builder-ready issue exists. If not, record why in GitHub and tell the founder exactly what is missing before stopping.
13. Recommend `do-tasks` only after GitHub is updated and at least one builder-ready issue exists.

Expected behavior:
- use `new-spec` as the single founder-facing command for idea shaping, spec finalization, and GitHub task setup
- strategist owns business sections; must be complete enough to answer future business questions without re-interviewing the founder
- tech-lead owns technical sections, the GitHub milestone, and every execution issue — no other role creates or modifies these in normal flow
- the spec quality gate in step 9 and the issue gate in step 10 are hard stops, not suggestions; the flow does not advance past either gate until both are fully satisfied
- founder collaboration is part of the normal flow, not an escalation
- do not write the final spec until gaps, tradeoffs, and a recommended direction have been surfaced back to the founder
- use `documentation-standard` SPEC type for the spec document
- use `how-to-create-task` for all milestone and issue creation

Do not start implementation unless the founder explicitly switches into execution.
