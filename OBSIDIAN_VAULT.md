# Obsidian Vault

This repository does not own project documentation. Its canonical specs, architecture records, runbooks, project-management notes, and role memory live in an Obsidian vault.

Set `OBSIDIAN_VAULT_PATH` to the absolute path of this repository's documentation folder inside that vault. The Git-managed vault for this repository is:

```text
/Users/chrissim/Projects/Docs
```

`DOC_ROOT` remains an explicit per-command override. Both variables refer to the documentation root itself, which contains `DOCUMENT_INDEX.md`, `arch/`, `gov/`, `spec/`, and `proj-management/`.

```bash
export OBSIDIAN_VAULT_PATH="/Users/chrissim/Projects/Docs"
scripts/setup-doc-structure.sh "$OBSIDIAN_VAULT_PATH"
```

Do not add a `docs/` or `.docs/` directory to this repository. Update the vault documents directly and link their vault-relative paths from GitHub issues, milestones, and pull requests.