# Managed Skill Sync Runbook

Metadata:

| Field | Value |
|---|---|
| ID | RB-001 |
| Type | runbook |
| Domain | global workflow installation |
| Status | active |
| Owner | operator / tech-lead |
| Applies To | `scripts/init-company.sh`, `scripts/sync-managed-skills.sh`, `~/.config/opencode`, `~/.agents/skills/`, `~/.agents/skills/.manifest.json` |
| Keywords | managed sync, two-target install, ~/.config/opencode, ~/.agents/skills, manifest, force, dry-run, collision, command-derived skills, validation |
| Related Docs | SPEC-002, ARCH-004, SPEC-001, ARCH-003, DOCUMENT_INDEX, README.md |
| Last Updated | 2026-08-03 |

## Purpose

Operator-facing runbook for the managed skill sync subsystem introduced in SPEC-002. It describes the two-target install model, what gets synced, the flags, the manifest ownership model, collision and force semantics, rollback, and the validation commands. It is a concise companion to the canonical references `docs/spec/SPEC-002-...md` and `docs/arch/ARCH-004-...md`; it does not redefine them.

## Two-Target Install Model

A single `scripts/init-company.sh` invocation maintains two independent install targets:

| Target | Path | Strategy | Owned by this repo? |
|---|---|---|---|
| Canonical OpenCode | `~/.config/opencode` | Full replace (with provider config merge) | Yes — entire target is repo-owned |
| Managed skill mirror | `~/.agents/skills/` | Non-destructive, manifest-tracked | Only manifest-recorded entries |

- The canonical install behavior is unchanged from pre-SPEC-002. It replaces the whole `~/.config/opencode` directory after merging the existing provider config into a temporary copy.
- The managed sync runs only after the canonical install completes successfully. It is additive and never touches unmanaged content.
- The two targets are independent at the filesystem level; the managed sync never reads from or writes to `~/.config/opencode`.

## What Gets Synced Into `~/.agents/skills/`

The managed mirror is populated with 34 entries: 26 source skill directories plus 8 command-derived skill directories.

### Source skills (26) — full-directory copy

Each directory under `.opencode/skills/<name>/` is copied in full, including `SKILL.md` plus any `scripts/`, `references/`, `assets/`, `evals/`, `agents/`, or `examples/` subdirectories. In-skill `.gitignore` files are excluded.

```
agent-communication-log      founder-escalation-preflight  orchestrator-task-done   security-review
agentic-flow-terms           frontend-design               playwright-cli           skill-creator
approval-or-escalation       github-agentic-delivery-flow  pr-review-flow           state-transitions
development-hygiene          github-conventions            product-shaping          task-completion
do-task                      github-issues-projects-cli    project-initialization   webapp-testing
doc-coauthoring              how-to-create-task            release-management
documentation-standard       idea-challenge                role-memory
```

### Command-derived skills (8) — exact-name transform

Each file `.opencode/commands/<name>.md` is transformed into `~/.agents/skills/<name>/SKILL.md` using the exact command filename as the skill name (no `cmd-` prefix). The generated `SKILL.md` contains:

- frontmatter with exactly `name`, `description` (copied verbatim from the source command), and `disable-model-invocation: true` (in that order)
- the source command body preserved byte-for-byte, including any `$ARGUMENTS` references
- the source `agent` field is dropped
- a trailing newline

```
deliver        fix-bug        migrate        plan-sprint    sprint-clean   sync-spec
do-tasks       new-spec
```

Command-derived `SKILL.md` files are derived artifacts: the authoritative source is always `.opencode/commands/<name>.md`. Never hand-edit the generated files; edit the source command and re-sync.

## Commands

### Standard install (both targets)

```text
scripts/init-company.sh
```

Installs `.opencode/` into `~/.config/opencode` (canonical, full replace), then runs the managed sync into `~/.agents/skills/`. `scripts/init-company.sh` and `scripts/init-company.sh` are aliases and inherit this behavior unchanged.

### Managed sync only (canonical target untouched)

```text
scripts/sync-managed-skills.sh [--force] [--dry-run]
```

Runs only the managed mirror sync. Does not touch `~/.config/opencode`.

## Flags

| Flag | Where accepted | Effect |
|---|---|---|
| `--force` | `init-company.sh`, `sync-managed-skills.sh` | Overwrite locally modified managed entries with current source content. `init-company.sh --force` forwards the flag to the managed sync only; it does not change canonical install behavior. |
| `--dry-run` | `sync-managed-skills.sh` only | Report planned actions prefixed with `[DRY-RUN]` and write nothing. There is intentionally no top-level `init-company.sh --dry-run` in MVP, because the canonical full-replace install has no safe no-write preview. |

`--force` and `--dry-run` may be combined on `sync-managed-skills.sh` to preview what would be force-overwritten.

## Manifest Ownership

The manifest at `~/.agents/skills/.manifest.json` is the sole record of what the sync manages.

- An entry is managed if and only if its name appears in `managed_entries`.
- An entry is unmanaged if its directory exists under `~/.agents/skills/` but its name is not in the manifest — the sync never reads, hashes, modifies, or deletes unmanaged content.
- The manifest is written last and atomically (temp file + rename). It is a record, not an authority: every write target is independently validated to be inside `~/.agents/skills/` regardless of what the manifest says.
- Schema version is `1`. Top-level keys: `version`, `source_repo`, `last_sync`, `managed_entries`. The full schema is defined in SPEC-002 DM-2.

## Modification, Force, And Collision Semantics

For each managed file, the sync compares the current on-disk SHA-256 against the hash recorded in the manifest and decides:

| Situation | Default (`--force` absent) | With `--force` |
|---|---|---|
| Not in manifest (new) | `[INSTALL]` | `[INSTALL]` |
| Current hash == manifest hash, source unchanged | `[NOOP]` | `[NOOP]` |
| Current hash == manifest hash, source changed | `[UPDATE]` | `[UPDATE]` |
| Current hash != manifest hash (locally modified) | `[SKIP modified]` — file preserved, warning to stderr | `[FORCE overwrite]` — replaced from source |
| In manifest but source no longer exists | `[SKIP orphan]` — preserved | `[SKIP orphan]` — preserved |

Collision handling (exact-name rules):

- If a source skill and a command file share a name, the source skill wins; the command-derived entry is skipped with a `[SKIP collision]` warning.
- If a target name is already occupied by unmanaged content (not in the manifest), the entry is skipped with a `[SKIP collision]` warning. The unmanaged entry is never inspected, overwritten, or deleted.
- If a symlink or non-directory appears anywhere along a managed write path, that file is skipped with a `[SKIP collision]` warning (never followed, never used to escape the managed subtree).

Idempotency: re-running with no source or target changes performs no file writes and only updates the manifest `last_sync` timestamp. Every entry reports `[NOOP]`.

Exit codes (same for both scripts; `init-company.sh` reflects the worst outcome):

| Code | Meaning |
|---|---|
| 0 | Success (or dry-run with no structural errors) |
| 1 | Usage error, or a source file was skipped due to an error |
| 2 | Boundary violation (attempted write outside `~/.agents/skills/`) |
| 3 | Source ambiguity (duplicate source names) |
| 4 | Missing dependency (`sha256sum` / `shasum -a 256`, or `node`) |
| 5 | File-system error (permission denied, disk full, etc.) |

## Rollback

There is no automatic rollback in MVP. To remove all managed entries manually:

1. Read `~/.agents/skills/.manifest.json` to see exactly which entry names are managed.
2. Delete the managed directories listed there (e.g. `rm -rf ~/.agents/skills/<name>`).
3. Delete the manifest: `rm ~/.agents/skills/.manifest.json`.
4. Unmanaged sibling content is never affected by this removal.

To revert `init-company.sh` to the pre-SPEC-002 single-target behavior, replace it with the earlier version that does not invoke `sync-managed-skills.sh`; the canonical install behavior was not changed by SPEC-002.

`.manifest.json.corrupt.<timestamp>` files are manual-inspection artifacts produced only when manifest validation fails. The sync moves a corrupt manifest aside, warns, and proceeds as if no manifest exists.

## Scope Cuts (Intentionally Excluded In MVP)

The following are explicitly out of scope and not documented as features:

- Orphan-prune automation (cleanup of stale managed entries is manual, via the manifest).
- Automatic per-file `.bak` rollback files for `--force` overwrites.
- A top-level `scripts/init-company.sh --dry-run` (dry-run stays scoped to `sync-managed-skills.sh`).
- Any broader `~/.agents` content management beyond `~/.agents/skills/`.

## Validation Commands

Run these from the repository root after pulling the latest `master`.

### Managed-sync test suite (SPEC-002-T3)

Runs every `tests/test_sync_*.sh` scenario (unit, integration, e2e, coverage matrix). Each scenario is standalone, uses a temporary `HOME`, and never touches the real `~/.config/opencode` or `~/.agents/skills`.

```text
bash tests/run_sync_tests.sh
```

Equivalent literal invocation:

```text
for f in tests/test_sync_*.sh; do bash "$f" || exit 1; done
```

### Dry-run preview (no writes)

```text
scripts/sync-managed-skills.sh --dry-run
```

Verify nothing was written:

```text
find ~/.agents/skills/ -newer <timestamp-before-run> -not -path '*/.manifest.json'
```

### Idempotent re-run check

Run the managed sync twice with no changes; the second run should report every entry as `[NOOP]` and exit 0:

```text
scripts/sync-managed-skills.sh && scripts/sync-managed-skills.sh
```

### AGENTS.md structural validation

```text
bash scripts/validate-agents-md.sh AGENTS.md
```

### Shell syntax checks

```text
bash -n scripts/*.sh .opencode/skills/project-initialization/scripts/init_project_docs.sh
```

## Related Documents

- SPEC-002 — `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md` (canonical spec, requirements, acceptance criteria)
- ARCH-004 — `docs/arch/ARCH-004-managed-skill-sync-architecture.md` (canonical architecture)
- SPEC-001 — `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`
- ARCH-003 — `docs/arch/ARCH-003-project-local-initialization-artifacts.md`
- README — `README.md`
