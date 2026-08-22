# Project-Local Initialization Artifacts

Metadata:

| Field | Value |
|---|---|
| ID | ARCH-003 |
| Type | arch |
| Domain | project initialization workflow |
| Status | active |
| Owner | tech-lead |
| Applies To | `scripts/init-project.sh`, `.github-project.env`, `AGENTS.md`, project-local `.opencode/skills/`, all initialized project repositories |
| Keywords | init-project, AGENTS.md, .github-project.env, env-only configuration, ANT_TEAM_* exports, project-local skills, initialization artifacts |
| Related Docs | SPEC-001, ARCH-001, ARCH-002, GOV-002, `.opencode/skills/project-initialization/SKILL.md`, `DOCUMENT_INDEX.md` |
| Supersedes | The `.github-project.json` project-config model (removed 2026-08; see the env-only configuration contract below) |
| Last Updated | 2026-08-22 |

## Summary

This document is the canonical technical reference for the project-local initialization artifacts produced by `init-project`. It defines the contract that every initialized repository must fulfill and that every downstream agent can rely on. Since the founder-confirmed env-only configuration contract (2026-08), the sole committed project config source is `.github-project.env`. There is no JSON config and no JSON import/removal path — the former `.github-project.json` config artifact is ignored (never read, never removed).

## Purpose

Define the stable artifact contract (`AGENTS.md`, `.github-project.env`, project-local `.opencode/skills/`) so that agent prompts, downstream tooling, and upgrade logic have a single source of truth about what an initialized repository contains and what guarantees those artifacts make.

## Scope

This document covers:
- The `.github-project.env` canonical export set (single source of truth)
- The `AGENTS.md` generation contract (structure, guarantees, content bounds)
- The project-local skills copy model (which skills, why those three, merge rules)
- The env-only configuration contract (no JSON import/removal path)
- The backward-compatibility contract (what survives, what coexists, what is deprecated)

Out of scope:
- The interactive prompting UX (defined in SPEC-001)
- The repository inspection algorithm (defined in SPEC-001 FR-2)
- The canonical Workflow State names — they live as constants in the workflow skills, tests, and docs, not as a config field

## Audience

- **Builders** implementing or modifying the `init-project` pipeline
- **Reviewers** verifying init output correctness
- **Downstream agents** (orchestrator, tech-lead, strategist, builder, reviewer) consuming initialized repo context

## Artifacts And Their Contracts

### Artifact 1: `.github-project.env`

**Location:** `<REPO_ROOT>/.github-project.env`

**Purpose:** The sole local source for shared GitHub workflow and routing metadata, expressed as sourceable `ANT_TEAM_*` shell exports. Every agent prompt and helper script that needs stable project metadata sources this file; nothing parses a JSON config at runtime because no JSON config exists.

**Canonical export set (deterministic order):**

```text
ANT_TEAM_GITHUB_OWNER                      # GitHub owner
ANT_TEAM_GITHUB_OWNER_TYPE                 # 'org' | 'user'
ANT_TEAM_GITHUB_REPO                       # 'owner/repo'
ANT_TEAM_GITHUB_PROJECT_NUMBER             # GitHub Project number
ANT_TEAM_GITHUB_PROJECT_ID                 # GraphQL global ID (optional value)
ANT_TEAM_GITHUB_STATUS_FIELD_ID            # legacy Status field ID
ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID    # canonical Workflow State field ID
ANT_TEAM_GITHUB_STATUS_OPTION_<KEY>_ID     # one per carried status option key
ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_<KEY>_ID
                                           # one per canonical state: OPEN, BACKLOG,
                                           # NEED_ATTENTIONS, READY, IN_PROGRESS,
                                           # IN_REVIEW, READY_TO_MERGE, BLOCKED, DONE
ANT_TEAM_WORKTREE_ROOT                     # default issue-worktree parent
ANT_TEAM_DOCS_VAULT_PATH                   # central Obsidian vault root
ANT_TEAM_DOCS_PROJECT_NAME                 # defaults to the git repo name
ANT_TEAM_DOCS_PROJECT_PATH_TEMPLATE        # template carrying '<project-name>'
ANT_TEAM_DOCS_REPOSITORY                   # vault remote
ANT_TEAM_DOCS_PROJECT_PATH                 # derived: template with placeholder resolved
```

Option keys normalize to uppercase underscore variable-name fragments (`in-progress` → `IN_PROGRESS`, `need-attentions` → `NEED_ATTENTIONS`, `ready-to-merge` → `READY_TO_MERGE`). Values are single-quoted with `'\''` escaping so any shell metacharacter survives sourcing.

**Seeding and update rules (init-project is the only writer besides the founder):**

1. Fresh repo: seed the full canonical set. Operator flags (`--github-owner`, `--github-project-number`) fill values where provided; everything else gets clearly-marked placeholders (`your-github-owner`, `1`, `PVT_kwDOEXAMPLE`, `*-option-id`, `workflow-state-field-id`). The initializer has no network access and never invents real-looking IDs.
2. Existing env: founder values are preserved verbatim. Only keys that are absent (or empty) are filled; the canonical header is normalized. Nothing already set is ever overwritten.
3. `ANT_TEAM_DOCS_PROJECT_NAME` defaults to the detected git repository name (basename of the project root); a founder value is never replaced.
4. `ANT_TEAM_DOCS_PROJECT_PATH` is derived (first-occurrence `<project-name>` resolution) whenever both template and project name exist.
5. Founder-added non-canonical exports and unrecognized non-comment lines are preserved verbatim.
6. Dropped config fields: there is no `identity`, `boundaries`, `initMeta`, or `canonicalWorkflowStates` block anywhere in the config. Repository identity and relationships live in `AGENTS.md` prose (shaped by `--name`, `--description`, `--repo-role`, `--related-repos`); the canonical Workflow State names live as constants in the workflow skills, tests, and docs.

**Guarantees:**

1. If this file exists at the repo root, every canonical key above is present (possibly with a placeholder value).
2. Re-running init-project is byte-for-byte idempotent: an unchanged env is never rewritten (stable mtime).
3. The file is deterministic — no timestamps, stable key order.
4. `ANT_TEAM_WORKTREE_ROOT` points to a directory `create_task_worktree.sh` can use (may carry a literal `~`; consumers expand it against `$HOME`).
5. The file is safe to commit: shared project metadata only, never secrets.

**Agent consumption pattern:** source it (`source ./.github-project.env`) before GitHub API/project operations, documentation access, and worktree operations. `gh_project_helper.sh` and the do-task worktree helpers source it as their sole local config; remote board discovery remains the fallback for values the env does not carry.

### Artifact 2: `AGENTS.md`

**Location:** `<REPO_ROOT>/AGENTS.md`

**Purpose:** The primary agent guidance file for this repository. Replaces the legacy `agent.md` (lowercase) as the canonical path. Downstream agents should prefer `AGENTS.md` when both exist, falling back to `agent.md` only when `AGENTS.md` is absent.

**Guarantees:**
1. Every factual claim in the file is traceable to either repository inspection evidence or explicit operator input. The file contains no fabricated claims.
2. The file begins with `<!-- Generated by init-project vX.Y.Z on <ISO 8601> — edit freely -->`.
3. Sections without content are absent — no empty headings with placeholder text.
4. At minimum, the "Local Configuration Files" section lists every initialization artifact present.
5. The file uses Markdown format with UTF-8 encoding and LF line endings.

**Agent consumption pattern:** Agents read `AGENTS.md` as part of their initial repository context. The file provides structured sections that match the agent's context-gathering needs (stack, commands, conventions, relationships). No agent parses `AGENTS.md` programmatically — it is a human-and-agent-readable document.

### Artifact 3: Project-local `.opencode/skills/`

**Location:** `<REPO_ROOT>/.opencode/skills/`

**Purpose:** Project-local copies of the three script-bearing skills that all agent prompts depend on via relative paths. Makes the repo self-contained for execution — agents do not need the global `~/.config/opencode` to find these scripts.

**Required skills (and only these):**

| Skill directory | Required scripts | Why |
|---|---|---|
| `github-issues-projects-cli/` | `scripts/gh_project_helper.sh` | All agent prompts reference `./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh` |
| `do-task/` | `scripts/create_task_worktree.sh`, `scripts/cleanup_task_worktree.sh` | Builder and orchestrator use these for issue worktree management |
| `project-initialization/` | `scripts/init_project_docs.sh`, `scripts/setup_project_docs.sh`, `SKILL.md` | Re-initialization and agent-driven project setup |

**Guarantees:**
1. Exactly these three skills are present, plus any project-specific skills the operator adds manually.
2. No other source-repo skills (e.g., `skill-creator`, `webapp-testing`, `frontend-design`) are copied.
3. The `SKILL.md` in each copied skill is a valid OpenCode skill definition.
4. Shell scripts under `scripts/` have execute permission.
5. If the project already has a customized `SKILL.md` for a skill, the local copy is preserved (merge, not overwrite).

**Agent consumption pattern:** Agent prompts use relative paths like `./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh`. These paths resolve correctly because the skills are copied to the project-local `.opencode/skills/` directory. No agent prompt changes are needed.

### Artifact 4: Project-local `.opencode/opencode.json`

**Location:** `<REPO_ROOT>/.opencode/opencode.json` or `.opencode/opencode.jsonc`

**Purpose:** Minimal project-local OpenCode runtime config. Ensures the project's worktree root is accessible to agents.

**Guarantees:**
1. The file contains `permission.external_directory.<worktree-root>/** = "allow"`.
2. The init never removes or modifies existing permission entries, agent definitions, provider configs, or plugin entries.
3. The init never changes the file extension (`.jsonc` to `.json` or vice versa).

**Agent consumption pattern:** OpenCode runtime reads this file automatically. No agent prompt changes needed.

## Backward-Compatibility Contract

### What the initializer preserves

| Existing artifact | Behavior |
|---|---|
| `agent.md` (lowercase) | Never deleted. Coexists with `AGENTS.md`. |
| `.github-project.env` founder values | Preserved verbatim; only missing keys are filled. |
| `.opencode/opencode.json` / `.opencode/opencode.jsonc` | Existing entries preserved. Only `external_directory` is added if missing. |
| Docs folders (`docs/adr/`, `docs/arch/`, etc.) | Never modified or deleted. |
| Project-local custom skills | Preserved; never overwritten. |

### What is deprecated (not removed)

| Deprecated artifact | Status |
|---|---|
| `agent.md` (lowercase) | Deprecated as canonical path. `AGENTS.md` is preferred. `agent.md` remains for backward compatibility but is no longer generated by the upgraded init. |
| `setup_project_docs.sh` | Still available and functional. Not upgraded beyond seeding a placeholder `.github-project.env`. For new initializations, `init_project_docs.sh` is the preferred path. |
| `agent-md-template.md` asset | Still present in source repo. No longer used by the upgraded init for `AGENTS.md` generation. |
| `.github-project.json` | Removed as a config artifact. Ignored entirely: there is no JSON import/removal path. |

### Migration states

```
Fresh repo → init:
  Creates: AGENTS.md, .github-project.env (full canonical seed), .opencode/skills/ (3 skills),
           .opencode/opencode.json (minimal)

Already-initialized repo → rerun init:
  Idempotent: no changes. --force regenerates AGENTS.md, re-copies skills. --merge
  adds new sections to existing AGENTS.md without overwriting.

Already-initialized repo → run old init (setup_project_docs.sh):
  Old script detects existing files (agent.md, .github-project.env) and skips them.
  No damage, no regression.
```

## Guardrails

### For builders implementing init changes

1. The `.github-project.env` export set defined here is the single source of truth. Do not introduce a second config format, a JSON config, or a standalone env generator command.
2. Founder values in the env are never overwritten by the initializer. Only missing keys are filled.
3. The three skills copied are non-negotiable. Do not add `skill-creator`, `webapp-testing`, or any other skill unless this ARCH document is updated.
4. `AGENTS.md` must never contain fabricated facts. If you cannot trace a claim to inspection evidence or operator input, remove it.
5. Never delete the legacy `agent.md` file automatically. Coexistence is mandatory.
6. The init must not require network access. No API calls, no URL resolution, no external validation.
7. The init must not create files outside the target project directory except for the temp directory used during generation (cleaned up by trap on EXIT).
8. Never resurrect `identity`, `boundaries`, `initMeta`, or `canonicalWorkflowStates` config fields — those concerns live in `AGENTS.md` prose and workflow-skill constants respectively.

### For reviewers verifying init output

1. Verify `.github-project.env` exists, sources cleanly, and carries every canonical key.
2. Verify a stray `.github-project.json` is left untouched (init never reads or removes it).
3. Verify `AGENTS.md` has no placeholder text.
4. Verify exactly three skills are copied, no more.
5. Verify legacy `agent.md` is still present if it existed before.
6. Verify `.opencode/opencode.json` retains all pre-existing entries.
7. Verify idempotency: second run produces no file changes.
8. Verify `--dry-run` writes zero files.

### For agents consuming initialized repo context

1. Read `AGENTS.md` first; fall back to `agent.md` only if `AGENTS.md` is absent.
2. Source `.github-project.env` for GitHub workflow metadata and worktree/documentation routing. Assume `ANT_TEAM_WORKTREE_ROOT` is present.
3. Reference project-local skills via `./.opencode/skills/<name>/scripts/<script>.sh`.
4. Canonical Workflow State names come from the workflow skills (`state-transitions`), not from config.

## Enforcement

- ARCH-003 is the architecture review reference for all init-project changes.
- Any PR that modifies the init scripts must be checked against the guarantees and guardrails in this document.
- Changes to the `.github-project.env` export set, the skills copy list, or the `AGENTS.md` generation contract require an ARCH-003 update.
- SPEC-001 defined the original delivery behavior; where its `.github-project.json` design conflicts with this document, ARCH-003 governs. The env-only configuration contract (2026-08) supersedes the JSON artifact design entirely — there is no JSON config and no JSON import/removal path.

## Related Documents

- `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md` (superseded config design)
- `docs/arch/ARCH-001-skill-delegation.md`
- `docs/arch/ARCH-002-agent-task-delegation.md`
- `docs/gov/GOV-002-master-enterprise-architecture-reference-and-local-application.md`
- `docs/DOCUMENT_INDEX.md`
- `.opencode/skills/project-initialization/SKILL.md`
