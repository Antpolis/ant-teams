---
name: agent-communication-log
description: Use when multiple agents collaborate on a spec, GitHub milestone, GitHub issue, pull request, code review, reviewer verification, blocker, defer decision, or review-development loop. Uses the central Obsidian project folder for agent-to-agent communication records, while using GitHub Issues, milestones, Projects, and PRs for status, execution state, and final closing messages.
---

# Agent Communication Log

Use this skill whenever work:

- moves between agents;
- enters the builder-reviewer loop;
- changes scope or sequencing;
- encounters a blocker;
- requires a defer decision;
- approaches escalation;
- reaches completion.

Use `agentic-flow-terms` as the canonical glossary.

## Purpose

Keep detailed agent-to-agent collaboration in the central Obsidian project folder.

Keep GitHub authoritative for:

- issue status;
- milestone status;
- project-board state;
- assignees;
- labels;
- dependencies;
- final decisions;
- closure;
- PR review findings;
- approval evidence;
- merge state.

Do not rely on chat history as the durable workflow record.

## Communication location

Resolve documentation paths by sourcing:

```sh
source ./.github-project.env