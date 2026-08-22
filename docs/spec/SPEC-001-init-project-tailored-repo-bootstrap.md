# Init-Project Tailored Repository Bootstrap

> [!WARNING] Superseded config design (2026-08-22)
> The founder-confirmed env-only configuration contract replaced this spec's `.github-project.json` artifact: the JSON config file was deleted, `.github-project.env` (`ANT_TEAM_*` exports) is the sole committed project config source, the `identity` / `boundaries` / `initMeta` / `canonicalWorkflowStates` config fields were dropped (canonical Workflow State names now live as constants in the workflow skills, tests, and docs), and project-init seeds/updates the env directly with no JSON import/removal path (a stray `.github-project.json` is ignored — never read, never removed). See ARCH-003 for the governing artifact contract. This document is retained as the historical SPEC-001 delivery record; its `.github-project.json` references describe the superseded design, not the current system.

Metadata:

| Field | Value |
|---|---|
| ID | SPEC-001 |
| Type | spec |
| Domain | project initialization workflow |
| Status | superseded (config design) — AGENTS.md generation behavior still governed by ARCH-003 |
| Owner | strategist, tech-lead |
| Applies To | `scripts/init-project.sh`, `scripts/init-project-docs.sh`, `.opencode/skills/project-initialization/`, initialized project repositories |
| Keywords | init-project, project initialization, AGENTS.md, opencode.json, .github-project.json, repo bootstrap, multi-repo identity, backward-compatible migration |
| Related Docs | GOV-002, ARCH-001, ARCH-002, ARCH-003, `.opencode/skills/project-initialization/SKILL.md`, `README.md` |
| Supersedes |  |
| Last Updated | 2026-08-22 |

## Summary

Define a safer and more useful `init-project` outcome: instead of only copying a static documentation/config scaffold, initialization must produce a project-local workflow baseline that reflects the target repository's real structure and usage. The critical business addition is a tailored `AGENTS.md` generated from repository inspection plus guided interactive or noninteractive initialization inputs, in the style of Codex/Claude init, while preserving safe backward compatibility for current adopters.

## Problem Statement

The weakest assumption in the prior direction is that copying a generic starter package is "good enough" initialization for a real repository. It is not. A static template can create the appearance of setup while leaving the repo with agent instructions that are generic, stale on day one, or mismatched to the actual stack, boundaries, and working conventions. That fails the founder's goal because the output looks complete but does not materially improve execution quality.

The problem to solve is therefore narrower and more concrete: when a founder or operator runs `init-project` against an existing repository, the workflow must leave behind a trustworthy local operating baseline that is specific enough for agents to work from reality instead of guesswork. That baseline must include project-local `.opencode/opencode.json`, copied required script-bearing skills, repo-root `.github-project.json`, a thin description of multi-repo identity/boundaries/relationships, and a tailored `AGENTS.md` created from repository inspection plus guided initialization inputs.

This matters now because the repository already positions `init-project` as the starting point for delivery work. If the initializer emits generic instructions, every downstream agent loop inherits ambiguity: wrong assumptions about stack, wrong repo boundaries, missing collaboration defaults, and low-confidence project guidance. The result is rework, founder re-explanation, and weaker multi-repo execution.

## Business Value

If this spec succeeds, `init-project` stops being a cosmetic bootstrap step and becomes a reliable first-run accelerator for project onboarding. The founder gains three concrete benefits:

1. Faster setup to first useful delivery work because initialized repos already contain the minimum local workflow context agents need.
2. Lower coordination overhead because `AGENTS.md` and related repo-local metadata are derived from observed repository reality plus explicit founder/operator inputs, rather than from a one-size-fits-all template.
3. Safer rollout across multiple repositories because the migration remains backward-compatible and the new identity/boundary metadata stays intentionally thin instead of becoming a second heavy architecture system.

The user value is not "better docs" in the abstract. The user value is that a newly initialized repository becomes immediately more operable: agents can understand what repo they are in, what local files matter, how that repo relates to neighboring repos, and how to act without repeated manual correction.

## Success Metrics

Success is proven only if the initialized repository becomes measurably more usable, not merely more populated with files. This spec is successful when all of the following are true:

1. **Initialization completeness:** In the acceptance test repos selected for rollout, 100% of successful `init-project` runs produce or preserve all required MVP artifacts: project-local `.opencode/opencode.json`, copied required script-bearing skills, repo-root `.github-project.json`, thin multi-repo identity/boundary metadata, and a generated `AGENTS.md`.
2. **Tailoring quality:** In the same rollout sample, generated `AGENTS.md` files reference repository-specific facts gathered from inspection or initialization input (for example stack, package manager, app/service boundaries, docs root, test/build commands, or repo relationships) and do not ship as untouched generic boilerplate.
3. **Backward-compatible migration safety:** Existing repositories that already use the current initialization flow can rerun the upgraded initializer without destructive loss of existing local config or workflow metadata.
4. **Setup efficiency:** An operator can complete the interactive initialization path for a normal repository without manual file editing during the first pass, and can complete a noninteractive path in a single command when inputs are supplied ahead of time.
5. **Reduced founder re-briefing:** During pilot usage, initialization should eliminate the need for a follow-up clarification on basic repository identity/setup facts in the common case; if repeated clarification is still required, the initialization output is not sufficiently tailored.

## Goals

- Upgrade `init-project` from static scaffolding to repository-aware initialization.
- Ensure initialization writes or maintains a **project-local** `.opencode/opencode.json` rather than relying only on global defaults.
- Copy the **required script-bearing skills** needed for project-local operation so initialized repos are operational, not merely documented.
- Ensure `.github-project.json` exists at the repository root and remains the thin local source for shared GitHub workflow metadata.
- Introduce a **thin** multi-repo identity/boundary/relationship layer that helps agents understand what this repo is, what it owns, and how it relates to sibling repos without turning initialization into a full architecture program.
- Generate a repository-tailored `AGENTS.md` through repository inspection plus guided interactive/noninteractive initialization, explicitly matching the spirit of Codex/Claude init rather than shipping a static generic template.
- Preserve safe backward-compatible migration so current users of `init-project` can adopt the upgraded behavior without breaking existing initialized repos.

## Non-Goals

- Rebuilding the entire delivery workflow, agent roster, or GitHub execution model.
- Creating or modifying GitHub milestones, issues, or project-board items as part of this spec.
- Producing a full enterprise architecture mirror inside every initialized repository.
- Solving deep repository discovery for every possible language or stack in MVP; the initial version only needs enough inspection to generate a useful tailored baseline for common repo shapes.
- Turning `AGENTS.md` generation into an autonomous architecture authoring system. It should tailor practical working instructions, not invent speculative system truth.
- Performing destructive normalization of existing project configs in the name of consistency.
- Expanding scope into implementation-time code generation, task planning, or feature delivery.

## Stakeholders

- **Founder (decision maker):** approves the product direction and cares that initialization yields a genuinely useful starting point rather than boilerplate.
- **Repository operator / initializer runner (primary user):** runs `init-project` and needs a fast, low-friction setup that does not require hand-editing multiple files afterward.
- **Strategist / tech-lead / builder / reviewer agents:** consume the initialized local context and are directly harmed by inaccurate generic setup.
- **Multi-repo maintainers:** need thin but durable repo identity and relationship metadata so work can stay correctly bounded across repositories.
- **Future contributors to the initialization workflow:** need a clearly scoped MVP so the initializer does not sprawl into an unmaintainable platform.

## Constraints

- The implementation must remain **safe and backward-compatible** for repositories already using the current initialization flow.
- The MVP must stay **thin**: multi-repo identity/boundary/relationship data is required, but only at the minimum level needed to prevent repo confusion.
- The initializer must support both **interactive** and **noninteractive** usage patterns.
- Repository inspection must inform `AGENTS.md`, but generated output cannot depend on brittle or exhaustive codebase analysis to be useful.
- The initializer must prefer **project-local** configuration and assets where this spec explicitly requires them, especially `.opencode/opencode.json` and `.github-project.json`.
- Required copied assets are limited to **script-bearing skills** needed for project-local operation; this spec does not justify copying the entire global environment blindly.
- The work is currently at **spec authoring**, so this document must not pre-empt tech-lead decisions on implementation design, exact file formats, or rollout mechanics.
- The solution must fit the current sprint as an MVP slice; anything beyond tailored initialization and safe migration should be deferred rather than absorbed into this spec.

## Functional Requirements

All behavioral statements below are mandatory for MVP delivery unless explicitly marked "(deferred)."

### FR-1: Initialization entrypoint

**FR-1.1** The top-level `scripts/init-project.sh` must trigger the full upgraded initialization flow. It must remain a single-command entrypoint that works identically when invoked from the target project root.

**FR-1.2** The initialization flow must operate in one of two modes, selected at invocation time:
- **Interactive mode** (default when no input flags are supplied): prompts the operator with focused questions and waits for responses before generating artifacts.
- **Noninteractive mode**: accepts all required inputs through CLI flags or environment variables and completes without prompting. If required inputs are missing in noninteractive mode, the command must fail with a clear error message listing which inputs were missing.

**FR-1.3** Both modes must be exposed through `scripts/init-project.sh` using consistent flags. The underlying `init_project_docs.sh` script inside the `project-initialization` skill must be the single implementation, not a duplicate. The entrypoint shell scripts (`init-project.sh`, `init-project-docs.sh`) remain thin delegation wrappers.

### FR-2: Repository inspection phase

**FR-2.1** Before prompting the operator or generating any artifact, the initializer must inspect the target repository to collect factual ground truth. Inspection must be read-only and never modify the target repo.

**FR-2.2** The inspection phase must gather, at minimum, the following categories of evidence:

| Category | Detection method | Mandatory? |
|---|---|---|
| Language / runtime stack | Package manager lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `poetry.lock`, `composer.lock`, `Pipfile.lock`), build configs (`build.gradle*`, `pom.xml`, `Makefile`, `CMakeLists.txt`), module files (`go.mod`, `pyproject.toml`, `Cargo.toml`, `requirements.txt`) | Yes |
| Package manager | Explicit presence of `package.json` (npm/pnpm/yarn), `pnpm-lock.yaml` (pnpm), `yarn.lock` (yarn), `Cargo.toml` (cargo), `go.mod` (go modules), `pyproject.toml` (pip/poetry/uv), `pom.xml` / `build.gradle*` (maven/gradle) | Yes |
| Docs root | Presence of `docs/` directory, `.docs/` directory, or neither | Yes |
| Existing agent guidance | Presence of `agent.md` (legacy lowercase), `AGENTS.md` (current convention), `.cursorrules`, `.windsurfrules`, `CLAUDE.md`, or `CODEX.md` | Yes |
| Test infrastructure | Directory presence of `test/`, `tests/`, `spec/`, `__tests__/`; test script entries in `package.json` scripts; `Makefile` test targets; `pytest`, `vitest`, `jest`, `rspec` config files | Yes |
| CI/CD | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `Dockerfile`, `docker-compose*.yml` | Yes |
| Existing `.opencode` config | Existence of `.opencode/opencode.json`, `.opencode/opencode.jsonc`, or `opencode.jsonc` at repo root | Yes |
| Existing `.github-project.json` | Existence of `.github-project.json` at repo root | Yes |
| App/service boundaries | Top-level directories with independent `package.json`/`go.mod`/`Cargo.toml` files (monorepo detection), `docker-compose.yml` service names, or explicit `apps/`/`services/`/`packages/` layout | No (optional) |
| Repository origin | `git remote -v` output to detect GitHub/GitLab origin and infer repo name when `--name` is not supplied | Yes |

**FR-2.3** Inspection must produce a structured evidence record (in-memory; not persisted to disk) that is consumed by the subsequent prompting and generation phases. The evidence record must distinguish "observed" facts (detected from repo) from "inferred" facts (derived heuristically, e.g., inferring "TypeScript project" from `tsconfig.json` presence) so the AGENTS.md generator can choose language carefully.

**FR-2.4** If the inspection phase encounters contradictory signals (e.g., both `go.mod` and `package.json` at repo root without clear monorepo structure), it must flag this as an ambiguity rather than silently picking one. In interactive mode, the operator must be prompted to resolve the ambiguity. In noninteractive mode, the ambiguity must be reported in stderr, the most likely interpretation used, and `AGENTS.md` must include a note that the stack inference may be incomplete.

### FR-3: AGENTS.md shaping — interactive mode

**FR-3.1** After inspection, the initializer must present the operator with a summary of detected facts and ask targeted clarification prompts. Each prompt must be grounded in specific inspection evidence or an explicit gap in detected evidence.

**FR-3.2** The minimum prompt set in interactive mode:

| Prompt | Purpose | Grounding | Default (when operator skips) |
|---|---|---|---|
| "What is the primary purpose of this repository?" | Set the `AGENTS.md` opening context | Detected stack, directory structure | `<repo-name>: a <detected-language> project` |
| "What should agents know about the working conventions here?" | Capture non-detectable conventions (branch naming, commit style, PR norms, linting, monorepo rules) | Detected CI config, linter configs | "No specific conventions recorded." |
| "Describe any build, test, or run commands agents should use." | Seed the commands section | Detected scripts/targets from package managers, Makefiles | Commands extracted from detected config (e.g., `npm test`, `cargo build`) |
| "How does this repository relate to other repos in the project?" | Populate multi-repo identity section | Detected monorepo structure, git remotes | "No related repos recorded." |
| "Where should agents store durable work-in-progress and logs?" | Define scratch/log directories | Detected `.gitignore` entries, existing `tmp/` or `scratch/` directories | `./tmp/` |
| "What is this repo\'s GitHub Project configuration?" | Populate `.github-project.json` identity fields when missing | Pre-existing `.github-project.json` | Prompt for owner, project number; use detected repo name |

**FR-3.3** Every prompt must accept a blank/empty response. A blank response must either use the documented default or omit that section from `AGENTS.md`. Prompts must never block on required answers — the initializer must be usable with minimal operator input.

**FR-3.4** After the final prompt, the initializer must display the proposed `AGENTS.md` preview and ask confirmation ("Write AGENTS.md with the above content? [Y/n]"). On confirmation, write the file. On rejection, allow the operator to re-answer prompts or abort.

### FR-4: AGENTS.md shaping — noninteractive mode

**FR-4.1** Noninteractive mode must accept the same set of inputs as CLI flags or environment variables:

| Flag | Environment variable | Maps to prompt |
|---|---|---|
| `--name` | `INIT_PROJECT_NAME` | Repository name (overrides git-remote detection) |
| `--description` | `INIT_PROJECT_DESCRIPTION` | Primary purpose |
| `--repo-role` | `INIT_PROJECT_ROLE` | Repository role (e.g., `service`, `library`, `infra`, `monorepo-root`) |
| `--related-repos` | `INIT_PROJECT_RELATED_REPOS` | Multi-repo relationships (comma-separated `name:url:relationship` triples) |
| `--worktree-root` | `INIT_PROJECT_WORKTREE_ROOT` | Issue worktree root (overrides default `~/Projects/worktree/<repo-name>`) |
| `--docs-root` | `INIT_PROJECT_DOCS_ROOT` | Documentation root directory (defaults to `docs`) |
| `--github-owner` | `INIT_PROJECT_GITHUB_OWNER` | GitHub owner for `.github-project.json` |
| `--github-project-number` | `INIT_PROJECT_GITHUB_PROJECT_NUMBER` | GitHub Project number for `.github-project.json` |
| `--conventions` | `INIT_PROJECT_CONVENTIONS` | Working conventions (newline-separated, or path to a file) |
| `--commands` | `INIT_PROJECT_COMMANDS` | Build/test/run commands (newline-separated, or path to a file) |
| `--scratch-dir` | `INIT_PROJECT_SCRATCH_DIR` | Scratch/log directory (defaults to `./tmp/`) |

**FR-4.2** When all flags are supplied and no inspection ambiguity requires human resolution, noninteractive mode must complete with zero prompts. The command must exit 0 and print a one-line confirmation.

**FR-4.3** When required noninteractive flags are missing, the command must exit 1 and print on stderr a list of which flags were missing and what they map to interactively.

### FR-5: AGENTS.md generated artifact

**FR-5.1** The generated `AGENTS.md` must be written to the repository root as `AGENTS.md` (uppercase `AGENTS`). This is the canonical path going forward.

**FR-5.2** `AGENTS.md` must contain, at minimum, the following sections. If a section has no content (no detected evidence and no operator input), it must be omitted entirely rather than emitted with placeholder text.

| Section | Content source |
|---|---|
| Repository identity | Operator input (name, description, repo role) or detected git remote |
| Project structure | Detected directory layout, app/service boundaries |
| Stack | Detected language, package manager, framework, runtime from inspection |
| Build, test, and run commands | Detected scripts/targets + operator input |
| Working conventions | Operator input; if none, omit this section |
| Repository relationships | Operator input or detected monorepo structure |
| Documentation root | Operator flag or default `docs/` |
| Scratch and log directories | Operator input or default `./tmp/` |
| GitHub Project configuration | Detected from `.github-project.json` if present, or operator input |
| Local configuration files | List of initialized config artifacts the agent should know about (`.opencode/opencode.json`, `.github-project.json`, `AGENTS.md` itself) |

**FR-5.3** `AGENTS.md` must never contain fabricated facts. Every claim in the file must be traceable to either a detected inspection signal or an explicit operator input. If the operator provided no input for a section, that section must be absent — never filled with guessed content.

**FR-5.4** `AGENTS.md` must include a generation timestamp and the version of the `init-project` script that generated it, in an HTML comment at the top of the file:
```
<!-- Generated by init-project v<version> on 2026-07-18T... — edit freely -->
```

**FR-5.5** If a pre-existing `AGENTS.md` exists at the target path, the initializer must not overwrite it by default. Interactive mode must ask whether to overwrite, merge (append new sections), or skip. Noninteractive mode must skip unless `--force` is passed. `--force` overwrites without prompting; `--force --merge` merges new sections while preserving existing content.

### FR-6: Backward-compatible migration behavior

**FR-6.1** The initializer must detect the legacy `agent.md` (lowercase) file at the repo root. When `agent.md` exists and `AGENTS.md` does not:
- Interactive mode: offer to migrate content into `AGENTS.md` with a prompt. If accepted, read relevant facts from `agent.md` (especially docs root), seed prompts with those values, and generate `AGENTS.md`. `agent.md` is left in place as a coexistence artifact.
- Noninteractive mode: treat `agent.md` as existing agent guidance (see FR-2.2) for inspection purposes; do not migrate its content unless `--migrate-agent-md` is explicitly passed.

**FR-6.2** The initializer must detect existing `.opencode/opencode.json` or `.opencode/opencode.jsonc` at the project root. When either exists:
- Add the `permission.external_directory` entry for the worktree root only if it is missing.
- Never remove or modify existing permission entries, agent definitions, provider configs, or plugin entries.
- Changing the config file extension (`.jsonc` to `.json` or vice versa) is prohibited.

**FR-6.3** The initializer must detect existing `.github-project.json` at the repo root. When it exists:
- Add `worktreeRoot` if missing.
- Add `boundaries` and `identity` fields if missing and operator supplied related inputs.
- Never remove or overwrite existing fields (`owner`, `owner_type`, `repo`, `project`, `fields`, `status_options`).
- The `worktreeRoot` default (`~/Projects/worktree/<repo-name>`) must not overwrite a pre-existing explicit value.

**FR-6.4** Rerunning `init-project` on an already-initialized repository must be idempotent: no existing artifact is destroyed, no section is silently rewritten, and the exit code is 0 with a "No changes needed" report unless `--force` is passed.

### FR-7: Required script-bearing skills copy

**FR-7.1** The initializer must copy the following three skills into the project-local `.opencode/skills/` directory from the source repository (the repo containing the init scripts):

| Skill directory | Reason | Required for operation? |
|---|---|---|
| `.opencode/skills/github-issues-projects-cli/` | Contains `scripts/gh_project_helper.sh`, the canonical GitHub Project board wrapper used by all agent prompts | Yes — all agents reference `./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh` |
| `.opencode/skills/do-task/` | Contains `scripts/create_task_worktree.sh` and `scripts/cleanup_task_worktree.sh`, needed for issue-level git worktree management during execution | Yes — builder and orchestrator depend on these scripts |
| `.opencode/skills/project-initialization/` | Contains the init scripts themselves (`scripts/init_project_docs.sh`, `scripts/setup_project_docs.sh`) and the SKILL.md definition used by agents during project initialization work | Yes — agents use this skill for initialization and re-initialization |

**FR-7.2** Skills that do not contain scripts required for project-local agent operation — specifically `skill-creator`, `webapp-testing`, `doc-coauthoring`, `frontend-design`, and all other skill directories — must not be copied. The copy scope is strictly limited to the three skills listed above.

**FR-7.3** If a target skill directory already exists under the project-local `.opencode/skills/`, the initializer must merge: copy new or updated scripts, preserve existing SKILL.md if the project has customized it. The merge rule is copy-by-file, not directory replacement — no existing local file is deleted.

**FR-7.4** The initializer must create the project-local `.opencode/skills/` directory structure if it does not exist. The `.opencode/.gitignore` entry that ignores `node_modules` must also be ensured.

### FR-8: Multi-repo identity and boundary metadata

**FR-8.1** The multi-repo identity and boundary metadata must be stored in `.github-project.json` under a new top-level key `identity` and a new top-level key `boundaries`. These fields are the single source for thin cross-repo context used by agent prompts.

**FR-8.2** The `identity` block must use the following schema:

```json
{
  "identity": {
    "name": "<repo-name>",
    "description": "<one-sentence repo purpose>",
    "role": "<service|library|infra|monorepo-root|tool|docs|other>"
  }
}
```

**FR-8.3** The `boundaries` block must use the following schema:

```json
{
  "boundaries": {
    "owns": "<what this repo is the canonical source of truth for>",
    "depends_on": [
      {
        "name": "<human-readable sibling repo name>",
        "url": "<git remote URL or file path>",
        "relationship": "<provides-data-to|consumes-data-from|deploys-alongside|docs-reference|shared-config>"
      }
    ],
    "related_repos": [
      {
        "name": "<human-readable sibling repo name>",
        "url": "<git remote URL or file path>",
        "relationship": "<sibling|parent|child|peer|external-ref>"
      }
    ]
  }
}
```

**FR-8.4** `depends_on` captures operational dependencies where this repo requires another repo to be functional. `related_repos` captures looser relationships (peer repos in the same project family, parent monorepos, reference implementations). Both arrays may be empty.

**FR-8.5** When the operator provides an empty or absent response for multi-repo relationships, `identity` must still be populated from detected repo name, and both `depends_on` and `related_repos` must be written as empty arrays (`[]`) rather than omitted. This ensures agents can detect the absence of configured relationships and do not treat missing fields as an error state.

### FR-9: Observability and diagnostics

**FR-9.1** The initializer must produce structured console output that distinguishes inspection results, operator prompts, warnings, and actions taken. At minimum:

```
[inspecting]  Detected: Node.js (npm), docs root: docs/, tests: vitest
[prompt]      What is the primary purpose of this repository?
[writing]     AGENTS.md (3 sections, 2 commands)
[writing]     .opencode/skills/ (3 skills copied, 0 merged)
[writing]     .github-project.json (identity + boundaries updated)
[summary]     Initialization complete. 4 artifacts created; 0 conflicts.
```

**FR-9.2** In noninteractive mode, the output must be compact (one line per artifact) and parseable for scripting. All warnings must go to stderr, all informative output to stdout.

**FR-9.3** When inspection detects anomalies (missing lockfiles, multiple package managers at root, existing AGENTS.md with --force), a `[warning]` line must be emitted with a specific, actionable message.

## Technical Requirements

### TR-1: Runtime environment

**TR-1.1** The initializer must run on any POSIX-compatible shell (bash ≥4.0 on Linux/macOS, and the bash environment provided by Git for Windows). No additional system packages beyond bash, `node` (≥18 for the JSON manipulation inline scripts), `git`, and coreutils (`cp`, `mkdir`, `cat`, `rm`, `mktemp`) may be required.

**TR-1.2** The `node` dependency is already present in the current init scripts (used for JSON parsing in `ensure_opencode_config` and `ensure_github_project_config`). This dependency is not new.

**TR-1.3** The initializer must complete initialization of a typical repository (≤1000 files) in under 5 seconds on local SSD. Inspection is the dominant cost; directory traversal must not recurse into `node_modules`, `.git`, `target`, `build`, `dist`, `__pycache__`, or other generated directories.

### TR-2: Idempotency

**TR-2.1** Running `init-project` N times on the same already-initialized repository must produce the same outcome as running it once, modulo the `--force` flag. No artifact count increases, no duplicate entries are appended, and the exit code is 0 with "No changes needed".

**TR-2.2** Running `init-project` N times with `--force` must produce a deterministic outcome: each rerun regenerates `AGENTS.md` from inspection + provided inputs, and the content must be identical across reruns for the same inputs and same repo state.

### TR-3: Portability

**TR-3.1** The initializer must work correctly regardless of the target repository's primary language. The inspection phase must handle repositories containing no code (bare docs/config repos) gracefully: all inspection categories return "not detected" rather than erroring.

**TR-3.2** The initializer must not depend on the target repository having any particular file structure beyond a valid git repository. Repos without `package.json`, without `Makefile`, without any build system at all must still produce a valid `AGENTS.md` from operator input alone.

### TR-4: Character encoding

**TR-4.1** All generated files must be UTF-8 with LF line endings. The `AGENTS.md` file must use Markdown format.

## Data Model Changes

### DM-1: `.github-project.json` canonical schema

The current `.github-project.json` schema is inconsistent between the two init scripts (`init_project_docs.sh` includes `worktreeRoot`; `setup_project_docs.sh` does not). This spec defines the single canonical schema. All fields with `(new)` are net-new; all other fields are pre-existing and preserved.

```json
{
  "$schema": "https://raw.githubusercontent.com/antpolis/ant-teams/main/schemas/github-project.schema.json",
  "owner": "string",
  "owner_type": "org | user",
  "repo": "string (owner/repo)",
  "project": {
    "number": "integer",
    "id": "string (GraphQL global ID, e.g. PVT_kwDO...)"
  },
  "fields": {
    "status": "string (GraphQL field ID, e.g. PVTSSF_...)"
  },
  "status_options": {
    "todo": "string",
    "in-progress": "string",
    "in-review": "string",
    "done": "string",
    "blocked": "string (optional)",
    "need-attentions": "string (optional)",
    "ready": "string (optional)",
    "ready-to-merge": "string (optional)",
    "inbox": "string (optional)",
    "shaping": "string (optional)"
  },
  "worktreeRoot": "string (absolute or ~-prefixed path)",
  "identity": {
    "name": "string",
    "description": "string",
    "role": "service | library | infra | monorepo-root | tool | docs | other"
  },
  "boundaries": {
    "owns": "string",
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
    "version": "string (init-project version)",
    "generatedAt": "string (ISO 8601 timestamp)"
  }
}
```

**Required fields** for backward compatibility and MVP correctness:

| Field | Required? | Rationale |
|---|---|---|
| `owner` | Yes | Used by `gh_project_helper.sh` for all API calls |
| `owner_type` | Yes | Required by GitHub GraphQL mutations |
| `repo` | Yes | Required by `gh_project_helper.sh` |
| `project.number` | Yes | Alternative lookup when ID is unknown |
| `project.id` | No (optional) | Preferable for GraphQL queries; can be populated later |
| `fields.status` | Yes | Required for status transitions |
| `status_options` | Yes (minimum: `todo`, `in-progress`, `in-review`, `done`) | Required for board movement; extended options are optional |
| `worktreeRoot` | Yes | Required by `create_task_worktree.sh` and all agent prompts referencing `./.github-project.json` |
| `identity` | Yes (new) | Required per spec — populated during init |
| `boundaries` | Yes (new) | Required per spec — populated with at least `owns`, empty arrays for `depends_on` and `related_repos` |
| `initMeta` | Yes (new) | Provides version traceability for migration tooling |
| `$schema` | No (optional) | Self-documentation; schema file may be created as follow-on |

**DM-1.1** The `status_options` map must support the full set of status option IDs used in the GitHub delivery flow. The required minimum set is `todo`, `in-progress`, `in-review`, `done`. Additional options (`blocked`, `need-attentions`, `ready`, `ready-to-merge`, `inbox`, `shaping`) must be accepted but are not required for MVP.

**DM-1.2** The `$schema` field points to a JSON Schema file that validates the structure. The schema file is a deferred delivery artifact (not in MVP scope) but the field must be written so future validators can consume it. The URL path must exist at the declared location before this field in any shipped `.github-project.json` references it.

**DM-1.3** The `initMeta` object records the version of `init-project` that last wrote the file and the timestamp of generation. This enables migration tooling to detect outdated configs and enables agents to reason about config freshness.

### DM-2: AGENTS.md structure

`AGENTS.md` has no formal schema; it is a Markdown file. However, the following structural rules apply:

**DM-2.1** The file must begin with an HTML comment line containing the generation metadata:
```html
<!-- Generated by init-project vX.Y.Z on YYYY-MM-DDTHH:MM:SS+ZZZZ — edit freely -->
```

**DM-2.2** Sections must use H2 headings (`##`). The standard set of possible section headings is:
- `## Repository Identity`
- `## Project Structure`
- `## Stack`
- `## Build, Test, and Run Commands`
- `## Working Conventions`
- `## Repository Relationships`
- `## Documentation`
- `## Scratch and Log Directories`
- `## GitHub Project Configuration`
- `## Local Configuration Files`

**DM-2.3** Any section with no content must be omitted from the generated file. The empty H2 heading with no body text is prohibited.

**DM-2.4** The initializer must add a `## Local Configuration Files` section listing every artifact it creates or modifies, with file paths relative to the repo root and a one-line description. This is the only section that is mandatory even when other sections are empty.

### DM-3: Project-local `.opencode/skills/` directory

**DM-3.1** The project-local `.opencode/skills/` directory follows the same structure as the source `.opencode/skills/`:

```
.opencode/skills/<skill-name>/
  SKILL.md
  scripts/
    <script>.sh
```

**DM-3.2** The `SKILL.md` file in each copied skill is the authoritative skill definition for that project-local copy. It must be identical to the source at copy time unless the project has customized it (detected by checking whether the local file already exists and differs from source).

### DM-4: Migration state tracking (deferred)

**DM-4.1** Neither the initializer nor any downstream system requires a persistent migration-state file on disk. Migration detection is derived at runtime from the presence/absence of artifacts (agent.md existing, `.github-project.json` field presence).

**DM-4.2** (Deferred) A future `initMeta.lastMigrationCheck` field in `.github-project.json` could support proactive upgrade notification, but this is out of MVP scope.

## API / CLI Changes

### CLI-1: `scripts/init-project.sh` and `scripts/init-project-docs.sh`

Both scripts remain thin delegation wrappers that pass all arguments through. No new logic is added to these wrapper files.

### CLI-2: `.opencode/skills/project-initialization/scripts/init_project_docs.sh` — flag expansion

The existing flags (`--project-dir`, `--docs-root`, `--worktree-root`, `--help`) are preserved. New flags:

| Flag | Type | Description |
|---|---|---|
| `--interactive` | Boolean (default: true when TTY, false when no TTY) | Force interactive prompting mode |
| `--noninteractive` | Boolean (default: false) | Force noninteractive mode; requires all mandatory input flags |
| `--name` | String | Repository name |
| `--description` | String | Repository primary purpose |
| `--repo-role` | String enum (`service`, `library`, `infra`, `monorepo-root`, `tool`, `docs`, `other`) | Repository role classification |
| `--related-repos` | String (comma-separated `name:url:relationship` triples) | Multi-repo relationships |
| `--github-owner` | String | GitHub owner for `.github-project.json` |
| `--github-project-number` | Integer | GitHub Project number |
| `--conventions` | String (multiline or `@/path/to/file`) | Working conventions for AGENTS.md |
| `--commands` | String (multiline or `@/path/to/file`) | Build/test/run commands for AGENTS.md |
| `--scratch-dir` | String (default: `./tmp/`) | Scratch/log directory |
| `--force` | Boolean (default: false) | Overwrite existing `AGENTS.md` and re-copy skills |
| `--merge` | Boolean (default: true in interactive, false in noninteractive) | Merge new content into existing artifacts instead of overwriting |
| `--migrate-agent-md` | Boolean (default: false) | Actively migrate legacy `agent.md` content into `AGENTS.md` (only meaningful in noninteractive mode) |
| `--skip-inspection` | Boolean (default: false) | Skip repository inspection; use only provided flags |
| `--dry-run` | Boolean (default: false) | Perform inspection and preview AGENTS.md but write nothing |

**CLI-2.1** Environment variable equivalents (see FR-4.1) take precedence over flag defaults but are overridden by explicit flags. Resolution order: default < environment variable < CLI flag.

**CLI-2.2** TTY detection for mode default: if stdout is a TTY, default to interactive; if stdout is piped or redirected, default to noninteractive. The `--interactive` and `--noninteractive` flags override the default.

**CLI-2.3** `--skip-inspection` is an escape hatch for testing and scripted re-initialization. When set, the inspection phase is skipped entirely, and only operator-provided inputs (flags or env vars) are used. `AGENTS.md` will contain only sections derived from provided inputs.

### CLI-3: `scripts/sync-company.sh` — no changes

The `sync-company.sh` script is not modified by this spec. It continues to sync the global `.opencode` install but does not participate in project-local initialization.

### CLI-4: New script `scripts/validate-project-state.sh` extension (deferred)

The existing `scripts/validate-project-state.sh` should eventually validate `AGENTS.md` and `.github-project.json` schema compliance. This is out of MVP scope.

## Security Considerations

### SEC-1: File system trust boundaries

**SEC-1.1** The initializer runs with the operator's user permissions. It must not access files outside the target project directory except to copy skills from the source repository directory. Path traversal via `--project-dir` with `../` sequences must be resolved to the canonical absolute path before any file access.

**SEC-1.2** The `--worktree-root` flag accepts an arbitrary path. The initializer must expand `~` to the operator's home directory but must not create or write inside the worktree root unless `mkdir -p` is safe (no permission escalation possible). The worktree root path is only stored in config; actual worktree creation happens later during issue execution, not during init.

**SEC-1.3** The `--related-repos` flag accepts URLs or file paths in `name:url:relationship` triples. The initializer must not attempt to fetch, open, or resolve these URLs — they are stored as opaque strings. This avoids SSRF, DNS leaks, and credential exposure.

### SEC-2: Config preservation

**SEC-2.1** The initializer must never remove, truncate, or rewrite existing permission entries in `.opencode/opencode.json`. Adding `external_directory` entries uses the existing `ensure_opencode_config` function's incremental-add behavior (which already reads, parses, checks for existing entry, and only writes if missing).

**SEC-2.2** The initializer must never log or display the contents of `.opencode/opencode.json` provider blocks (which may contain API keys, base URLs, or model names). The existing `ensure_opencode_config` function operates on the parsed JSON object in `node` without printing it to stdout.

**SEC-2.3** The initializer does not accept or process credentials of any kind. The `--github-owner` and `--github-project-number` flags store non-secret metadata. GitHub authentication is assumed to be pre-configured via `gh auth login` or `GITHUB_TOKEN` environment variable, both outside init scope.

### SEC-3: Generated file permissions

**SEC-3.1** Generated files (`AGENTS.md`, `.github-project.json`, `.opencode/opencode.json`, copied scripts) must inherit the umask of the running process. The initializer must not set explicit permissions beyond what `mkdir -p` and `cp` provide by default.

**SEC-3.2** Copied shell scripts under `.opencode/skills/*/scripts/` must preserve their execute bit from the source. The `cp` command's default behavior preserves permissions; no explicit `chmod` call is required.

## Integration Points

### INT-1: Source repository → target repository copy

**INT-1.1** The source repository is determined at script runtime: the init script resolves its own location (`$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`) to find the source `.opencode/skills/` tree. This is the existing pattern used by `init_project_docs.sh`. No separate discovery mechanism is needed.

**INT-1.2** For skills copying, the initializer must read from:
- Source skills: `$REPO_ROOT/.opencode/skills/github-issues-projects-cli/`
- Source skills: `$REPO_ROOT/.opencode/skills/do-task/`
- Source skills: `$REPO_ROOT/.opencode/skills/project-initialization/`
- Target: `$PROJECT_DIR/.opencode/skills/`

Where `$REPO_ROOT` is the init script's containing repository and `$PROJECT_DIR` is the target project directory.

### INT-2: Existing init scripts — delegation chain preserved

**INT-2.1** The delegation chain (`init-project.sh` → `init-project-docs.sh` → `project-initialization/scripts/init_project_docs.sh`) must remain intact. The behavior change is entirely inside `init_project_docs.sh`.

**INT-2.2** `setup_project_docs.sh` remains unchanged. It is a lighter-weight scaffold that only creates folder READMEs, the legacy `agent.md`, and a minimal `.github-project.json`. It is not upgraded by this spec — its functionality is subsumed by the upgraded `init_project_docs.sh` for new initializations, but it remains available for backward compatibility.

### INT-3: Agent prompt integration

**INT-3.1** All agent prompts in `.opencode/opencode.json` already reference `./.github-project.json` and `./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh` via relative paths. The new artifacts (`AGENTS.md`, expanded `.github-project.json`, project-local skills) must be readable through these existing relative paths. No agent prompt changes are required for the initialization itself — agent prompts already reference the repo root and will naturally discover the new artifacts.

**INT-3.2** The `project-initialization` skill's SKILL.md must be updated in the source repository to reflect the new AGENTS.md generation behavior and the multi-repo identity model. This spec is the trigger for that SKILL.md update, but the SKILL.md update is a documentation change, not a code change.

### INT-4: `.gitignore` considerations

**INT-4.1** The existing `.opencode/.gitignore` in the source repository ignores `node_modules`. If the target project does not have `.opencode/.gitignore`, the initializer must copy it. The generated `AGENTS.md` and `.github-project.json` are intended to be committed.

**INT-4.2** The initializer must not add entries to the repository root `.gitignore`. The `./tmp/` scratch directory (see FR-3.2) should already be ignored; if it is not, recommend adding it in `AGENTS.md` but do not modify `.gitignore`.

## Observability Requirements

### OBS-1: Console output structure

**OBS-1.1** All output must use the bracketed-prefix format defined in FR-9.1. The prefixes are:

| Prefix | Purpose | Stream |
|---|---|---|
| `[inspecting]` | Inspection phase progress and findings | stdout |
| `[prompt]` | Interactive prompt | stdout |
| `[writing]` | File creation or modification | stdout |
| `[warning]` | Non-fatal anomaly | stderr |
| `[error]` | Fatal error before abort | stderr |
| `[summary]` | Post-completion summary | stdout |

**OBS-1.2** The `[summary]` line must report: number of artifacts created, number of artifacts merged/updated, number of artifacts skipped, and number of warnings emitted.

### OBS-2: Dry-run output

**OBS-2.1** When `--dry-run` is passed, all `[inspecting]` and `[prompt]` lines behave normally. All `[writing]` lines are replaced with `[would-write]` lines. The `[summary]` line reports what would have been written. No files are created or modified.

**OBS-2.2** `[warning]` lines in dry-run mode report warnings that would apply if the run were real.

### OBS-3: Error diagnostics

**OBS-3.1** If the source repository (containing the init scripts) cannot be located, the `[error]` message must include the resolved path that was attempted and suggest running from within a source checkout.

**OBS-3.2** If `node` is not available on PATH, the `[error]` message must state the minimum version (≥18) and point to the specific function that requires it (`ensure_opencode_config`, `ensure_github_project_config`).

## Error Handling

### ERR-1: Pre-flight validation

**ERR-1.1** Before any file is written, the initializer must validate:
1. The target project directory exists and is a git repository (has `.git/`).
2. The source repository directory exists and contains `.opencode/skills/`.
3. `node` is available on PATH.
4. Required coreutils (`cp`, `mkdir`, `cat`, `rm`, `mktemp`) are available.

**ERR-1.2** If any pre-flight check fails, the command must exit 1 with a specific `[error]` message and must not have written any files.

### ERR-2: Partial-run safety

**ERR-2.1** The initializer must write all artifacts using write-to-temp-then-rename for individual files, or create files in order of increasing impact. The recommended order is:
1. Copy skills into `.opencode/skills/` (idempotent per-file merge)
2. Update or create `.opencode/opencode.json` (incremental add only)
3. Update or create `.github-project.json` (merge new fields, preserve existing)
4. Generate `AGENTS.md` (new file; interactive confirmation gate before writing)

**ERR-2.2** If the process is interrupted (SIGINT, SIGTERM) after step 1 completes, the project is in a safe partially-initialized state: skills are copied, configs are updated, but `AGENTS.md` may be absent. Rerunning `init-project` must detect this state and resume from the incomplete step. Specifically, `--force` must force regeneration of `AGENTS.md` even when skills and configs are already present; without `--force`, the merged configs must not be rewritten.

**ERR-2.3** The initializer must not leave temporary files behind. All temp files must be created under `mktemp -d` with a trap-based cleanup on EXIT.

### ERR-3: Conflict handling

**ERR-3.1** Conflicting inputs in noninteractive mode (e.g., `--repo-role library` but detected monorepo structure) must produce a `[warning]` and use the explicit flag value. The detected evidence is recorded in `AGENTS.md` as a note but does not override the explicit operator input.

**ERR-3.2** When `--force` is used and a target file exists, the existing file must be backed up to `<filename>.bak.<timestamp>` before overwriting. The backup path must be reported in a `[writing]` line.

### ERR-4: Noninteractive missing-input error

**ERR-4.1** When noninteractive mode is selected and required flags are missing, the exit code is 1 and stderr receives a message like:
```
[error] Noninteractive mode requires: --name, --github-owner, --github-project-number
[error] Missing: --github-project-number
[error] Run interactively or set INIT_PROJECT_GITHUB_PROJECT_NUMBER.
```

## Testing Strategy

### TEST-1: Unit-level tests for inspection functions

**TEST-1.1** The repository inspection logic must be isolated in a testable function (Node.js script or bash function) that accepts a target directory path and outputs a JSON evidence record to stdout. This function-specific script must be testable with fixture repositories.

**TEST-1.2** Test fixtures required:

| Fixture | Description |
|---|---|
| `fixtures/repo-node-npm/` | Node.js project with `package.json`, `package-lock.json`, `src/`, `test/`, `vitest.config.ts`, `docs/` |
| `fixtures/repo-go/` | Go project with `go.mod`, `go.sum`, `cmd/`, `internal/`, `Makefile` |
| `fixtures/repo-monorepo/` | Mono-repo with `package.json` at root and `apps/web/package.json`, `packages/shared/package.json` |
| `fixtures/repo-bare/` | No code: only `README.md`, `docs/` folder, and `.git/` |
| `fixtures/repo-legacy-init/` | Already initialized with old flow: has `agent.md` (lowercase), `.github-project.json` without `worktreeRoot`, `.opencode/opencode.json` |
| `fixtures/repo-multi-pm/` | Both `go.mod` and `package.json` at root — stack detection ambiguity |

**TEST-1.3** Each fixture must have a known expected evidence record. The test compares the function's JSON output against the expected record for `observed` fields. `inferred` fields are validated only for presence, not exact content.

### TEST-2: Integration tests for end-to-end flows

**TEST-2.1** End-to-end test cases (must run in CI or be executable locally):

| Test case | Input | Expected outcome |
|---|---|---|
| `test-e2e-interactive-bare` | Run interactive on `fixtures/repo-bare`, answer all prompts | `AGENTS.md` exists with identity + commands sections; `.github-project.json` exists with `worktreeRoot` + `identity`; 3 skills copied |
| `test-e2e-noninteractive-node` | Run noninteractive on `fixtures/repo-node-npm` with all flags | `AGENTS.md` exists; detected stack is Node.js/npm; `.opencode/opencode.json` has worktree permission; exit 0 |
| `test-e2e-noninteractive-missing` | Run noninteractive without `--github-owner` | Exit code 1; stderr lists missing flags; no files written |
| `test-e2e-idempotent` | Run init twice on `fixtures/repo-node-npm` | Second run: "No changes needed" summary; exit 0 |
| `test-e2e-legacy-migrate` | Run init on `fixtures/repo-legacy-init` with `--migrate-agent-md` | `agent.md` preserved; `AGENTS.md` created; `.github-project.json` gains `worktreeRoot` without losing existing fields |
| `test-e2e-force` | Run init with `--force` on already-initialized repo | `.bak` file created; `AGENTS.md` regenerated; skills re-copied |
| `test-e2e-dry-run` | Run with `--dry-run` | No files written; `[would-write]` lines present; exit 0 |

**TEST-2.2** Interactive-mode end-to-end tests may use `expect` (Tcl) or a Node.js-based pseudo-TTY wrapper to simulate operator input. Noninteractive tests must use plain shell scripts.

### TEST-3: Migration and backward-compatibility tests

**TEST-3.1** Test `fixtures/repo-legacy-init` specifically for:
- `agent.md` (lowercase) is never deleted
- `AGENTS.md` is created alongside `agent.md`
- `.github-project.json` keeps `owner`, `project`, `fields`, `status_options` values intact
- `.opencode/opencode.json` keeps existing permission entries intact
- Existing docs folders are not modified

**TEST-3.2** Test that running the old `setup_project_docs.sh` after running the new `init_project_docs.sh` does not damage the new artifacts. The old script should detect existing files and skip them.

### TEST-4: AGENTS.md content validation

**TEST-4.1** For each end-to-end test case that produces `AGENTS.md`, validate:
- The file begins with the `<!-- Generated by init-project` comment
- Every claim in the file can be traced to inspection evidence or operator input
- Sections with no content are absent
- The "Local Configuration Files" section lists all artifacts created
- No placeholder text (e.g., "TODO", "fill this in", "your-project-name") remains

**TEST-4.2** Implement a `scripts/validate-agents-md.sh` that checks the structural rules in DM-2. This script is part of the deliverable and must be runnable by CI and by operators post-initialization.

### TEST-5: Smoke tests on real repositories

**TEST-5.1** Before merging to main, run the upgraded initializer against this repository (`ant-teams`) in dry-run mode. Verify the output would not damage the existing initialization.

**TEST-5.2** If the founder has other candidate repos, run the same dry-run validation against a representative sample.

## Architecture Notes

### AN-1: Relationship to existing ARCH docs

**AN-1.1** ARCH-001 (skill delegation) and ARCH-002 (agent task delegation) are not affected by this spec. No new skills are added, no existing skill delegation rules change, and no agent-task invocation paths change. The initialization workflow adds new artifacts consumed by agents but does not alter agent behavior rules.

**AN-1.2** GOV-002 (master enterprise architecture) is relevant because this spec introduces project-level identity and boundary metadata. The new `identity` and `boundaries` blocks in `.github-project.json` are local project-level metadata, not enterprise architecture. They do not violate GOV-002's rule against copying master EA content into projects. No governance update is required.

### AN-2: ARCH-003 — new architecture document required

**AN-2.1** This spec is significant enough to warrant a dedicated ARCH document that captures the project-local initialization artifact architecture as a canonical technical reference. The scope covers:
- The canonical `.github-project.json` schema (the single source of truth superseding the two inconsistent versions in current scripts)
- The AGENTS.md generation contract (what promises the initializer makes to downstream agents about the content)
- The project-local skills copy model (which skills, why those three, merge rules)
- The multi-repo identity/boundary model (thin, URL-based, non-resolving)
- The backward-compatibility contract (what old artifacts are preserved, what renaming/migration occurs)

**AN-2.2** ARCH-003 must be created before the first implementation task begins. It serves as the architecture guardrail that builders and reviewers reference during implementation. The ARCH document title should be `ARCH-003-project-local-initialization-artifacts.md`.

**AN-2.3** ARCH-003 is not a restatement of this spec. It is a canonical technical reference that answers "how does an initialized repository work" for any agent reading it after initialization, and "what is the contract that any init implementation must fulfill" for any contributor modifying the init scripts.

### AN-3: KISS enforcement

**AN-3.1** The following design choices were explicitly made to satisfy KISS and must not be reversed during implementation:

| Choice | Simpler than | Rationale |
|---|---|---|
| AGENTS.md is plain Markdown, no frontmatter | YAML frontmatter + schema validation | Agents read natural language; no parser dependency |
| `.github-project.json` extended in-place, no new file | A separate `repo-identity.json` file | One config file agents already read; fewer I/O syscalls |
| Multi-repo data stored as static strings in JSON, not resolved | Live URL resolution with caching | No network dependency; no credential surface; works offline |
| Skills copied by file merge, not directory sync | rsync with source-of-truth tracking | Simpler implementation; fewer state management bugs |
| Inspection as bash+node, not a dedicated binary | Go/Rust CLI tool | No build step; runs in current environment; matches existing pattern |

**AN-3.2** The total net-new code surface is expected to be: one new inspection script (`inspect_repo.js` or equivalent bash function), AGENTS.md template assembly logic (inside `init_project_docs.sh`), and interactive prompting logic (bash `read` with default values). The skills-copy logic extends the existing `cp -Rn` pattern with per-file merge.

### AN-4: Not an ADR

**AN-4.1** The decision to adopt this initialization model is a spec-level decision (this document), not a standalone ADR. Alternative approaches were evaluated by the strategist during spec shaping. No new ADR is required.

## Acceptance Criteria At The Spec Level

Each criterion below has a stable ID for traceability to implementation tasks. All criteria must pass before this spec is considered delivered.

### AC-SPEC-001: Inspection produces valid evidence on all fixture repos

When run against each test fixture defined in TEST-1.2, the inspection function outputs valid JSON with all required categories (see FR-2.2 table). The JSON output contains no errors, no fabricated claims, and correctly marks "not detected" for absent categories.

### AC-SPEC-002: Interactive mode completes with zero manual file editing

An operator starts with a bare repository (only README.md + .git), runs `scripts/init-project.sh` interactively, answers each prompt (may accept defaults for all), and receives a complete initialized repo. The operator does not need to open a text editor to fix any generated file. Verification: run e2e test `test-e2e-interactive-bare`.

### AC-SPEC-003: Noninteractive mode completes in a single command

An operator runs:
```bash
scripts/init-project.sh --noninteractive \
  --name "my-service" \
  --description "Handles user auth" \
  --repo-role service \
  --github-owner "antpolis" \
  --github-project-number 1
```
The command exits 0, generates `AGENTS.md` with the provided values, creates `.github-project.json`, and copies required skills. No prompt appears. Verification: run e2e test `test-e2e-noninteractive-node` (adapted for explicit flags).

### AC-SPEC-004: Backward-compatible on legacy-initialized repo

Running the upgraded initializer on a repo previously initialized with the old flow:
- Does not delete `agent.md` (lowercase)
- Does not overwrite existing `owner`, `project`, `fields`, `status_options` in `.github-project.json`
- Adds `worktreeRoot`, `identity`, `boundaries`, and `initMeta` to `.github-project.json`
- Does not delete existing `.opencode/opencode.json` entries
- Creates `AGENTS.md` as a new file

Verification: run e2e test `test-e2e-legacy-migrate`.

### AC-SPEC-005: Idempotent rerun produces no changes

Run init twice on the same repo. Second run:
- Reports "No changes needed" or equivalent summary
- Does not append duplicate content to any file
- Exits 0 without modifying any file

Verification: run e2e test `test-e2e-idempotent`.

### AC-SPEC-006: AGENTS.md contains only traceable claims

For every generated `AGENTS.md` in the test suite: every factual claim maps to either a detection in the inspection phase or an explicit operator input. No section contains placeholder text ("TODO", "fill this in"). Verification: `scripts/validate-agents-md.sh` passes on all generated outputs.

### AC-SPEC-007: Required skills are copied correctly

After initialization, the target project contains:
- `.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh` with execute permission
- `.opencode/skills/do-task/scripts/create_task_worktree.sh` and `cleanup_task_worktree.sh`
- `.opencode/skills/project-initialization/scripts/init_project_docs.sh` and `setup_project_docs.sh`
- Each skill directory contains its `SKILL.md`

And does not contain any other skill directories (e.g., `skill-creator`, `webapp-testing` are absent). Verification: inspect file tree after init.

### AC-SPEC-008: `.github-project.json` conforms to canonical schema

After initialization, `.github-project.json` contains all required fields (see DM-1) and can be parsed as valid JSON by `jq '.' .github-project.json`. The `worktreeRoot` field is present and expands to a real path. The `identity.name` field matches either the git remote repo name or the `--name` flag.

### AC-SPEC-009: Dry-run writes nothing

Running with `--dry-run` on any fixture produces `[would-write]` lines but zero file changes. Verification: `git diff --exit-code` after dry-run on a git-tracked fixture.

### AC-SPEC-010: Missing noninteractive flags produce clear error

Running with `--noninteractive` and missing `--github-owner` exits 1. Stderr contains the flag name that was missing. No files are created. Verification: e2e test `test-e2e-noninteractive-missing`.

### AC-SPEC-011: Migration does not delete legacy `agent.md`

The legacy `agent.md` file created by the old `setup_project_docs.sh` survives the run. It coexists alongside the new `AGENTS.md`. Verification: file existence check after init on legacy fixture.

### AC-SPEC-012: AGENTS.md generation timestamp present

Every generated `AGENTS.md` has an HTML comment on line 1 matching `<!-- Generated by init-project v... on ... -->`. Verification: `head -1 AGENTS.md | grep -q 'Generated by init-project'`.

## Rollout And Rollback Plan

### Phase 1: Source-repo implementation (this sprint)

1. Implement the upgraded `init_project_docs.sh` in the source repository (this repo: `ant-teams`).
2. Implement the inspection script (`inspect_repo.js` or equivalent).
3. Create ARCH-003 canonical architecture document.
4. Create test fixtures and all described test cases.
5. Run dry-run validation against this repo (`ant-teams`) to verify no damage.
6. Full test suite passes.

### Phase 2: Source-repo self-initialization

1. Run the upgraded initializer against `ant-teams` itself with `--force`.
2. Verify the newly generated `AGENTS.md`, `.github-project.json`, and `.opencode/skills/` are correct for this repo.
3. Commit the updated artifacts to this repo's main branch.
4. This serves as the reference implementation — any downstream repo can diff against this repo to see expected output.

### Phase 3: Pilot rollout (1–2 candidate repos)

1. Select 1–2 real downstream repositories as pilot targets.
2. Run the upgraded initializer in interactive mode on each.
3. Hand-validate each generated `AGENTS.md` for correctness.
4. Collect operator feedback on prompt clarity and defaults.
5. Apply any prompt/UX adjustments before broad rollout.

### Phase 4: Broad availability

1. After pilot adjustments, the upgraded initializer is considered generally available.
2. The old `setup_project_docs.sh` is deprecated in documentation but left in place for backward compatibility.
3. The old `agent.md` template asset is deprecated but left in place.

### Rollback procedure

**For the source repository (`ant-teams`):** The upgrade changes only `.opencode/skills/project-initialization/scripts/init_project_docs.sh` and adds an inspection script. Rollback means reverting to the previous version of `init_project_docs.sh`. The old `setup_project_docs.sh` remains untouched and available as a fallback. Git revert is the rollback mechanism.

**For initialized target repositories:** The init creates only additive artifacts. There is no downgrade tool that removes the new artifacts, but none is needed — the new artifacts (`AGENTS.md`, expanded `.github-project.json` fields, copied skills) are backward-compatible with the old flow. An operator who wants to return to the old state can:
1. Delete `AGENTS.md` (keep `agent.md` if it existed).
2. Delete the `identity`, `boundaries`, and `initMeta` fields from `.github-project.json`.
3. Optionally delete `.opencode/skills/github-issues-projects-cli/`, `.opencode/skills/do-task/`, and `.opencode/skills/project-initialization/` if they were not previously present.
4. Rerun the old `setup_project_docs.sh` to restore legacy artifacts.

No automated downgrade script is needed for MVP. Manual rollback instructions are sufficient given the additive-only design.

### Compatibility matrix

| Scenario | Old init | Upgraded init | Outcome |
|---|---|---|---|
| Fresh repo, first init | N/A | Run upgraded init | All new artifacts created |
| Old-initialized repo, rerun old init | `setup_project_docs.sh` | N/A | Old artifacts regenerated; existing files skipped |
| Old-initialized repo, run upgraded init | Already run | Run upgraded init | New artifacts added alongside old; old artifacts preserved |
| New-initialized repo, rerun upgraded init | N/A | Run upgraded init | Idempotent; no changes (or `--force` to regenerate) |
| New-initialized repo, run old init | N/A | Already run | Old `setup_project_docs.sh` detects existing files, skips them; no damage |

## Related Documents

- `docs/gov/GOV-002-master-enterprise-architecture-reference-and-local-application.md`
- `docs/arch/ARCH-001-skill-delegation.md`
- `docs/arch/ARCH-002-agent-task-delegation.md`
- `docs/arch/ARCH-003-project-local-initialization-artifacts.md` (to be created)
- `.opencode/skills/project-initialization/SKILL.md`
- `scripts/init-project.sh`
- `scripts/init-project-docs.sh`
- `README.md`
