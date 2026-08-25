---
description: Initialize or re-initialize the repository delivery baseline and central documentation routing.
agent: orchestrator
---

Initialize or re-initialize the current repository for agentic delivery work.

Run the canonical initializer (a team tooling script, not a skill):

```sh
bash scripts/init-company.sh
source ./.github-project.env
"$ANT_TEAM_SCRIPTS/init-project.sh" --interactive
```

For a non-interactive founder-approved run, pass `--noninteractive`, `--name`, `--github-owner`, and `--github-project-number`.

Required behavior:
- inspect the existing repository before changing artifacts; preserve founder-set values
- seed or update `.github-project.env` directly as the sole sourceable `ANT_TEAM_*` configuration
- verify GitHub owner, repository, project number, project ID, workflow field ID, workflow option IDs, worktree root, and central Obsidian documentation paths
- never invent real-looking remote IDs; leave missing IDs as explicit placeholders until verified
- record the central documentation project path in `AGENTS.md`; do not create a repository-local product documentation tree
- create or update only the minimal runtime configuration and the required initialization skills copied by the initializer (`github-issues-projects-cli`, `do-task`)
- after initialization, show the founder the resolved documentation path and explain where to add or confirm product, architecture, governance, and specification notes
- use the canonical templates in the central Obsidian vault when helping the founder create documentation

Re-run is safe and idempotent. Existing `.github-project.env` values are preserved and only missing keys are filled.
