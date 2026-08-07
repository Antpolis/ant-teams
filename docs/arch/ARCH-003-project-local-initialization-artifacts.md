# Project-Local Initialization Artifacts

Metadata:

| Field | Value |
|---|---|
| ID | ARCH-003 |
| Type | arch |
| Domain | project initialization workflow |
| Status | active |
| Owner | tech-lead |
| Applies To | `scripts/init-project.sh`, `.github-project.json`, `AGENTS.md`, project-local `.opencode/skills/`, all initialized project repositories |
| Keywords | init-project, AGENTS.md, .github-project.json, project-local skills, multi-repo identity, boundaries, backward-compatible migration, initialization artifacts |
| Related Docs | SPEC-001, ARCH-001, ARCH-002, GOV-002, `.opencode/skills/project-initialization/SKILL.md`, `DOCUMENT_INDEX.md` |
| Supersedes |  |
| Last Updated | 2026-07-18 |

## Summary

This document is the canonical technical reference for the project-local initialization artifacts produced by `init-project`. It defines the contract that every initialized repository must fulfill and that every downstream agent can rely on. It supersedes the two inconsistent partial schemas currently embedded in `init_project_docs.sh` and `setup_project_docs.sh`.

## Purpose

Define the stable artifact contract (`AGENTS.md`, `.github-project.json`, project-local `.opencode/skills/`) so that agent prompts, downstream tooling, and migration logic have a single source of truth about what an initialized repository contains and what guarantees those artifacts make.

## Scope

This document covers:
- The `.github-project.json` canonical schema (single source of truth)
- The `AGENTS.md` generation contract (structure, guarantees, content bounds)
- The project-local skills copy model (which skills, why those three, merge rules)
- The multi-repo identity/boundary model (thin, static, non-resolving)
- The backward-compatibility contract (what survives, what coexists, what is deprecated)

Out of scope:
- The interactive prompting UX (defined in SPEC-001)
- The repository inspection algorithm (defined in SPEC-001 FR-2)
- Agent prompt updates to consume these artifacts (no changes required — existing prompts already reference `./.github-project.json` and `./.opencode/skills/`)

## Audience

- **Builders** implementing or modifying the `init-project` pipeline
- **Reviewers** verifying init output correctness
- **Downstream agents** (orchestrator, tech-lead, strategist, builder, reviewer) consuming initialized repo context
- **Multi-repo maintainers** reasoning about repo boundaries

## Artifacts And Their Contracts

### Artifact 1: `.github-project.json`

**Location:** `<REPO_ROOT>/.github-project.json`

**Purpose:** The single local source for shared GitHub workflow metadata and thin multi-repo identity. Every agent prompt that references `./.github-project.json` must be able to rely on this file's structure.

**Canonical schema:**

```json
{
  "owner": "string (required)",
  "owner_type": "org | user (required)",
  "repo": "string (required, format owner/repo)",
  "project": {
    "number": "integer (required)",
    "id": "string (optional, GraphQL global ID)"
  },
  "fields": {
    "status": "string (required, GraphQL field ID)"
  },
  "status_options": {
    "todo": "string (required)",
    "in-progress": "string (required)",
    "in-review": "string (required)",
    "done": "string (required)",
    "blocked": "string (optional)",
    "need-attentions": "string (optional)",
    "ready": "string (optional)",
    "ready-to-merge": "string (optional)",
    "inbox": "string (optional)",
    "shaping": "string (optional)"
  },
  "worktreeRoot": "string (required, absolute or ~-prefixed path)",
  "identity": {
    "name": "string (required)",
    "description": "string (required)",
    "role": "service | library | infra | monorepo-root | tool | docs | other (required)"
  },
  "boundaries": {
    "owns": "string (required)",
    "depends_on": [
      {
        "name": "string",
        "url": "string",
        "relationship": "string"
      }
    ],
    "related_repos": [
      {
        "name": "string",
        "url": "string",
        "relationship": "string"
      }
    ]
  },
  "initMeta": {
    "version": "string (required)",
    "generatedAt": "string (required, ISO 8601)"
  }
}
```

**Guarantees:**
1. If this file exists at the repo root, all required fields listed above are present.
2. The schema is strictly additive — new fields may be added but existing required fields are never removed by the initializer.
3. The `worktreeRoot` field points to a directory that `create_task_worktree.sh` can use.
4. The `identity` and `boundaries` blocks reflect operator-provided or detected metadata. They are authoritative for this repo's self-description.
5. The `initMeta.version` field enables migration tooling to detect stale configs.

**Agent consumption pattern:** All agent prompts already reference `./.github-project.json`. The new `identity`, `boundaries`, and `initMeta` fields are passively available — agents may read them but the absence of code that reads them does not cause failures. The fields are described in `AGENTS.md` for agent discoverability.

### Artifact 2: `AGENTS.md`

**Location:** `<REPO_ROOT>/AGENTS.md`

**Purpose:** The primary agent guidance file for this repository. Replaces the legacy `agent.md` (lowercase) as the canonical path. Downstream agents should prefer `AGENTS.md` when both exist, falling back to `agent.md` only when `AGENTS.md` is absent.

**Guarantees:**
1. Every factual claim in the file is traceable to either repository inspection evidence or explicit operator input. The file contains no fabricated claims.
2. The file begins with `<!-- Generated by init-project vX.Y.Z on <ISO 8601> — edit freely -->`.
3. Sections without content are absent — no empty headings with placeholder text.
4. At minimum, the "Local Configuration Files" section lists every initialization artifact present.
5. The file uses Markdown format with UTF-8 encoding and LF line endings.

**Agent consumption pattern:** Agents read `AGENTS.md` as part of their initial repository context. The file provides structured sections that match the agent's context-gathering needs (stack, commands, conventions, boundaries). No agent parses `AGENTS.md` programmatically — it is a human-and-agent-readable document.

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

## Multi-Repo Identity And Boundary Model

### Design principle: thin, static, non-resolving

The multi-repo identity model deliberately avoids:
- Live URL resolution (no network calls, no credential surface)
- Automatic discovery (operator or init provides the information)
- Schema that implies a canonical multi-repo directory service
- Dependencies that require sibling repos to be present or reachable

Instead, it stores operator-provided, human-maintained metadata as static JSON strings. This is sufficient to prevent repo confusion (the primary goal) without creating an operational dependency on external repos being available.

### When agents should use boundary metadata

Agents should consult `.github-project.json` → `boundaries` when:
- A task references a service or component that may live in a sibling repo
- Cross-repo coordination is needed
- The agent is unsure whether a change should be made in this repo or another

Agents should **not** use boundary metadata for:
- Automatic code fetching or resolution
- Build-time dependency resolution
- Inferring API contracts or schemas

### Relationship to GOV-002

The `identity` and `boundaries` blocks in `.github-project.json` are project-level local metadata. They do not duplicate or mirror the master enterprise architecture (stored in Google Drive per GOV-002). They describe *this repo's* place in the multi-repo family, not enterprise-wide architecture. No GOV-002 conflict exists.

## Backward-Compatibility Contract

### What the upgraded initializer preserves

| Existing artifact | Behavior |
|---|---|
| `agent.md` (lowercase) | Never deleted. Coexists with `AGENTS.md`. Content may be read for migration (interactive mode only) but the file is not modified. |
| `.github-project.json` (old schema) | Existing fields (`owner`, `owner_type`, `repo`, `project`, `fields`, `status_options`) are preserved verbatim. New fields (`worktreeRoot`, `identity`, `boundaries`, `initMeta`) are added if missing. |
| `.opencode/opencode.json` / `.opencode/opencode.jsonc` | Existing entries preserved. Only `external_directory` is added if missing. |
| Docs folders (`docs/adr/`, `docs/arch/`, etc.) | Never modified or deleted. |
| Project-local custom skills | Preserved; never overwritten. |

### What is deprecated (not removed)

| Deprecated artifact | Status |
|---|---|
| `agent.md` (lowercase) | Deprecated as canonical path. `AGENTS.md` is preferred. `agent.md` remains for backward compatibility but is no longer generated by the upgraded init. |
| `setup_project_docs.sh` | Still available and functional. Not upgraded. For new initializations, `init_project_docs.sh` is the preferred path. |
| `agent-md-template.md` asset | Still present in source repo. No longer used by the upgraded init for `AGENTS.md` generation. |

### Migration states

```
Fresh repo → upgraded init:
  Creates: AGENTS.md, .github-project.json (full schema), .opencode/skills/ (3 skills),
           .opencode/opencode.json (minimal)

Legacy-initialized repo → upgraded init:
  Preserves: agent.md, existing .github-project.json fields, existing .opencode/opencode.json
  Adds: AGENTS.md, worktreeRoot to .github-project.json, identity+boundaries+initMeta,
        .opencode/skills/ (3 skills)

Already-upgraded repo → rerun upgraded init:
  Idempotent: no changes. --force regenerates AGENTS.md, re-copies skills. --merge
  adds new sections to existing AGENTS.md without overwriting.

Already-upgraded repo → run old init (setup_project_docs.sh):
  Old script detects existing files (agent.md, .github-project.json) and skips them.
  No damage, no regression.
```

## Guardrails

### For builders implementing init changes

1. The `.github-project.json` schema defined here is the single source of truth. Do not introduce a second schema in script code.
2. The three skills copied are non-negotiable. Do not add `skill-creator`, `webapp-testing`, or any other skill unless this ARCH document is updated.
3. `AGENTS.md` must never contain fabricated facts. If you cannot trace a claim to inspection evidence or operator input, remove it.
4. Never delete the legacy `agent.md` file automatically. Coexistence is mandatory.
5. The init must not require network access. No API calls, no URL resolution, no external validation.
6. The init must not create files outside the target project directory except for the temp directory used during generation (cleaned up by trap on EXIT).

### For reviewers verifying init output

1. Verify `.github-project.json` contains all required fields.
2. Verify `AGENTS.md` has no placeholder text.
3. Verify exactly three skills are copied, no more.
4. Verify legacy `agent.md` is still present if it existed before.
5. Verify `.opencode/opencode.json` retains all pre-existing entries.
6. Verify idempotency: second run produces no file changes.
7. Verify `--dry-run` writes zero files.

### For agents consuming initialized repo context

1. Read `AGENTS.md` first; fall back to `agent.md` only if `AGENTS.md` is absent.
2. Read `.github-project.json` for GitHub workflow metadata. Assume `worktreeRoot` is present.
3. Reference project-local skills via `./.opencode/skills/<name>/scripts/<script>.sh`.
4. Use `.github-project.json` → `boundaries` for repo-identity questions but do not resolve URLs or fetch sibling repos.
5. The absence of a section in `AGENTS.md` means "no information available," not "default behavior applies."

## Enforcement

- ARCH-003 is the architecture review reference for all init-project changes.
- Any PR that modifies the init scripts must be checked against the guarantees and guardrails in this document.
- Changes to the `.github-project.json` schema, the skills copy list, or the `AGENTS.md` generation contract require an ARCH-003 update.
- SPEC-001 acceptance criteria are the verification standard for initial delivery. This ARCH document is the ongoing maintenance standard. When they conflict, the ARCH document governs structure; the spec governs behavior.

## Related Documents

- `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`
- `docs/arch/ARCH-001-skill-delegation.md`
- `docs/arch/ARCH-002-agent-task-delegation.md`
- `docs/gov/GOV-002-master-enterprise-architecture-reference-and-local-application.md`
- `docs/DOCUMENT_INDEX.md`
- `.opencode/skills/project-initialization/SKILL.md`
