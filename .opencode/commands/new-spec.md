---
description: Collaboratively shape a new initiative with the founder, pressure-test it with strategist and tech-lead, finalize the spec, and always update GitHub milestone and task state.
agent: orchestrator
---

Run the full collaborative spec-shaping and GitHub planning flow for: $ARGUMENTS

Before interpreting workflow metadata terms, use the agentic-flow-terms skill as the canonical glossary for development loop, review loop, loop-breaker, stopper, hard blocker, defer task, communication log, role memory, approval gate, task branch, and production base branch.

Flow:
1. Orchestrator or strategist owns the full shaping loop from start to stop. Do not treat the founder's first prompt as a complete spec.
2. Start by understanding the founder goal, urgency, success criteria, constraints, assumptions, and open questions.
3. Research the most relevant repository docs, code context, existing GitHub milestones, issues, and project history needed to ground the conversation in real repo context. Search by topic, feature name, domain terms, paths, module names, and synonyms. Do not rely on document numbering.
4. Use strategist to pressure-test the idea with the founder: challenge assumptions, suggest better variants, cut scope to the smallest viable slice, and surface product tradeoffs, risks, and missing decisions.
5. Bring in tech-lead before the spec is finalized to pressure-test feasibility, architecture fit, integration points, sequencing, operational burden, and technical tradeoffs. Tech-lead should help uncover gaps, not just rubber-stamp a finished draft.
6. Strategist and tech-lead may discuss in-agent while shaping the spec, but any discussion that changes scope, assumptions, tradeoffs, sequencing, constraints, or the recommended path must be written back as a durable GitHub comment on the milestone or shaping issue before the flow moves on. Do not leave important shaping decisions only in transient chat.
7. Synthesize the discussion back to the founder with:
   - proposed problem framing
   - recommended MVP scope
   - notable product and technical tradeoffs
   - key gaps or unanswered questions
   - the suggested implementation direction
8. Get explicit founder confirmation or correction before finalizing the spec. If material ambiguity remains, keep collaborating instead of drafting prematurely.
9. Once aligned, create or update the implementation-ready spec and any required docs.
10. Always update GitHub as part of this command. Create or update the milestone, milestone summary, scoped execution issues, project status, and durable handoff comments needed for the next role to act.
11. Every created issue must include outcome, scope, dependencies, acceptance criteria, verification, and current responsible role. Move executable issues to `Ready`. Leave non-executable work in `Shaping` or `Blocked` with the exact reason recorded in GitHub.
12. Ensure at least one builder-ready issue exists when the founder approves execution. If no issue is executable yet, clearly record why in GitHub and tell the founder what is missing.
13. Recommend `do-tasks <issue>` only after GitHub has been updated and a concrete builder-ready issue exists.

Expected behavior:
- use `new-spec` as the single founder-facing command for idea shaping, spec finalization, and GitHub task setup
- strategist and tech-lead both participate before the spec hardens
- strategist and tech-lead may reason together in chat, but the durable outcome of that discussion must be posted back to GitHub before execution setup continues
- founder collaboration is part of the normal flow, not an escalation
- do not stop at planning notes or spec prose if GitHub updates can be completed safely in the same run
- do not write the final spec until the command has surfaced gaps, tradeoffs, and a recommended direction back to the founder

Do not start implementation unless the founder explicitly switches into execution.
