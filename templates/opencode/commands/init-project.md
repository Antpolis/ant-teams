---
description: Initialize or re-initialize the repository delivery baseline and central documentation routing.
agent: orchestrator
---

Initialize or re-initialize the current repository for agentic delivery work.

**Before running**: discuss with the founder what this repository is for, its conventions, and GitHub project configuration. The initializer writes only safe defaults; all project-specific content comes from founder conversation.

```sh
bash scripts/init-company.sh
source ./.github-project.env
"$ANT_TEAM_SCRIPTS/init-project.sh" --dry-run
```

Run `--dry-run` first to preview. Then run without flags to apply.

Required behavior:
- seed or update `.github-project.env` directly as the sole sourceable `ANT_TEAM_*` configuration; preserve founder-set values
- never invent real-looking remote IDs; leave missing IDs as explicit placeholders until verified
- create a minimal default `AGENTS.md`; skip if one already exists
- do not create a repository-local product documentation tree
- after initialization, show the founder the resolved documentation path (`$ANT_TEAM_DOCS_VAULT_PATH`) and discuss:
  - **AGENTS.md project-specific content**: purpose, conventions, build/test/run commands, relationships
  - **`.github-project.env` confirmation**: walk through owner, project number/ID, Workflow State field/option IDs, worktree root, vault paths; replace placeholders only with founder-verified values
  - **Obsidian initial docs**: with founder direction, create initial spec/arch/gov/product notes from the canonical vault templates — nothing created without explicit founder consent

Re-run is safe and idempotent. Existing `.github-project.env` values are preserved and only missing keys are filled.
