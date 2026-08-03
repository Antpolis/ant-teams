# Managed Global Skill Sync And Command-Derived Skills

Metadata:

| Field | Value |
|---|---|
| ID | SPEC-002 |
| Type | spec |
| Domain | global workflow installation |
| Status | active |
| Owner | strategist, tech-lead |
| Applies To | `scripts/sync-company.sh`, `scripts/init-company.sh`, `scripts/update-company.sh`, `scripts/sync-managed-skills.sh`, source `.opencode/commands/`, source `.opencode/skills/`, managed install target `~/.agents/skills`, managed manifest `~/.agents/skills/.manifest.json`, canonical OpenCode target `~/.config/opencode` |
| Keywords | sync-company, ~/.config/opencode, ~/.agents/skills, managed sync, command-derived skills, SKILL.md transform, manifest ownership, idempotent install, dry-run, local modifications, force overwrite, manual cleanup |
| Related Docs | SPEC-001, ARCH-003, ARCH-004, GOV-002, `README.md`, `.opencode/opencode.json` |
| Supersedes |  |
| Last Updated | 2026-08-01 |

## Summary

This spec defines a separate follow-on to SPEC-001: keep `~/.config/opencode` as the canonical OpenCode install target, and add a non-destructive managed sync into `~/.agents/skills` so external agent runtimes can consume the same source skills and command-derived skills without copying or mutating unrelated local user content. The MVP is intentionally narrow: sync only what this repository owns, track ownership with a manifest, preserve locally modified managed entries unless `--force` is explicitly used, transform every source command file at `.opencode/commands/<name>.md` into `~/.agents/skills/<name>/SKILL.md` using the exact command name, and keep all generated outputs derived and reproducible.

## Problem Statement

The weakest assumption is that "dual-home install" is automatically useful just because two agent ecosystems exist. It may fail if it creates two drifting truths, overwrites local user customizations, or turns one simple sync command into a destructive migration tool. If the workflow starts touching unmanaged `~/.agents` content, the feature becomes risky faster than it becomes valuable.

So the real problem is narrower: the repository needs one safe sync path that continues to install canonical OpenCode config to `~/.config/opencode` while also exporting repository-owned skills into `~/.agents/skills` for agent consumers that expect that directory. That export must be predictably managed, reversible, and obviously non-destructive, or operators will stop trusting the installer.

This matters now because the founder has confirmed the follow-on direction and has already ruled out the two highest-risk shortcuts: fake command aliases (`cmd-do-tasks`) and destructive overwrite of locally modified managed entries. The spec therefore needs to lock the product intent before technical design starts expanding it.

## Business Value

If this works, one sync command maintains the founder's canonical OpenCode setup and a compatible agent-skill mirror without making operators babysit two separate installs. The practical value is not "more files copied." The value is lower setup friction, lower drift between supported command/skill surfaces, and lower fear that an update will wipe out local work.

The founder gains three concrete outcomes:

1. A single supported source of truth for company workflow assets, even when they must be installed into two homes.
2. Safer upgrades because managed entries with local edits are preserved by default and surfaced with warnings instead of being silently replaced.
3. Better interoperability because every source command becomes a skill-shaped artifact that agent runtimes can read directly without inventing a second naming scheme.

## Success Metrics

This spec is only successful if operators can trust the sync behavior. The MVP is successful when all of the following are true:

1. **Canonical target preserved:** A standard sync still installs OpenCode config to `~/.config/opencode`, and no feature in this spec changes that canonical target.
2. **Managed `~/.agents` sync works:** A standard sync installs repository-owned source skills plus command-derived skills under `~/.agents/skills` without touching unmanaged sibling content.
3. **Modification safety:** If a managed entry in `~/.agents/skills` has been locally modified, the default sync preserves it and emits a warning; overwrite happens only when `--force` is explicitly used.
4. **Command transform correctness:** Every `.opencode/commands/<name>.md` source file produces `~/.agents/skills/<name>/SKILL.md` using the exact command name, with body content and `$ARGUMENTS` preserved and `disable-model-invocation: true` set.
5. **Derived-output determinism:** Re-running the managed sync with unchanged inputs produces no material changes except the manifest timestamp explicitly defined by tech-lead; `scripts/sync-managed-skills.sh --dry-run` reports planned actions without writing files.
6. **Trust boundary preserved:** Unmanaged content already present under `~/.agents` is never deleted, renamed, or modified by the managed sync path.

## Goals

- Keep `~/.config/opencode` as the canonical OpenCode installation target.
- Add a managed, non-destructive sync path for repository-owned skills into `~/.agents/skills`.
- Install all source skill directories, including scripts and reference/support files required for those skills to remain usable.
- Transform every `.opencode/commands/<name>.md` into `~/.agents/skills/<name>/SKILL.md` using the exact command name, not a prefixed alias.
- Mark command-derived skill outputs with `disable-model-invocation: true` while preserving the command body and `$ARGUMENTS` semantics.
- Treat generated command-derived outputs as derived artifacts rather than hand-edited canonical sources.
- Use manifest-based ownership so the sync knows what it manages and what it must not touch.
- Ensure idempotent default runs and a clear `--dry-run` mode before any implementation starts.

## Non-Goals

- Re-opening or extending completed SPEC-001 scope.
- Changing project-local initialization behavior or `init-project` artifact contracts.
- Making `~/.agents` the canonical home for OpenCode config.
- Managing, cleaning, or normalizing arbitrary unmanaged files anywhere under `~/.agents`.
- Inventing alternative command-skill names such as `cmd-<name>`.
- Adding behavior that silently overwrites locally modified managed entries.
- Designing a general plugin/package manager for all possible agent ecosystems.
- Creating GitHub milestones, issues, or project-board artifacts as part of this shaping pass.
- Adding orphan-prune automation or automatic backup-file management in MVP; operators can clean up managed entries manually from the manifest if needed.

## Stakeholders

- **Founder (decision maker):** has confirmed the product direction and the non-destructive safety rules.
- **Repository operator (primary user):** runs the sync command and needs a predictable update that does not damage local customizations.
- **Agent runtime consumers of `~/.agents/skills`:** need skill directories and command-derived `SKILL.md` files in the expected location.
- **OpenCode users of `~/.config/opencode`:** still depend on the current install target staying canonical and stable.
- **Future maintainers of sync/install tooling:** need a narrow MVP with explicit ownership boundaries instead of ambiguous installer behavior.

## Constraints

- The OpenCode target remains `~/.config/opencode`; this is non-negotiable for MVP.
- The managed sync must be additive and non-destructive by default.
- Locally modified managed entries are preserved with warning unless `--force` is provided.
- Unmanaged content under `~/.agents` is never touched.
- Command-derived skills must use the exact command filename as the installed skill name.
- Generated outputs are derived and must not become a second hand-maintained source tree.
- Ownership tracking must be manifest-based, not inferred from guesswork alone.
- The spec must stay separate from SPEC-001 and small enough for current-sprint delivery.

## Context

Today `scripts/sync-company.sh` replaces the target OpenCode directory wholesale after merging provider config into a temporary copy. That is acceptable for a single canonical target owned entirely by this repository, but it is the wrong default for `~/.agents`, where operators may already have unrelated local content. The founder has already made the core product decisions needed to keep the follow-on safe:

- command-derived skills use the exact command name (`do-tasks`, not `cmd-do-tasks`)
- locally modified managed entries are preserved with warning unless `--force`
- canonical OpenCode target stays `~/.config/opencode`
- managed sync is added to `~/.agents/skills`, not as a replacement for the canonical OpenCode install
- all source skill directories are installed with their scripts and references/supporting files
- every source command file becomes a derived `SKILL.md` with `disable-model-invocation: true`
- unmanaged `~/.agents` content is never touched
- manifest ownership plus idempotent and dry-run behavior are required

The remaining work is not another product debate. It is technical translation of these locked product constraints into an implementation plan that stays narrow.

## Founder-Confirmed Product Decisions

1. **Naming rule:** command-derived skills use the exact command name from `.opencode/commands/<name>.md`.
2. **Safety rule:** locally modified managed entries are preserved with warning by default; overwrite requires `--force`.
3. **Canonical-home rule:** `~/.config/opencode` remains the canonical OpenCode install target.
4. **Managed mirror rule:** add non-destructive managed sync to `~/.agents/skills`.
5. **Completeness rule:** install all source skill directories, including scripts and references/support files.
6. **Transform rule:** generate `~/.agents/skills/<name>/SKILL.md` from every command file, preserve body and `$ARGUMENTS`, and set `disable-model-invocation: true`.
7. **Ownership rule:** generated outputs are derived; use manifest ownership for managed install decisions.
8. **Boundary rule:** unmanaged `~/.agents` content is never touched.
9. **Operability rule:** behavior must be idempotent and support dry-run.

## Better Practical Variant And Scope Cuts

The risky version of this idea is "sync all of `~/.agents`." That should be rejected. The smallest viable variant is narrower and should remain the spec baseline:

- manage only `~/.agents/skills`
- manage only repository-owned entries recorded in a manifest
- preserve modified managed entries by default instead of trying to auto-merge them
- derive command-skills from source commands on each sync instead of adding a second editable source tree
- defer any broader `~/.agents` config sync, cleanup outside managed ownership, prune automation, backup-file management, or multi-target abstraction layer until this smaller slice proves safe

## Decisions

- This follow-on remains a separate spec from SPEC-001.
- Product success is trust and predictability, not maximum file-copy coverage.
- Safety defaults beat convenience shortcuts: preserve modified managed entries unless `--force`.
- Exact-name command transforms beat alias schemes because they keep user-facing command vocabulary consistent across surfaces.
- Derived outputs must remain reproducible from source, not become another manually maintained asset family.

## Guardrails

- Do not broaden scope beyond `~/.config/opencode` plus managed `~/.agents/skills` in MVP.
- Do not approve any implementation that mutates unmanaged `~/.agents` content.
- Do not approve any implementation that silently overwrites locally modified managed entries.
- Do not introduce prefixed command-derived skill names.
- Do not let technical sequencing re-open the founder-confirmed product decisions above.
- If a simpler MVP is needed, cut optional polish before cutting the safety model.

## Functional Requirements

These requirements translate the founder-confirmed product decisions into testable, sequential behavior. Every `FR-` requirement must be independently verifiable.

### FR-1 — Canonical OpenCode Install

**FR-1.1** A default run of `sync-company.sh` or `init-company.sh` must install the repository `.opencode/` directory contents into `~/.config/opencode` using the existing full-replace-with-provider-merge strategy already implemented in `sync-company.sh`.

**FR-1.2** No code path in the managed sync feature may alter, bypass, or weaken the canonical OpenCode install behavior defined in FR-1.1.

**FR-1.3** The canonical install target path must remain `~/.config/opencode` (overridable only via the existing `--target-dir` flag on `sync-company.sh`).

### FR-2 — Managed Skill Directory Sync To `~/.agents/skills`

**FR-2.1** After the canonical install completes, the sync must perform a managed, non-destructive sync of repository-owned skills into `~/.agents/skills`.

**FR-2.2** Managed sync must install two categories of entries:
  a. **Source skills:** every directory under `.opencode/skills/<name>/` copied in full to `~/.agents/skills/<name>/`, including all subdirectories (scripts, references, assets, evals, agents, examples) and all files within them.
  b. **Command-derived skills:** for every file `.opencode/commands/<name>.md`, a generated `~/.agents/skills/<name>/SKILL.md` containing the transformed frontmatter and preserved body content (see FR-4 for transformation rules).

**FR-2.3** Managed sync must not create, modify, or delete any file or directory under `~/.agents/skills/` that is not recorded in the manifest as a managed entry.

**FR-2.4** Managed sync must not create, modify, or delete any file or directory outside `~/.agents/skills/`.

### FR-3 — Manifest Ownership

**FR-3.1** Managed sync must read from and write to a manifest file at `~/.agents/skills/.manifest.json`.

**FR-3.2** The manifest must record, for each managed entry, the entry name, type (`source_skill` or `command_derived`), source repository-relative path, and install-time content hashes for every installed file.

**FR-3.3** Before any write to `~/.agents/skills/`, the sync must validate that the target directory or file is either a) absent, b) already recorded in the manifest as a managed entry, or c) explicitly being written as a new managed entry. Writes to paths not meeting these conditions must be rejected (see FR-7 on boundary enforcement).

**FR-3.4** The manifest schema is defined in the Data Model Changes section of this spec and must be the canonical reference for all implementation.

### FR-4 — Command-To-SKILL.md Transformation

**FR-4.1** For each source file `.opencode/commands/<name>.md`, the sync must generate `~/.agents/skills/<name>/SKILL.md` with:
  a. YAML frontmatter delimited by `---` containing exactly these fields in this order: `name` (set to the command filename without `.md`, e.g., `do-tasks`), `description` (copied verbatim from the source command frontmatter `description` field), `disable-model-invocation` (set to `true`).
  b. A blank line after the closing `---`.
  c. The body content of the source command file, preserved byte-for-byte starting from the first non-frontmatter line.
  d. A trailing newline.

**FR-4.2** The source command frontmatter field `agent` must be dropped; it must not appear in the generated SKILL.md.

**FR-4.3** Any `$ARGUMENTS` reference in the command body must be preserved exactly as written in the source; the sync must not expand, interpret, or replace `$ARGUMENTS`.

**FR-4.4** Generated SKILL.md files are derived artifacts. The sync must not read them back as input for any future decision. The authoritative source is always `.opencode/commands/<name>.md`.

### FR-5 — Modified-Entry Detection

**FR-5.1** A managed file under `~/.agents/skills/` is considered locally modified when its current SHA-256 content hash differs from the hash recorded in the manifest for that file.

**FR-5.2** For command-derived SKILL.md files, the sync must additionally compute a source-predicted hash (the SHA-256 of what the file would contain if regenerated from current source). A command-derived file is considered locally modified when its current hash differs from the manifest hash, regardless of whether the source has also changed. When both manifest hash and current hash match but differ from source-predicted hash, the entry is an unmodified stale entry eligible for normal update.

**FR-5.3** For source skill files, modification detection uses only the current hash vs. manifest hash comparison. No source-predicted hash is needed because source skills are direct copies, not generated.

### FR-6 — Default Behavior With Modification Warnings

**FR-6.1** On a default run (no `--force`), the sync must:
  a. Install new managed entries (absent from manifest) without warning.
  b. Update unchanged managed entries (current hash matches manifest hash) without warning.
  c. Skip locally modified managed entries and emit a `WARNING:` line to stderr for each, stating the path and that it was preserved. The skip must not leave the entry in a partially-modified state.
  d. Skip stale managed orphan entries (present in manifest but source no longer exists) and emit a `WARNING:` line to stderr for each.

**FR-6.2** A default run must return exit code 0 when it completes successfully, even when modifications were skipped with warnings.

**FR-6.3** The set of skipped entries and their reasons must be summarized at the end of the output.

### FR-7 — Boundary Enforcement

**FR-7.1** Before creating or modifying any path under `~/.agents/skills/`, the sync must confirm one of:
  a. The exact path is already in the manifest as a managed entry.
  b. The exact path is not yet in the manifest and corresponds to a current source file or directory being installed for the first time.
  c. The exact path is already in the manifest and corresponds to a current managed source entry being updated.

**FR-7.2** Any write attempt to a path that fails all three checks must be treated as a fatal error; the sync must stop with exit code 2 and must not have written to that path.

**FR-7.3** Unmanaged content in `~/.agents/skills/` (i.e., directories or files not recorded in the manifest) must not be read by the sync for any purpose other than confirming the path is absent before a new install. Content of unmanaged files must never be inspected, hashed, or compared.

### FR-8 — `--force` Behavior

**FR-8.1** When `--force` is supplied, locally modified managed entries must be overwritten with current source content instead of being skipped. A `FORCE:` notice must be emitted to stderr for each overwritten entry.

**FR-8.2** `--force` is an explicit operator opt-in. MVP force overwrite does not need to create automatic per-file rollback backups; its only required behavior is replacing the locally modified managed entry with current source content.

**FR-8.3** `--force` must not cause unmanaged content to be touched or orphaned managed entries to be removed.

**FR-8.4** After a force overwrite, the manifest must be updated to reflect the new content hashes.

### FR-9 — `--dry-run` Behavior

**FR-9.1** When `--dry-run` is supplied, the sync must compute all planned actions and report them to stdout without writing any file to disk.

**FR-9.2** Dry-run output must categorize each planned action as one of: `[INSTALL]`, `[UPDATE]`, `[SKIP modified]`, `[SKIP orphan]`, `[FORCE overwrite]`, `[SKIP collision]`, or `[NOOP]`.

**FR-9.3** Dry-run must not create or modify the manifest file or any file under `~/.agents/skills/`. Temporary files created for hash computation must be cleaned up.

**FR-9.4** Dry-run must exit with code 0 when no errors are detected, or exit with the same error code that a real run would produce for structural errors (missing source, permission denied, etc.).

### FR-10 — Idempotency

**FR-10.1** Running the sync twice with no intervening source or target changes must produce no file writes on the second run beyond updating the manifest timestamp.

**FR-10.2** For command-derived skills, re-running the sync with unchanged source commands must produce bit-identical SKILL.md output to the previous install, excluding only the manifest `last_sync` timestamp.

### FR-11 — Exact-Name Collision Resolution

**FR-11.1** When a source skill directory and a command-derived skill would produce the same target directory name (e.g., if `.opencode/skills/do-tasks/` and `.opencode/commands/do-tasks.md` both exist — a hypothetical collision), the source skill must take precedence and the command-derived skill must be skipped with a `WARNING:`.

**FR-11.2** When two source skills share the same name, the sync must treat this as a fatal error (source ambiguity) and exit with code 3.

**FR-11.3** When two command files share the same name after normalization (impossible in a single filesystem directory, but included for robustness), the sync must treat this as a fatal error (source ambiguity) and exit with code 3.

**FR-11.4** If a target entry name already exists under `~/.agents/skills/` as unmanaged content, the sync must skip that entry with a `WARNING:` and continue. It must not overwrite, delete, or inspect the unmanaged entry contents.

### FR-12 — Script Entry-Point Behavior

**FR-12.1** `scripts/sync-managed-skills.sh` must be the single implementation owner of FR-2 through FR-11. It must accept `--force` and `--dry-run` flags.

**FR-12.2** `scripts/sync-company.sh` must invoke `scripts/sync-managed-skills.sh` after completing the canonical install in FR-1, passing through `--force` when supplied. The sync-company exit code must reflect the worst outcome: if the canonical install succeeds but managed sync fails, exit with the managed sync failure code.

**FR-12.3** `scripts/init-company.sh` and `scripts/update-company.sh` must continue delegating to `sync-company.sh` without modification, inheriting all new behavior through that delegation.

## Technical Requirements

### TR-1 — Runtime Environment

**TR-1.1** The managed sync script must run on any POSIX-compatible system with `bash` 4.0+, GNU coreutils (or compatible `cp`, `mkdir`, `rm`, `mktemp`, `sha256sum`), and no additional language runtimes beyond those already required by the repository.

**TR-1.2** The script must detect missing `sha256sum` at startup and exit with code 4 and a clear error message if unavailable. A fallback to `shasum -a 256` (macOS) must be supported.

**TR-1.3** The script must expand `~` to the current user's home directory using `$HOME` (POSIX-compatible) and must not rely on shell tilde expansion within quoted strings.

### TR-2 — Portability

**TR-2.1** The managed sync must produce identical output on Linux (GNU userland) and macOS (BSD userland) for the same source and target state.

**TR-2.2** File paths must use forward-slash separators and be compared as byte strings after resolving `$HOME`.

**TR-2.3** The script must not depend on GNU-specific `cp` flags (`--parents`, `--preserve=`) or `sed` extensions. Use POSIX-compatible alternatives or a documented minimum toolchain.

### TR-3 — Performance

**TR-3.1** For the current repository scale (26 source skills, 8 command files, ~70 total files), a no-op dry-run must complete in under 1 second on modern hardware.

**TR-3.2** A full managed sync (all entries new) must complete in under 5 seconds on modern hardware, excluding the canonical OpenCode install time.

**TR-3.3** SHA-256 hash computation must be done per-file, not by reading entire directories into memory.

### TR-4 — Deterministic Regeneration

**TR-4.1** Command-derived SKILL.md output must be bit-deterministic given the same source command file content: same YAML frontmatter field order, same line endings, same trailing newline.

**TR-4.2** Source skill file copies must preserve original file permissions (read/write for owner, read for group/other — mode 0644 for files, 0755 for directories and executables).

**TR-4.3** The manifest `last_sync` timestamp is the only field allowed to differ between two idempotent runs with unchanged inputs.

### TR-5 — Failure Atomicity

**TR-5.1** If the managed sync fails partway through (e.g., disk full, permission denied), the target state must not be left with a half-written manifest. The manifest update must be the last write operation, performed atomically via write-to-temp-then-rename.

**TR-5.2** Individual file installations may complete before the manifest is updated. If the sync fails after file writes but before manifest commit, a subsequent re-run must detect the drift (current files with no manifest record) and treat the files as new managed entries to be verified or overwritten from source.

## Data Model Changes

### DM-1 — Manifest File Location

**DM-1.1** The ownership manifest resides at `~/.agents/skills/.manifest.json`.

**DM-1.2** The manifest is a managed artifact itself: if the manifest is missing on a managed sync run, the sync treats all existing `~/.agents/skills/` content as unmanaged (never touched) and installs all current source entries as new managed entries, writing a fresh manifest.

### DM-2 — Manifest Schema

**DM-2.1** The manifest must conform to the following JSON schema:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["version", "managed_entries", "last_sync"],
  "properties": {
    "version": {
      "type": "integer",
      "const": 1,
      "description": "Schema version for forward-compatibility."
    },
    "source_repo": {
      "type": "string",
      "description": "Absolute path to the repository root at time of last sync. Informational only; not used for path validation."
    },
    "last_sync": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp of the last successful sync completion."
    },
    "managed_entries": {
      "type": "object",
      "description": "Map of managed entry names to their metadata.",
      "additionalProperties": {
        "type": "object",
        "required": ["type", "source_path", "installed_at", "files"],
        "properties": {
          "type": {
            "type": "string",
            "enum": ["source_skill", "command_derived"],
            "description": "Whether the entry is a direct copy of a source skill directory or a generated skill from a command file."
          },
          "source_path": {
            "type": "string",
            "description": "Repository-relative path to the source. For source_skill: '.opencode/skills/<name>/'. For command_derived: '.opencode/commands/<name>.md'."
          },
          "installed_at": {
            "type": "string",
            "format": "date-time",
            "description": "ISO 8601 timestamp of when this entry was last installed or updated."
          },
          "files": {
            "type": "object",
            "description": "Map of repository-relative source file paths to their install metadata.",
            "additionalProperties": {
              "type": "object",
              "required": ["hash", "target_path"],
              "properties": {
                "hash": {
                  "type": "string",
                  "pattern": "^[a-f0-9]{64}$",
                  "description": "SHA-256 hash of the installed file content at install time."
                },
                "target_path": {
                  "type": "string",
                  "description": "Absolute path under ~/.agents/skills/ where this file was installed."
                }
              }
            }
          }
        }
      }
    }
  }
}
```

**DM-2.2** Example manifest entry for a source skill:

```json
{
  "agent-communication-log": {
    "type": "source_skill",
    "source_path": ".opencode/skills/agent-communication-log/",
    "installed_at": "2026-08-01T12:00:00Z",
    "files": {
      ".opencode/skills/agent-communication-log/SKILL.md": {
        "hash": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
        "target_path": "/home/user/.agents/skills/agent-communication-log/SKILL.md"
      }
    }
  }
}
```

**DM-2.3** Example manifest entry for a command-derived skill:

```json
{
  "do-tasks": {
    "type": "command_derived",
    "source_path": ".opencode/commands/do-tasks.md",
    "installed_at": "2026-08-01T12:00:00Z",
    "files": {
      ".opencode/commands/do-tasks.md": {
        "hash": "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3",
        "target_path": "/home/user/.agents/skills/do-tasks/SKILL.md"
      }
    }
  }
}
```

### DM-3 — Source-To-Target Path Mapping

**DM-3.1** For `source_skill` entries, each file at `.opencode/skills/<name>/<subpath>` maps to `~/.agents/skills/<name>/<subpath>`.

**DM-3.2** For `command_derived` entries, the source file `.opencode/commands/<name>.md` maps to `~/.agents/skills/<name>/SKILL.md`.

**DM-3.3** The directory `~/.agents/skills/<name>/` for command-derived entries contains only `SKILL.md`. No other files or subdirectories are created for command-derived entries.

### DM-4 — Manifest Integrity

**DM-4.1** The manifest file is written atomically: the sync writes to a temporary file in the same directory, then renames it over the target manifest. This prevents partial writes from corrupting the manifest.

**DM-4.2** Before reading a manifest, the sync must validate that it is syntactically valid JSON and contains the required top-level keys `version` and `managed_entries`. An invalid manifest must be treated as a recoverable condition: the sync emits a warning, moves the corrupt manifest to `.manifest.json.corrupt.<timestamp>`, and proceeds as if no manifest exists (treating all existing content as unmanaged).

**DM-4.3** No automatic `.manifest.json.bak` file is required in MVP. Manifest recovery relies on atomic writes plus `.manifest.json.corrupt.<timestamp>` preservation only when validation fails.

## API Changes

### CLI-1 — New Script: `scripts/sync-managed-skills.sh`

**CLI-1.1** A new script `scripts/sync-managed-skills.sh` is the single implementation owner for the managed `~/.agents/skills` sync behavior (FR-2 through FR-11).

**CLI-1.2** Usage:

```
Usage:
  scripts/sync-managed-skills.sh [--force] [--dry-run]

Flags:
  --force       Overwrite locally modified managed entries instead of preserving them.
  --dry-run     Report planned actions without writing any files.

Exit codes:
  0   Success (or dry-run completed with no structural errors)
  1   Usage error (invalid flag, missing dependency)
  2   Boundary violation (attempted write to unmanaged path)
  3   Source ambiguity (duplicate source names)
  4   Missing dependency (e.g., sha256sum not found)
  5   File-system error (permission denied, disk full, etc.)
```

**CLI-1.3** The script must accept `--dry-run` and `--force` together (report what would be force-overwritten, write nothing).


### CLI-2 — Changes To `scripts/sync-company.sh`

**CLI-2.1** `sync-company.sh` must accept the new flag `--force`, passing it through to `scripts/sync-managed-skills.sh`.

**CLI-2.2** Updated usage:

```
Usage:
  scripts/sync-company.sh [--target-dir PATH] [--force]

Copy the repository .opencode folder into target config directory,
then perform a managed sync of repository-owned skills into ~/.agents/skills.

Defaults:
  target-dir: ~/.config/opencode

Flags:
  --target-dir PATH   Override the canonical OpenCode install target.
  --force             Overwrite locally modified managed entries in ~/.agents/skills.
```

**CLI-2.3** `sync-company.sh` does not expose a new `--dry-run` mode in MVP. Dry-run remains scoped to `scripts/sync-managed-skills.sh` so operators are not misled into expecting a no-write preview of the canonical `~/.config/opencode` install.

**CLI-2.4** Exit code behavior: if the canonical install fails, exit with the canonical install failure code. If the canonical install succeeds but the managed sync fails, exit with the managed sync failure code. If both succeed, exit 0.

### CLI-3 — Changes To `scripts/init-company.sh` And `scripts/update-company.sh`

**CLI-3.1** No code changes required. Both scripts delegate to `sync-company.sh` via `exec`, which inherits all new flags.

## Security Considerations

### SEC-1 — Path Traversal Prevention

**SEC-1.1** The script must resolve all source paths relative to the repository root and reject any source path containing `..` segments that escape the repo root.

**SEC-1.2** Target paths under `~/.agents/skills/` must be constructed by joining the resolved base target directory with the entry name and subpath. No user-provided input may influence target path construction beyond the entry name.

**SEC-1.3** Before writing any file, the resolved absolute target path must be validated to start with the resolved absolute path of `~/.agents/skills/` (or the canonical install target for FR-1). Any path that escapes this prefix must be rejected as a fatal security error (exit code 2).

### SEC-2 — Manifest Trust Model

**SEC-2.1** The manifest is a record of what the sync has previously installed, not an authoritative source of ownership. The sync must never trust the manifest to grant write permission to a path; it must independently verify that each target path is within the managed subtree and corresponds to a current or previously-managed source.

**SEC-2.2** A maliciously crafted manifest (e.g., containing `target_path` entries pointing outside `~/.agents/skills/`) must be detected by SEC-1.3 path prefix validation before any write occurs.

**SEC-2.3** The sync must not execute any file under `~/.agents/skills/` or source directories. The sync performs file copy, hash computation, and YAML frontmatter parsing only.

### SEC-3 — Permission Handling

**SEC-3.1** Installed files must have permissions 0644 (owner read/write, group read, other read). Installed directories must have permissions 0755. Executable files in source skill directories (e.g., `.sh` scripts) must be installed with 0755.

**SEC-3.2** The sync must not change permissions on unmanaged files or directories. When updating an existing managed file, the sync must preserve the existing file permissions unless they are more permissive than 0644, in which case they must be tightened to 0644.

**SEC-3.3** The sync must use `mktemp` for any temporary files and set a `trap` to clean them up on exit (including on error).

### SEC-4 — Secrets In Source Files

**SEC-4.1** The sync must never log, display, or hash content that might contain secrets. However, the current source files (commands and skills) do not contain secrets. If this changes, a pre-sync scan must be added.

**SEC-4.2** The `opencode.json` provider config merge in the canonical install (existing behavior) is the only code path that interacts with potentially sensitive data. The managed sync must not read or parse `opencode.json`.

### SEC-5 — Unmanaged Content Protection

**SEC-5.1** The sync must never inspect, hash, compare, or enumerate files in unmanaged directories under `~/.agents/skills/`. The sync may only check for the existence of a directory entry to determine if a new install would overwrite it (which must be rejected unless the path is already in the manifest).

**SEC-5.2** The sync must not follow symlinks when checking for directory existence in the target. If a managed target path is a symlink, the sync must reject it with a warning (the operator must resolve the symlink manually).

## Integration Points

### INT-1 — Source Skill Directories

**INT-1.1** Source: `.opencode/skills/<name>/` — each directory contains a `SKILL.md` file and may contain subdirectories `scripts/`, `references/`, `assets/`, `evals/`, `agents/`, `examples/`, `eval-viewer/`.

**INT-1.2** The sync must copy the entire directory tree recursively, excluding only repository-specific metadata files (`.gitignore` within skill directories if present — these are not needed in the install target).

**INT-1.3** Files that are symlinks in the source directory must be copied as regular files (dereferenced), not as symlinks. The hash is computed on the file content after dereferencing.

### INT-2 — Source Command Files

**INT-2.1** Source: `.opencode/commands/<name>.md` — each file contains YAML frontmatter (fields: `description`, `agent`) followed by a body.

**INT-2.2** The YAML frontmatter must be parsed to extract the `description` field. The parsing must handle:
  a. Standard `---` delimited YAML frontmatter.
  b. Description values containing colons, quotes, or special characters (must be copied verbatim).
  c. Missing `description` field (treated as empty string `""` in the generated SKILL.md).
  d. Missing frontmatter entirely (body starts immediately; `description` defaults to `""`).

**INT-2.3** The body is defined as all content after the closing `---` of the frontmatter block (or from line 1 if no frontmatter exists), including leading blank lines, trailing whitespace, and `$ARGUMENTS` references.

### INT-3 — Existing Global Install (`sync-company.sh`)

**INT-3.1** The managed sync runs as a child process of `sync-company.sh` and does not share state with the canonical install step beyond the repository root path.

**INT-3.2** The canonical install (FR-1) completes fully before the managed sync begins. If the canonical install fails, the managed sync must not run.

**INT-3.3** The managed sync does not read from or write to `~/.config/opencode/` (the canonical target). The two install targets are fully independent at the filesystem level.

### INT-4 — Temporary Artifacts For Command-Derived Skills

**INT-4.1** Command-derived SKILL.md content must be generated in memory (or a temp file) and written directly to the target path, not staged in an intermediate build directory.

**INT-4.2** Temporary hash computation files must be created via `mktemp` and cleaned up via `trap EXIT`.

### INT-5 — Manifest File

**INT-5.1** The manifest lives at `~/.agents/skills/.manifest.json`. It is the sole record of managed ownership for files under `~/.agents/skills/`.

**INT-5.2** The manifest is written last in the sync sequence, after all file operations complete successfully.

## Observability Requirements

### OBS-1 — Install-Time Output Format

**OBS-1.1** Every action taken or skipped by the managed sync must produce one line to stdout or stderr, prefixed with a category tag:

| Prefix | Destination | Meaning |
|---|---|---|
| `[INSTALL]` | stdout | New managed entry created |
| `[UPDATE]` | stdout | Existing managed entry updated from source |
| `[NOOP]` | stdout | Managed entry unchanged (idempotent re-run) |
| `[SKIP modified]` | stderr | Locally modified entry preserved |
| `[SKIP orphan]` | stderr | Orphan managed entry with no source, preserved |
| `[SKIP collision]` | stderr | Entry skipped because a safe install would collide with an existing name |
| `[FORCE overwrite]` | stderr | Locally modified entry overwritten due to --force |
| `[WARNING]` | stderr | Non-fatal issue (corrupt manifest recovered, symlink detected, etc.) |
| `[ERROR]` | stderr | Fatal error before exit |

**OBS-1.2** Each action line must include the entry name and, for file-level operations, the relative path within the entry. Examples:

```
[INSTALL] do-tasks (command-derived -> ~/.agents/skills/do-tasks/SKILL.md)
[UPDATE] agent-communication-log/SKILL.md (source skill)
[NOOP] github-issues-projects-cli (all files unchanged)
[SKIP modified] role-memory/SKILL.md (preserved local changes)
[FORCE overwrite] task-completion/SKILL.md (replaced from source)
[SKIP collision] do-tasks (unmanaged entry already occupies target name)
```

### OBS-2 — Summary Output

**OBS-2.1** After all actions complete, the sync must emit a summary block to stdout:

```
=== Managed Sync Summary ===
Installed:    N
Updated:      N
Skipped (modified): N
Skipped (orphan):   N
Force overwritten:  N
No-op:              N
Errors:             N
Total managed entries: N
```

### OBS-3 — Dry-Run Output

**OBS-3.1** Dry-run output must use the same action line format as a real run, prefixed by `[DRY-RUN]`. The summary block must include the header `=== Dry-Run Summary (no files written) ===`.

**OBS-3.2** Dry-run must not emit `[SKIP]` lines for entries that would be `[NOOP]` in a real run — those are also `[NOOP]` in dry-run.

### OBS-4 — Error Output

**OBS-4.1** Fatal errors must be emitted to stderr prefixed with `[ERROR]`, followed by a specific description and suggested resolution.

**OBS-4.2** The exit code must be the last line of output when non-zero, or explicitly stated in the summary.

## Error Handling

### ERR-1 — Malformed Command Frontmatter

**ERR-1.1** If a source command file has malformed YAML frontmatter (unclosed `---`, invalid YAML syntax) and the `description` field cannot be extracted, the sync must emit a `[WARNING]` with the file path, default `description` to `""`, and continue processing the body.

**ERR-1.2** If a source command file is unreadable or missing, the sync must emit an `[ERROR]`, skip that entry, and continue processing remaining entries. The final exit code must be 1 if any source file was skipped due to error.

### ERR-2 — Unreadable Source Skill

**ERR-2.1** If a source skill directory exists but its `SKILL.md` or any file within it is unreadable, the sync must emit an `[ERROR]` with the exact path, skip that skill entry entirely, and continue processing remaining entries.

**ERR-2.2** If a source skill directory is missing but recorded in the manifest, the entry becomes an orphan — handled per FR-6.1d (warning, preserved by default).

### ERR-3 — Manifest Corruption

**ERR-3.1** If the manifest file exists but is not valid JSON, the sync must:
  a. Emit a `[WARNING]` with the manifest path and the corruption reason.
  b. Move the corrupt file to `.manifest.json.corrupt.<ISO8601-timestamp>`.
  c. Proceed as if no manifest exists (treat existing `~/.agents/skills/` content as unmanaged).
  d. Write a fresh manifest after completing the sync.

**ERR-3.2** If the manifest is valid JSON but missing required keys, the sync must treat it as corrupt (same recovery as ERR-3.1).

### ERR-4 — Target Permission Errors

**ERR-4.1** If the sync cannot create or write to `~/.agents/skills/` or a subdirectory due to permission errors, it must emit an `[ERROR]` with the path and exit with code 5.

**ERR-4.2** If the sync cannot write to the manifest file, it must emit an `[ERROR]` and exit with code 5. Files already installed in this run remain in place.

### ERR-5 — Partial-Run Recovery

**ERR-5.1** If a previous sync run failed after writing files but before updating the manifest, the next run will find files in `~/.agents/skills/` that are not in the manifest. These files must be treated as follows:
  a. If the directory matches a current source entry name: verify the file content against source, install/update as needed, and add to manifest.
  b. If the directory does not match any current source entry name: treat as unmanaged (never touched).

**ERR-5.2** The sync must never delete files to "clean up" a partial previous run. Orphan cleanup is a manual operator action in MVP using the manifest as a guide.

### ERR-6 — Disk Full

**ERR-6.1** If a write fails with ENOSPC, the sync must emit an `[ERROR]` and exit with code 5. The partially-written file must be removed if possible.

## Testing Strategy

### TEST-1 — Unit Tests (Bash-Level, Run Via `bats` Or Direct Shell)

**TEST-1.1** Manifest read/write and validation: test valid manifest, missing manifest, corrupt JSON manifest, manifest missing required keys, manifest schema validation.

**TEST-1.2** Command frontmatter parsing: test with valid frontmatter, missing frontmatter, frontmatter with only `agent`, frontmatter with complex `description` values (colons, quotes, multi-line not supported), empty file.

**TEST-1.3** SHA-256 hash computation: test known-vector file, empty file, binary file.

**TEST-1.4** Path construction and traversal prevention: test `..` rejection, absolute path rejection, symlink detection.

**TEST-1.5** Source-to-target path mapping for both source_skill and command_derived types.

**TEST-1.6** Collision detection: source skill and command-derived with same name.

### TEST-2 — Integration Tests (Temp Directory As `~/.agents/skills`)

**TEST-2.1** Fresh install (no manifest): all source skills and command-derived skills installed, manifest created, unmanaged sibling content untouched.

**TEST-2.2** Idempotent re-run: second run produces no file writes (only manifest timestamp), all entries report `[NOOP]`.

**TEST-2.3** Source update: modify a source SKILL.md, re-run sync, verify managed entry is updated, unmodified entries are NOOP.

**TEST-2.4** New source entry: add a new skill directory, re-run sync, verify new entry installed without touching existing entries.

**TEST-2.5** Local modification preservation: modify an installed SKILL.md, re-run sync without `--force`, verify entry preserved with warning, file content unchanged.

**TEST-2.6** Force overwrite: modify an installed SKILL.md, re-run sync with `--force`, verify entry overwritten with current source content.

**TEST-2.7** Dry-run: run with `--dry-run`, verify no files written, output matches expected action categories.

**TEST-2.8** Unmanaged content protection: create a file in `~/.agents/skills/` that is not in manifest, run sync, verify file untouched.

**TEST-2.9** Unmanaged name collision: create unmanaged `~/.agents/skills/do-tasks/` before first install, run sync, verify that entry is skipped with warning while unrelated managed entries continue syncing.

**TEST-2.10** Command-derived transformation: verify SKILL.md output has correct `name`, `description`, `disable-model-invocation: true`, preserved `$ARGUMENTS`, dropped `agent`.

**TEST-2.11** Collision resolution: create a source skill and command with the same name, verify source skill wins, command-derived skipped with warning.

**TEST-2.12** Boundary enforcement: craft a manifest with a target_path outside `~/.agents/skills/`, verify sync rejects it.

**TEST-2.13** Partial-run recovery: simulate a crash after file write but before manifest update, verify next run recovers cleanly.

**TEST-2.14** Source skill full-directory copy: verify scripts, references, assets subdirectories are all copied.

### TEST-3 — Acceptance Tests (End-To-End)

**TEST-3.1** Real `sync-company.sh` run: verify `~/.config/opencode` installed as before, `~/.agents/skills/` populated with all 26 source skills and 8 command-derived skills, unmanaged content (external skills) untouched.

**TEST-3.2** Real idempotent re-run: verify exit code 0, no unexpected file modifications, all NOOP.

**TEST-3.3** Real managed-sync dry-run: verify `scripts/sync-managed-skills.sh --dry-run` correctly identifies all actions that a real managed sync would take and writes no files.

**TEST-3.4** Real force overwrite: modify a real installed file, run with `--force`, verify overwrite with current source content.

### TEST-4 — Test Coverage Requirements

**TEST-4.1** Every functional requirement (FR-1 through FR-12) must be covered by at least one test case.

**TEST-4.2** Every error handling scenario (ERR-1 through ERR-6) must be covered by at least one test case.

**TEST-4.3** Test suite must pass with `set -euo pipefail` active.

## Architecture Notes

### ARCH-NOTE-1 — New Architecture Document Required

This spec introduces a new managed sync subsystem that operates on a separate install target with different safety semantics than the existing full-replace canonical install. Architecture document **ARCH-004** is the required architectural reference and defines:

- The two-target install model (canonical full-replace vs. managed non-destructive)
- The manifest ownership model and its trust boundaries
- The command-to-skill transformation contract
- The exact-name collision resolution rules
- The force-overwrite and manual rollback semantics
- The integration contract between `sync-company.sh` and `sync-managed-skills.sh`

See `docs/arch/ARCH-004-managed-skill-sync-architecture.md`.

### ARCH-NOTE-2 — No Second Canonical Source Of Truth

The existing architecture (ARCH-001, ARCH-003) establishes `~/.config/opencode` as the canonical install target and `.opencode/skills/` + `.opencode/commands/` as the canonical source. The managed sync to `~/.agents/skills` is a derived mirror — it does not introduce a second source of truth. Every file under `~/.agents/skills/` managed by this sync is traceable to a source file in the repository.

### ARCH-NOTE-3 — Separation From SPEC-001

SPEC-001 governs the `init-project` workflow for project-local initialization. SPEC-002 governs the global company install sync behavior. They share no code paths and no data. ARCH-003 (project-local initialization artifacts) is not affected by this spec.

## Acceptance Criteria At The Spec Level

Each acceptance criterion below is traceable to at least one functional requirement and must be verified before this spec is marked complete.

### AC-1 — Canonical Target Preserved

**AC-1.1** Running `scripts/sync-company.sh` installs `.opencode/` contents to `~/.config/opencode` with provider config merged, matching the pre-SPEC-002 behavior exactly. (FR-1)

**Verification:** Compare `diff -r .opencode/ ~/.config/opencode/` (excluding `opencode.json` provider section) before and after SPEC-002 changes.

### AC-2 — Managed Skills Populated

**AC-2.1** After a default sync, `~/.agents/skills/` contains exactly 34 entries: 26 source skill directories plus 8 command-derived skill directories. Unmanaged sibling directories (e.g., `brandkit`, `microsoft-foundry`) remain unchanged. (FR-2)

**Verification:** `ls ~/.agents/skills/` before and after sync; count managed vs unmanaged directories.

### AC-3 — Command Transform Correctness

**AC-3.1** For each of the 8 command files, `~/.agents/skills/<name>/SKILL.md` exists with frontmatter containing `name`, `description`, and `disable-model-invocation: true`, body matching the source command body, and `agent` field absent. (FR-4)

**Verification:** For each command, compare body content, verify frontmatter fields programmatically.

### AC-4 — Modified Entries Survive Default Rerun

**AC-4.1** Modify a managed `SKILL.md` under `~/.agents/skills/`. Run sync without `--force`. The file content is unchanged, a `WARNING:` is emitted to stderr, and the sync exits 0. (FR-5, FR-6)

**Verification:** SHA-256 before and after sync; check stderr for warning line.

### AC-5 — `--force` Is The Only Overwrite Path

**AC-5.1** The same modified file from AC-4, when sync is run with `--force`, is overwritten with current source content and a `FORCE:` notice is emitted. (FR-8)

**Verification:** SHA-256 matches source after force run.

### AC-6 — Unmanaged Content Survives All Operations

**AC-6.1** Create a file `~/.agents/skills/my-custom-skill/SKILL.md` that is not in the manifest. Run sync in default, `--force`, and `--dry-run` modes. In all cases, the file remains untouched and no warning about it appears. (FR-7, FR-9)

**Verification:** SHA-256 unchanged after each run; file never appears in sync output.

### AC-7 — Idempotency

**AC-7.1** Run sync twice with no intervening source or target changes. On the second run, every managed entry reports `[NOOP]`, no files are written (except manifest `last_sync` timestamp), and exit code is 0. (FR-10)

**Verification:** `find ~/.agents/skills/ -newer <timestamp-before-second-run>` returns only `.manifest.json`.

### AC-8 — Dry-Run Writes Nothing

**AC-8.1** Run `scripts/sync-managed-skills.sh --dry-run`. No files under `~/.agents/skills/` are created, modified, or deleted. The manifest is unchanged. The output reports planned actions with `[DRY-RUN]`. (FR-9)

**Verification:** `find ~/.agents/skills/ -newer <timestamp-before-run>` returns nothing; manifest hash unchanged.

### AC-9 — Source Skill Directories Installed Completely

**AC-9.1** A source skill with subdirectories (e.g., `github-issues-projects-cli` with `scripts/`, `references/`, `evals/`) is installed with all files and subdirectories intact. (FR-2.2a)

**Verification:** `diff -r .opencode/skills/github-issues-projects-cli/ ~/.agents/skills/github-issues-projects-cli/` shows no differences.

### AC-10 — Collision Resolution Works

**AC-10.1** Create a source skill directory `.opencode/skills/test-collision/` and a command file `.opencode/commands/test-collision.md`. Run sync. The source skill is installed, the command-derived entry is skipped with a `[SKIP collision]` warning. (FR-11)

**Verification:** `~/.agents/skills/test-collision/SKILL.md` matches the source skill SKILL.md, not the command-derived output.

## Rollout And Rollback Plan

### ROLLOUT-1 — Implementation Order

**ROLLOUT-1.1** Implementation must proceed in this order, with each step independently testable:

1. **ARCH-004 document** — Define the managed sync architecture before any code is written.
2. **`scripts/sync-managed-skills.sh`** — Implement the managed sync script with all FR-2 through FR-11 behavior. This is the core deliverable. Test with temp directories before touching real `~/.agents/skills/`.
3. **`scripts/sync-company.sh` integration** — Add `--force` passthrough and the post-install invocation of `sync-managed-skills.sh`. The canonical install path must remain unchanged.
4. **Test suite** — Implement TEST-1 through TEST-4.
5. **Documentation update** — Update DOCUMENT_INDEX.md and related docs.

### ROLLOUT-2 — Migration From Current Single-Target Behavior

**ROLLOUT-2.1** For operators upgrading from the current `sync-company.sh` (which only touches `~/.config/opencode`), the first run of the updated script will:
  a. Install `~/.config/opencode` as before (no behavioral change).
  b. Detect that `~/.agents/skills/` has no manifest (or has unmanaged content).
  c. Install all repository-owned entries as new managed entries without touching unmanaged sibling content.
  d. Write a fresh manifest.

**ROLLOUT-2.2** No migration steps are required for the operator. The upgrade is transparent.

### ROLLOUT-3 — Rollback Procedure

**ROLLOUT-3.1** If the managed sync causes operator confusion or conflicts:
  a. The manifest (`~/.agents/skills/.manifest.json`) records exactly which entries are managed.
  b. To remove all managed entries in MVP: delete the managed directories listed in the manifest, then delete the manifest.
  c. Unmanaged content is never affected by this removal.
  d. To revert the `sync-company.sh` behavior: replace with the pre-SPEC-002 version (which does not invoke `sync-managed-skills.sh`). The canonical install behavior was not changed.

**ROLLOUT-3.2** `.manifest.json.corrupt.<timestamp>` files created during manifest recovery are manual inspection artifacts only. The MVP does not create automatic rollback backups for every overwrite.

### ROLLOUT-4 — Feature Flag Consideration

**ROLLOUT-4.1** No feature flag is required. The managed sync is an additive behavior on the existing `sync-company.sh` command. Operators who do not use `~/.agents/skills/` see no change. Operators who do use it benefit from managed population without risk to unmanaged content.

## Risks Or Reasons This May Fail

- The team could over-engineer a generic multi-home package manager instead of shipping the narrow managed mirror actually requested.
- Convenience features such as prune automation, auto-backup files, or a misleading top-level dry-run could consume sprint time without improving the founder-confirmed user outcome.
- Modification detection could be too weak, causing false-safe overwrites, or too noisy, causing constant warnings and low trust.
- SHA-256 hash comparison could produce false positives for modified files if line endings differ between platforms (mitigated by POSIX line-ending convention in all source files).
- Command-to-skill transforms could drift from source semantics if frontmatter/body preservation rules are underspecified.
- The manifest could become an accidental source of truth for unmanaged content if ownership boundaries are not explicit.
- A technically convenient full-directory replace strategy for `~/.agents` would violate the core user outcome and should be rejected.
- The `shasum -a 256` fallback for macOS may have different output format than `sha256sum` (mitigated by normalizing output to lowercase hex only).

## Assumptions To Test

- Operators actually need `~/.agents/skills` populated from this repository often enough to justify ongoing maintenance.
- Exact-name command-derived skills are accepted by the target agent runtime without an additional naming shim.
- Preserving modified managed entries with warning is operationally clearer than attempting three-way merges.
- A manifest-based ownership model is sufficient to distinguish managed versus unmanaged entries without invasive scanning.
- Installing all source skill directories, including references and scripts, is necessary for runtime usefulness and not just completeness theater.
- SHA-256 hashing is fast enough for the current scale (26 skills + 8 commands) that performance is not a concern.
- The `disable-model-invocation: true` frontmatter field is recognized by the target agent runtimes that consume `~/.agents/skills/`.

## Verification

Strategist completeness check for this spec:

- separate follow-on from SPEC-001 is explicit
- founder-confirmed product decisions are recorded durably
- business sections are complete enough for tech-lead review without re-interviewing the founder
- required technical sections are present with explicit tech-lead placeholders — **NOW FILLED**
- success is defined in observable operator behavior, not vague quality claims

Tech-lead completeness check for this update:

- Functional Requirements: FR-1 through FR-12 with testable numbered sub-requirements — **COMPLETE**
- Technical Requirements: TR-1 through TR-5 with 13 numbered sub-requirements — **COMPLETE**
- Data Model Changes: DM-1 through DM-4 with manifest schema, examples, and path mapping — **COMPLETE**
- API Changes: CLI-1 through CLI-3 with flag specifications and exit codes — **COMPLETE**
- Security Considerations: SEC-1 through SEC-5 with 13 numbered requirements — **COMPLETE**
- Integration Points: INT-1 through INT-5 with source/target/contract details — **COMPLETE**
- Observability Requirements: OBS-1 through OBS-4 with output format specification — **COMPLETE**
- Error Handling: ERR-1 through ERR-6 with 14 numbered scenarios — **COMPLETE**
- Testing Strategy: TEST-1 through TEST-4 with updated MVP test scenarios and coverage requirements — **COMPLETE**
- Architecture Notes: ARCH-NOTE-1 through ARCH-NOTE-3 — **COMPLETE** (ARCH-004 now created)
- Acceptance Criteria: AC-1 through AC-10 with verification commands — **COMPLETE**
- Rollout And Rollback Plan: ROLLOUT-1 through ROLLOUT-4 — **COMPLETE**

Strategist review on 2026-08-01:

- founder-confirmed intent still preserved after technical fill-in — **CONFIRMED**
- exact command-derived names, local modification safety, canonical `~/.config/opencode`, managed `~/.agents/skills` mirror, and unmanaged-content safety remain the governing behavior — **CONFIRMED**
- prune automation, automatic backup files, and top-level `sync-company.sh --dry-run` were cut from MVP because they add scope without improving the named success metrics — **CONFIRMED**

## Related Documents

- SPEC-001 — `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`
- ARCH-003 — `docs/arch/ARCH-003-project-local-initialization-artifacts.md`
- ARCH-004 — `docs/arch/ARCH-004-managed-skill-sync-architecture.md`
- GOV-002 — `docs/gov/GOV-002-master-enterprise-architecture-reference-and-local-application.md`
- README — `README.md`
