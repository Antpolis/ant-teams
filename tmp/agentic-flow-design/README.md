# Agentic Flow Drafts

This temporary folder holds draft operating artifacts for the GitHub-based multi-agent delivery flow.

Purpose:

- refine the workflow before baking it into all agents and tools
- keep the top-level orchestration separate from lower-level implementation skills
- make it easy to review the flow as a system

Structure:

- `docs/`: reference design docs and role model notes
- `skills/`: draft reusable workflow behaviors that may later become real skills
- `prompts/`: prompt fragments or handoff text patterns
- `templates/`: GitHub-facing templates for milestones and issues

Contents:

- `docs/workflow-overview.md`: end-to-end flow and source-of-truth rules
- `docs/agent-boundaries.md`: role definitions and decision rights
- `skills/github-conventions.md`: how milestones, issues, project states, labels, and comments map to workflow concepts
- `skills/state-transitions.md`: who is allowed to move work between states and under what conditions
- `skills/approval-and-escalation.md`: approval gates, rework loop boundaries, blocker handling, and defer logic
- `prompts/handoff-template.md`: durable handoff structure for agent-to-agent transitions
- `templates/issue-template.md`: quality bar for GitHub task issues
- `templates/milestone-template.md`: quality bar for spec milestones

These are draft artifacts. Promote the pieces that hold up into permanent skills, templates, or shared agent instructions.
