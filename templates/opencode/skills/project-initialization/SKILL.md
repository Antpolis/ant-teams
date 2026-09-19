---
name: project-initialization
description: Establish an evidence-based delivery baseline for an existing repository. Use after init-project configures runtime routing, when agents must inspect the codebase and Git history, document the project and current architecture in the central Obsidian vault, and explain how future agents should navigate the project.
---

# Project Initialization

## Boundary

`$ANT_TEAM_SCRIPTS/init-project.sh` configures the local runtime, `.github-project.env`, helper access, and a generated repository `AGENTS.md`. It does **not** write durable architecture documentation.

Use this skill for the judgment-based documentation pass after initialization. GitHub remains the operational collaboration record; create or update Obsidian notes only for durable project understanding.

## Discovery

Before writing, inspect:

1. README, existing specs, architecture, ADR, and governance notes.
2. Repository structure, manifests, source roots, tests, CI, deployment files, and `.opencode` guidance.
3. Git remote, default branch, recent commits, tags, and existing decisions.
4. `.github-project.env` for the configured `ANT_TEAM_DOCS_PROJECT_PATH`.

Separate observed facts, documented decisions, and unresolved questions. Do not infer an ADR merely from code structure.

## Durable Baseline

Create or update the smallest useful set in `ANT_TEAM_DOCS_PROJECT_PATH` using `references/project-baseline-template.md`:

- `PROJECT_OVERVIEW.md` — purpose, current state, scope boundaries, agent orientation.
- `architecture/ARCH-001-current-system-architecture.md` — components, boundaries, data/control flows, stack, deployment, and known gaps.
- `PROJECT_STRUCTURE.md` — source roots, major modules, tests, scripts, and ownership boundaries.
- `DOCUMENT_INDEX.md` — links to authoritative durable records.

Create an ADR only for a documented or explicitly confirmed decision. Record unknowns as open questions, not decisions.

## Agent Orientation

The project overview must tell future agents:

1. Start from the assigned GitHub issue and its `Durable Context` URLs.
2. Treat linked SPEC, ARCH, ADR, GOV, and runbook notes as durable authority.
3. Use GitHub for handoffs, blockers, review, approval, and task state.
4. Use `$ANT_TEAM_SCRIPTS/gh_project_helper.sh` directly; it loads `.github-project.env` itself.
5. Source `.github-project.env` only when a direct command must expand an `ANT_TEAM_*` variable.

## Writing Rules

- Use the Obsidian frontmatter and wikilinking rules from `documentation-standard`.
- Link every internal relationship with `[[wikilinks]]`.
- Preserve existing durable records; update rather than overwrite them.
- Inspect the vault diff, stage only task-owned files, commit, and push the vault remote after documentation work.
