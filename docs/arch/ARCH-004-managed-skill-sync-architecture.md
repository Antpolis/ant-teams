# Managed Skill Sync Architecture

Metadata:

| Field | Value |
|---|---|
| ID | ARCH-004 |
| Type | arch |
| Domain | global workflow installation |
| Status | active |
| Owner | tech-lead |
| Applies To | `scripts/sync-managed-skills.sh`, `scripts/sync-company.sh`, managed install target `~/.agents/skills`, manifest `~/.agents/skills/.manifest.json`, source `.opencode/skills/`, source `.opencode/commands/` |
| Keywords | managed sync, two-target install, manifest ownership, command-derived skills, SKILL.md transform, idempotent sync, non-destructive install, exact-name collision, force overwrite, manual rollback |
| Related Docs | SPEC-002, SPEC-001, ARCH-001, ARCH-003, GOV-002 |
| Supersedes |  |
| Last Updated | 2026-08-01 |

## Summary

This document defines the architecture of the managed global skill sync system. It establishes the two-target install model, the manifest ownership mechanism, the command-to-skill transformation contract, and the operational semantics for collision resolution, modification detection, force overwrite, and manual rollback.

## Purpose

Provide the canonical architectural reference for the managed sync subsystem so that implementers, reviewers, and future maintainers have a single source of truth for how the two install targets interact, how ownership is tracked, and what safety guarantees the system upholds.

## Scope

Weakest assumption to reject first: adding cleanup convenience is not the same as improving operator trust. This architecture stays intentionally narrow and avoids prune automation or backup-file sprawl in MVP.

This document covers:

- The two-target install model (canonical full-replace vs. managed non-destructive)
- The manifest ownership model (schema, trust boundaries, lifecycle)
- The command-to-skill transformation contract
- Modification detection using content hashes
- Exact-name collision resolution rules
- Force overwrite and manual rollback semantics
- Integration contract between `sync-company.sh` and `sync-managed-skills.sh`
- Operational concerns: idempotency, atomicity, error recovery

Out of scope:

- The canonical OpenCode install target (`~/.config/opencode`) behavior — this is unchanged and defined in the existing `sync-company.sh`
- Project-local initialization (ARCH-003, SPEC-001)
- Any broader `~/.agents` content management beyond `~/.agents/skills/`

## Audience

- **Builders** implementing `scripts/sync-managed-skills.sh`
- **Reviewers** verifying implementation correctness against the safety model
- **Tech-lead** defining guardrails and sequencing for the implementation
- **Operators** understanding the managed sync behavior and rollback procedures

## System Boundaries

### Two-Target Install Model

```
Repository Sources                     Install Targets
==================                     ================

.opencode/                            ~/.config/opencode/
├── commands/       ──full replace──► ├── commands/          (unchanged)
├── skills/                          ├── skills/
├── opencode.json                    ├── opencode.json
└── ...                              └── ...

                                      ~/.agents/skills/
.opencode/skills/   ──managed sync──► ├── agent-communication-log/
  ├── <name>/                         │   └── SKILL.md
  │   ├── SKILL.md                    ├── do-tasks/          (command-derived)
  │   ├── scripts/                    │   └── SKILL.md
  │   └── references/                 ├── ...
                                      └── .manifest.json
.opencode/commands/
  ├── do-tasks.md  ──transform──►
  └── ...
```

**Target 1 — Canonical (`~/.config/opencode`):** Full-replace strategy. The repository `.opencode/` directory replaces the entire target directory (with provider config merge). This target is entirely repository-owned; there is no concept of "unmanaged content."

**Target 2 — Managed (`~/.agents/skills/`):** Non-destructive, manifest-tracked strategy. Only repository-owned entries recorded in the manifest are managed. Unmanaged sibling content is never touched.

### Ownership Boundary

```
~/.agents/skills/
├── .manifest.json          ← Managed (the ownership record itself)
├── agent-communication-log/ ← Managed (recorded in manifest)
│   └── SKILL.md
├── do-tasks/               ← Managed (command-derived, recorded in manifest)
│   └── SKILL.md
├── brandkit/               ← UNMANAGED (never touched by sync)
│   └── SKILL.md
└── my-custom-skill/        ← UNMANAGED (never touched by sync)
    └── SKILL.md
```

The sync determines whether an entry is managed by consulting the manifest. An entry is managed IFF its name appears as a key in `managed_entries`. An entry is unmanaged IFF its directory exists under `~/.agents/skills/` but its name does not appear in `managed_entries`.

## Components

### Component 1: `scripts/sync-managed-skills.sh`

**Responsibility:** Perform the managed sync from repository sources to `~/.agents/skills/`.

**Inputs:**
- Repository root (`scripts/sync-managed-skills.sh` resolves its own location)
- Source skill directories: `.opencode/skills/<name>/`
- Source command files: `.opencode/commands/<name>.md`
- Existing manifest: `~/.agents/skills/.manifest.json` (may not exist)

**Outputs:**
- Installed skill directories under `~/.agents/skills/<name>/`
- Updated manifest: `~/.agents/skills/.manifest.json`
- Corrupt manifest backups: `.manifest.json.corrupt.<timestamp>` (on recovery)

**Flags:**
- `--force`: overwrite locally modified managed entries
- `--dry-run`: report planned actions, write nothing

### Component 2: `scripts/sync-company.sh` (Modified)

**Responsibility:** Coordinate the two-target install. Existing canonical install (unchanged) plus invocation of `sync-managed-skills.sh`.

**Changes from pre-SPEC-002:**
- Accept `--force` for managed overwrite passthrough
- After canonical install completes, invoke `scripts/sync-managed-skills.sh` with `--force` when requested
- Exit code reflects worst outcome

### Component 3: Manifest (`~/.agents/skills/.manifest.json`)

**Responsibility:** Record the ownership and install state of every managed file under `~/.agents/skills/`.

**Schema:** Defined in SPEC-002 Data Model Changes (DM-2).

**Lifecycle:**
1. **Creation:** Written after first successful managed sync.
2. **Update:** Rewritten after every successful managed sync (atomic write via temp+rename).
3. **Recovery:** If corrupt, moved to `.corrupt.<timestamp>` and regenerated from source.

### Component 4: Command Transform (Inline Logic)

**Responsibility:** Convert `.opencode/commands/<name>.md` into `~/.agents/skills/<name>/SKILL.md`.

**Transformation rules (detailed):**

Input (`do-tasks.md`):
```yaml
---
description: Continue or finish existing approved tasks.
agent: orchestrator
---

Drive the next approved task work...
```

Output (`do-tasks/SKILL.md`):
```yaml
---
name: do-tasks
description: Continue or finish existing approved tasks.
disable-model-invocation: true
---

Drive the next approved task work...
```

Rules:
1. Extract `description` from source frontmatter (default `""` if missing).
2. Drop `agent` field.
3. Add `name` field set to command filename without `.md` extension.
4. Add `disable-model-invocation: true`.
5. Preserve body content byte-for-byte, including `$ARGUMENTS` references.
6. Emit fields in order: `name`, `description`, `disable-model-invocation`.
7. Ensure trailing newline.

## Data Flow

### Sync Algorithm (Per-Run)

```
1. RESOLVE source paths
   ├── Discover .opencode/skills/<name>/ directories
   └── Discover .opencode/commands/<name>.md files

2. RESOLVE collision (source skills win over command-derived)

3. READ manifest (or initialize empty if absent/corrupt)

4. For each source entry (skill + command-derived):
   ├── COMPUTE source hashes (SHA-256 of every source file)
   ├── DETERMINE action:
   │   ├── New entry (not in manifest)          → [INSTALL]
   │   ├── Unchanged (hash matches manifest)     → [NOOP]
   │   ├── Source changed, target unchanged      → [UPDATE]
   │   ├── Target locally modified (hash != manifest) →
   │   │   ├── --force        → [FORCE overwrite]
   │   │   └── default        → [SKIP modified]
   │   ├── Source gone (orphan)                   → [SKIP orphan]
   │   └── Target name occupied by unmanaged entry → [SKIP collision]
   └── EXECUTE action (or report if --dry-run)

5. For each new managed file being written:
   └── VALIDATE target path is within ~/.agents/skills/

6. WRITE manifest (atomic: temp file → rename)
7. EMIT summary
```

### Hash Comparison Model

```
                    ┌─────────────┐
                    │ Source File │
                    └──────┬──────┘
                           │ compute SHA-256
                           ▼
                    ┌─────────────┐
                    │ source_hash │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                  ▼
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │ Installed    │  │ Manifest     │  │ Source-       │
  │ File         │  │ Recorded     │  │ Predicted     │
  │ (current)    │  │ Hash         │  │ Hash (cmd-    │
  │              │  │              │  │ derived only) │
  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
         │                 │                  │
         └────────┬────────┘                  │
                  │ compare                    │
                  ▼                            │
         ┌────────────────┐                   │
         │ current_hash   │                   │
         │ vs             │                   │
         │ manifest_hash  │                   │
         └───────┬────────┘                   │
                 │                            │
    ┌────────────┼────────────┐               │
    ▼            ▼            ▼               │
  Equal      Different    (Not in             │
  (NOOP)     (Modified)   manifest)           │
                  │         (Install)         │
                  ▼                            │
         ┌────────────────┐                   │
         │ Preserve       │                   │
         │ (or force)     │                   │
         └────────────────┘                   │
```

For command-derived entries, a source-predicted hash is computed by generating what the SKILL.md would be from current source. This is used during manifest recovery (ERR-5.1a) to determine if an unmanifested file matches current source or is truly unrelated.

## Operational Concerns

### Idempotency Guarantee

The sync is idempotent by construction: every write decision is based on content hash comparison. When no source files have changed and no target files have been modified, the sync computes identical hashes and takes no action (all NOOP). The only mutation on an idempotent re-run is the manifest `last_sync` timestamp.

### Atomicity

The manifest is the last artifact written, and it is written atomically (temp file + rename). File installations may complete before the manifest commit. If a crash occurs mid-sync:
- Files written before the crash remain on disk without a manifest record.
- On next run, these files are detected (present on disk, not in manifest) and either matched to source (if content matches) or treated as unmanaged (if directory doesn't match any source entry).

### Performance Characteristics

- **Time complexity:** O(F) where F is the total number of files across all source skills and commands. Currently F ≈ 70.
- **Space complexity:** O(F) for in-memory hash storage. Temporary files are cleaned up.
- **Disk I/O:** One read per source file (hash), one read per target file (hash if exists), one write per changed/new file.
- **Expected runtime:** < 1 second for no-op dry-run, < 5 seconds for full install on modern hardware.

## Failure Modes

| Failure | Detection | Behavior |
|---|---|---|
| Missing `sha256sum` | Startup check | Exit 4 with message |
| Corrupt manifest | JSON parse failure | Recover: move to .corrupt, regenerate |
| Source file unreadable | File open failure | Skip entry, continue, exit non-zero |
| Target permission denied | Write failure | Exit 5 with path |
| Disk full | Write failure (ENOSPC) | Exit 5, remove partial file |
| Path traversal attempt | Path prefix validation | Exit 2, no write |
| Symlink in target path | `test -L` check | Skip entry with warning |
| Unmanaged target-name collision | Entry name exists outside manifest | Skip entry with warning, continue |
| Manifest write failure | Rename failure | Exit 5, files remain installed |
| Partial previous run | Files without manifest record | Recover: match to source or leave unmanaged |

## Developer Guardrails

1. **Never write outside `~/.agents/skills/`.** Validate every target path before writing. Use the SEC-1.3 prefix check.

2. **Never touch unmanaged content.** Consult the manifest before any write. Unmanaged entries are invisible to the sync except to confirm absence before a new install or to detect an exact-name collision that must be skipped with warning.

3. **Never parse or inspect unmanaged files.** Their content, hash, and metadata are out of bounds.

4. **Source skills win over command-derived on name collision.** Check for name overlap after resolving both source sets.

5. **Generated command-derived SKILL.md is derived.** Never read it back as input. The authoritative source is the `.opencode/commands/` file.

6. **Manifest is a record, not an authority.** The sync validates write targets independently; the manifest does not grant permission to write outside the managed subtree.

7. **Atomic manifest writes.** Always write to a temp file and rename. Never truncate and rewrite in place.

8. **Clean up temp files.** Use `trap EXIT` for cleanup. Use `mktemp` for all temporary files.

9. **POSIX compatibility.** No GNU-specific flags on `cp`, `sed`, etc. Use `sha256sum` with `shasum -a 256` fallback.

10. **Exit codes are part of the contract.** Scripts calling `sync-managed-skills.sh` depend on specific exit codes (0-5).

11. **Do not re-introduce top-level dry-run or prune scope in MVP.** `sync-company.sh` remains a real canonical installer; dry-run stays on the managed sync script only until there is a real no-write preview for both targets.

## Traceability To Spec

| Spec Requirement | Architecture Component |
|---|---|
| FR-1 (Canonical install) | Component 2 (unchanged behavior) |
| FR-2 (Managed sync) | Component 1 |
| FR-3 (Manifest ownership) | Component 3 |
| FR-4 (Command transform) | Component 4 |
| FR-5 (Modified detection) | Hash comparison model |
| FR-6 (Default behavior) | Sync algorithm (step 4) |
| FR-7 (Boundary enforcement) | Path validation in Component 1 |
| FR-8 (Force) | Sync algorithm (step 4, --force branch) |
| FR-9 (Dry-run) | Sync algorithm (--dry-run flag) |
| FR-10 (Idempotency) | Idempotency guarantee section |
| FR-11 (Collision) | Collision resolution in Component 1 |
| FR-12 (Script entry points) | Component 1 and Component 2 |

## Related Documents

- SPEC-002 — `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`
- ARCH-001 — `docs/arch/ARCH-001-skill-delegation.md`
- ARCH-003 — `docs/arch/ARCH-003-project-local-initialization-artifacts.md`
- GOV-002 — `docs/gov/GOV-002-master-enterprise-architecture-reference-and-local-application.md`
