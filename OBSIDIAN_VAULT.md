# Obsidian Vault

This repository does not own project documentation. Its canonical specs, architecture records, runbooks, project-management notes, agent communication records, and role memory live in the central Obsidian vault.

Resolve the vault and this project's documentation folder by sourcing `./.github-project.env` (the sole committed project config source) and using:

- `ANT_TEAM_DOCS_VAULT_PATH` — the central vault root
- `ANT_TEAM_DOCS_PROJECT_PATH` — this project's folder inside the vault (resolved as `$ANT_TEAM_DOCS_VAULT_PATH/02-Architecture-Landscape/projects/$ANT_TEAM_DOCS_PROJECT_NAME`, or a configured concrete value when set)

Update the vault documents directly and link their vault-relative paths from GitHub issues, milestones, and pull requests.

Repository-local `docs/` in this repo holds code-adjacent guidance only (see AGENTS.md). Do not reintroduce the legacy `OBSIDIAN_VAULT_PATH`/`DOC_ROOT` variables or the retired local-doc scaffolding scripts; project initialization seeds and updates the `ANT_TEAM_DOCS_*` values instead.
