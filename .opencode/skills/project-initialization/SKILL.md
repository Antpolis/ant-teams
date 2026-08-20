---
name: project-initialization
description: Use whenever a repository needs to be initialized for real delivery work from existing code and changing product docs. Trigger on requests to initialize a project, set up project docs, prepare implementation-ready specs from an existing repo, understand the product from code and docs, assess the current tech stack, define agent workflow context, or plan stack migration. Always use this skill when the user wants to start work in a repo that already has code and expects the workflow to account for the current stack, target stack, and migration path.
---

# Project Initialization

Use this skill when a repository needs a serious starting point for delivery work.

This skill is for projects where the product definition may change over time, the codebase already exists, the current stack may not match the target stack, and the repo needs a clean initialization pass before execution begins.

The point is not to invent a greenfield plan from thin air. The point is to read what already exists, understand what the product is supposed to become, understand what the system currently is, and initialize the repo so future work starts from reality instead of assumptions.

## Bundled Tools

This skill ships the canonical project initialization engine and the central-vault `AGENTS.md` template. Documentation-vault changes made by this workflow must be committed and pushed after verification, with unrelated changes excluded. The initializer must preserve only code-local operational guidance while routing all product documentation to the shared Obsidian vault.

### `assets/AGENTS.md.template` — central-vault project guidance

This is the canonical template for project repositories that receive an `AGENTS.md`. It must point product documentation to the Obsidian vault configured in `.github-project.json.documentation`, specifically the resolved `projectPathTemplate`, while keeping only code-adjacent operational guidance in the repository. Do not create a second product-documentation tree in the project repo.

### `scripts/init_project_docs.sh` — repository-aware bootstrap (canonical)

This is the upgraded single-command initializer (current version stamped in the script's `INIT_PROJECT_VERSION`). It is the canonical init flow for new and existing repositories. It is invoked through the thin delegation chain `scripts/init-project.sh` → `scripts/init-project-docs.sh` → this script; both wrappers are pure pass-through and add no logic.

The initializer leaves behind a project-local operating baseline derived from the actual repository plus operator inputs, not from a static template:

1. **Preflight validation** (before any write): the target directory exists and is a git repo (`.git` present), the source repo contains `.opencode/skills/`, `node` (≥18) is on PATH, and coreutils (`cp`, `mkdir`, `cat`, `rm`, `mktemp`) are available. Any failure exits 1 with a specific `[error]` message and writes nothing.

2. **`.github-project.json` extension** (canonical ARCH-003 DM-1 schema): adds `worktreeRoot`, `identity`, `boundaries`, and `initMeta` additively. Existing fields (`owner`, `owner_type`, `repo`, `project`, `fields`, `status_options`) are preserved verbatim. A pre-existing `worktreeRoot` is never overwritten. `identity.name` defaults to the detected repo name; `boundaries.depends_on` and `boundaries.related_repos` are written as `[]` when empty (never omitted) so agents can distinguish "no relationships" from "missing field". The merge is structural-idempotent: a no-op rerun leaves the file byte-for-byte identical, including the prior `initMeta.generatedAt` timestamp.

3. **`.opencode/opencode.json`** (minimal runtime config): detection covers the canonical `.opencode/opencode.json`, `.opencode/opencode.jsonc`, and legacy repo-root `opencode.jsonc` / `opencode.json`. A fresh init creates `.opencode/opencode.json`. A pre-existing config is updated in place and never relocated; only the missing `permission.external_directory["<worktree-root>/**"] = "allow"` entry is added. Existing permission entries, agents, providers, and plugins are never modified.

4. **Skills copy** (exactly three): copies `github-issues-projects-cli`, `do-task`, and `project-initialization` from the source `.opencode/skills/` into the project-local `.opencode/skills/`. No other skill is copied. Copy is a per-file merge: every source file is created when absent and preserved when already present (this protects project-customized `SKILL.md` files). Execute bits are preserved via `cp -p` from the source. `.opencode/.gitignore` with a `node_modules` entry is ensured.

5. **Central documentation routing**: does not copy or scaffold a product-documentation tree in the target repository. It reads `.github-project.json.documentation`, resolves the central Obsidian project path, and records that path in `AGENTS.md`. QA and runbook documentation are not created in the Obsidian project model by this initializer.

6. **`AGENTS.md` generation** (the final artifact, so "Local Configuration Files" can enumerate everything written): built from repository inspection plus operator inputs. See the AGENTS.md generation contract below.

### Repository inspection phase

Before prompting or writing, the initializer runs `scripts/inspect_repo.js` (read-only; never modifies the target repo). It gathers a structured evidence record (in-memory, not persisted) across these categories: language/runtime stack (lockfiles, build configs, module files), package manager, docs root (`docs/` or `.docs/`), existing agent guidance (`agent.md`, `AGENTS.md`, `.cursorrules`, `.windsurfrules`, `CLAUDE.md`, `CODEX.md`), test infrastructure (test dirs + framework configs), CI/CD (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `Dockerfile`, `docker-compose*.yml`), existing `.opencode` config, existing `.github-project.json`, app/service boundaries (monorepo detection), and repository origin (`git remote -v`). The record distinguishes `observed` facts from `inferred` facts and flags ambiguities (e.g., both `go.mod` and `package.json` at root). `--skip-inspection` skips this phase entirely. If inspection fails, `AGENTS.md` is still built from operator input alone.

### AGENTS.md generation

`AGENTS.md` is plain Markdown written to the repo root (uppercase `AGENTS.md`), in the style of Codex/Claude init. Two modes are supported:

- **Interactive mode** (default when stdout is a TTY): runs a 6-prompt flow — primary purpose, working conventions, build/test/run commands, repository relationships, scratch/log directory, and GitHub Project configuration. Each prompt accepts a blank response (blank falls back to a detected default or omits the section), shows a preview, and asks Y/n confirmation before writing.
- **Noninteractive mode** (default when stdout is not a TTY, or `--noninteractive`): all inputs come from CLI flags or env vars. Requires `--name`, `--github-owner`, and `--github-project-number`; missing values exit 1 with a clear `[error]` listing the missing flags. Completes with zero prompts.

Every section in the generated `AGENTS.md` is traceable to inspection evidence or operator input — no fabricated claims. Empty sections are omitted entirely (no placeholder headings). The mandatory `## Local Configuration Files` section lists every artifact written. Line 1 carries `<!-- Generated by init-project v<version> on <ISO 8601> — edit freely -->`. A pre-existing `AGENTS.md` is never overwritten by default: interactive mode offers overwrite/merge/skip; noninteractive mode skips unless `--force` (which backs up the old file to `<name>.bak.<timestamp>` first). `--force --merge` appends new H2 sections not already present.

### CLI flags and environment variables

Every flag has an `INIT_PROJECT_*` env-var equivalent (uppercase, dashes → underscores). Resolution order is `default < env < CLI flag`, so explicit flags always win.

- Mode: `--interactive` / `--noninteractive` (default: TTY-driven).
- Repository identity: `--name`, `--description`, `--repo-role` (enum: `service | library | infra | monorepo-root | tool | docs | other`), `--related-repos` (comma-separated `name:url:relationship` triples; url is opaque and stored as-is, never fetched).
- GitHub Project: `--github-owner`, `--github-project-number` (positive integer).
- AGENTS.md shaping: `--conventions` (text or `@file`), `--commands` (text or `@file`), `--scratch-dir` (default `./tmp/`).
- Behavior modifiers: `--force`, `--merge` (default: interactive=on, noninteractive=off), `--migrate-agent-md`, `--skip-inspection`, `--dry-run`.
- Pre-existing (preserved): `--project-dir`, `--docs-root`, `--worktree-root`, `-h`/`--help`.

### Multi-repo identity and boundary metadata

`.github-project.json` gains a thin, static, non-resolving identity layer: `identity` (`name`, `description`, `role`) and `boundaries` (`owns`, `depends_on[]`, `related_repos[]`). URLs and paths are stored as opaque strings — the initializer never fetches, resolves, or opens them. This is enough for agents to understand what repo they are in and how it relates to siblings without creating a second architecture system. See ARCH-003 for the full schema and consumption rules.

### Backward-compatible migration behavior

The initializer is strictly additive and never destructive:

- Legacy lowercase `agent.md` is never deleted; it coexists with `AGENTS.md`. Content may be migrated only when `--migrate-agent-md` is passed (noninteractive).
- Existing `.github-project.json`, `.opencode/opencode.json` / `.jsonc`, docs folders, and project-local custom skills are preserved verbatim; only missing fields/files are added.
- Reruns are idempotent: a no-op rerun reports "No changes needed" and writes nothing. `--force` regenerates `AGENTS.md` and re-copies skills, but a `--force` rerun with identical inputs leaves `AGENTS.md` byte-for-byte intact (content-level idempotency).
- `setup_project_docs.sh` remains available as a deprecated lighter-weight scaffold that only creates folder READMEs, the legacy `agent.md`, and a minimal `.github-project.json`. It is not upgraded; new initializations should use `init_project_docs.sh`. The `assets/agent-md-template.md` template is likewise deprecated (it carries a deprecation notice and is no longer used for `AGENTS.md` generation).

### Output format and error handling

Console output uses structured prefixes so agents can parse it: `[inspecting]`, `[prompt]`, `[writing]`, `[warning]` (stderr), `[error]` (stderr), `[summary]`. In noninteractive mode output is compact (one line per artifact); warnings go to stderr, informative output to stdout. `--dry-run` resolves and validates everything but replaces every `[writing]` with `[would-write]` and writes zero files. All generated files are written atomically (write-temp-then-rename in the same directory); a trap cleans up every scratch file on EXIT/INT/TERM, so an interrupted run leaves no partial state behind.

The skill also includes reference templates under `references/` for:

- ADR documents
- architecture documents
- governance documents

## Goals

- understand the current product from documentation and code
- understand the current implementation and tech stack from the repository
- identify the target or intended product direction
- identify the current stack, the desired stack, and the migration implications
- initialize repository delivery artifacts so later agents can execute with less ambiguity
- align project docs, workflow docs, and task planning with the actual codebase

## When To Use

Use this skill whenever the user asks to:

- initialize a project in a repo
- set up a project from existing docs and code
- prepare specs or delivery docs from an existing product/codebase
- start a migration-aware implementation plan
- bootstrap a repo for multi-agent delivery
- understand a product and stack before planning work

This skill is especially important when:

- the repo already contains partial or legacy implementation
- the product docs and the code may be out of sync
- the target stack differs from the current stack
- the user expects migration planning to be part of initialization

## Required Discovery Order

Do not start by writing the spec.

Read and inspect in this order:

1. product or business docs
2. implementation and technical docs
3. repo structure and key source directories
4. stack indicators such as package managers, framework configs, build files, Docker files, CI files, and deployment manifests
5. existing workflow docs, agent config, and project-management artifacts
6. existing architecture, ADR, and governance folders if they already exist
7. local governance rules that explain how this repo uses any external master enterprise architecture, such as `GOV-002`

If the repo includes current agent definitions, read them. Do not assume the agent set is fixed forever.

## What To Read

Read only what is needed, but be deliberate.

Look for:

- product specs
- feature lists
- implementation guides
- technical architecture docs
- backend or frontend structure docs
- README files
- `package.json`, `pnpm-lock.yaml`, `yarn.lock`, `pom.xml`, `build.gradle*`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `requirements.txt`
- Docker, Compose, Helm, Terraform, k8s, CI, and deployment files
- `.opencode/opencode.json` and relevant workflow skills if present
- the central Obsidian project documentation path resolved from `.github-project.json`
- governance docs that explain master-enterprise-architecture usage, mirroring rules, or local ADR/ARCH/GOV routing

## Core Principle

Initialize from reality, not wishful thinking.

If the product docs say one thing and the code says another, surface the mismatch explicitly.
If the current stack and target stack differ, treat that as first-class planning input, not a side note.

## Required Outputs

Produce or update these as appropriate for the repo:

- a project understanding summary
- a product understanding summary
- a current-state implementation and tech-stack summary
- a current-vs-target stack migration section
- initialization recommendations for docs, specs, tasks, and workflow setup
- a concrete next-step plan for execution

When editing repository artifacts, prefer:

- product or enhancement spec under `docs/spec/` or the repo's existing convention
- architecture or migration notes under the central Obsidian project path
- GitHub milestones, issues, project fields, and issue templates for collaboration artifacts
- `.github-project.json` for repo-level GitHub collaboration defaults, including top-level `worktreeRoot`
- `opencode.json` or `opencode.jsonc` for repo-level runtime permissions including worktree access

## Mandatory Analysis Sections

Every initialization pass must include these sections, even if brief.

### 1. Product Understanding

Summarize:

- what the product is
- who it serves
- what the current business direction is
- what the implemented scope appears to be
- what major gaps or contradictions exist between product intent and implementation

### 2. Codebase Understanding

Summarize:

- repo structure
- major apps or services
- current architectural shape
- operational dependencies
- notable technical debt or partial migrations already in progress

### 3. Current Stack

Summarize the actual current stack observed in the repo, such as:

- frontend framework
- backend framework
- language runtime
- auth
- data store
- realtime transport
- deployment system
- testing/build tooling

Do not guess if evidence is missing. State what was observed.

### 4. Target Stack Or Direction

Infer or document the target stack or direction from product docs, implementation docs, migration docs, and repo evidence.

If the user has not defined a target stack clearly, say so and describe the most likely current direction based on evidence.

### 5. Stack Migration

This section is required every time.

Include:

- current stack
- target stack
- migration already completed
- migration still incomplete
- compatibility or parity constraints
- risky migration areas
- recommended migration sequence
- what work should be treated as migration work versus net-new feature work

If there is no stack migration underway, explicitly say that and confirm whether the current stack should be treated as the stable target stack.

### 6. Workflow Initialization

Decide what workflow artifacts should exist or be updated, such as:

- main project spec
- architecture or migration doc
- ADR folder, architecture folder, and governance folder scaffolding
- local governance reference to the master enterprise architecture if this repo depends on an external authoritative source
- `AGENTS.md` (generated by `init_project_docs.sh`) pointing agents to the docs root, stack, commands, and repo identity; legacy lowercase `agent.md` is a deprecated fallback only
- GitHub milestone and issue conventions
- `.github-project.json` with repo GitHub owner, project identifiers, common field/option IDs, and top-level `worktreeRoot`
- role or agent handoff guidance

Read current agent definitions if they exist, but keep the workflow flexible enough that the agent roster can change.

If a local governance document already explains how this repo relates to a master enterprise architecture, use that document as the routing rule for:

- what should remain external
- what should be mirrored locally
- when to create local `GOV`, `ARCH`, or `ADR` docs

## Behavior Rules

- read the codebase before making architecture claims
- read product docs before writing product claims
- treat migration as a first-class workstream, not a footnote
- distinguish implemented reality from intended future state
- avoid pretending the code already matches the docs when it does not
- do not create tasks until the current state and migration implications are clear enough
- if the repo already has project-management conventions, extend them instead of replacing them casually
- if ADR, architecture, or governance folders are missing and the repo needs them, create them with the bundled setup script before relying on them
- if `.github-project.json` is missing and the repo uses GitHub Issues or Projects for collaboration, create it during initialization before relying on GitHub workflow automation
- if the repo has a governance doc such as `GOV-002` that defines how to use an external master enterprise architecture, follow it before creating local architecture-principle or governance material

## Recommended Deliverables

Depending on the repo state, create or update some combination of:

- repository initialization spec
- architecture current-state note
- stack migration note or ADR
- ADR, architecture, and governance folder scaffolding with README guidance
- local governance note or update confirming how the external master enterprise architecture applies to this repo when needed
- `AGENTS.md` documenting the repository docs root, stack, commands, conventions, and document naming conventions (the bundled `init_project_docs.sh` generates this; legacy `agent.md` is deprecated)
- `.github-project.json` documenting GitHub owner, project number, project ID, common status IDs, `worktreeRoot`, and the multi-repo `identity`/`boundaries`/`initMeta` blocks
- first milestone/spec definition
- first GitHub task breakdown
- workflow setup notes for agents and handoffs

## Output Format

Use this structure when reporting initialization findings:

```md
# Project Initialization Summary

## Product Understanding
- ...

## Codebase Understanding
- ...

## Current Stack
- ...

## Target Stack Or Direction
- ...

## Stack Migration
- Current stack:
- Target stack:
- Completed migration:
- Remaining migration:
- Risks:
- Recommended sequence:

## Recommended Repo Artifacts
- ...

## Recommended Next Steps
- ...
```

## Example Situations

**Example 1:**
Input: "Initialize this repo for delivery work. Read the docs and code first."
Output: repo understanding, product understanding, stack summary, migration section, and recommended spec/task initialization

**Example 2:**
Input: "Set up this migrated app project so future agents can deliver features safely."
Output: current-vs-target stack analysis, migration gaps, workflow initialization plan, and first delivery artifacts

**Example 3:**
Input: "Initialize this repo, but the master enterprise architecture is maintained outside the repo."
Output: repo understanding, stack migration analysis, check for local governance rules such as `GOV-002`, and local docs that apply the external architecture without duplicating it blindly

## Good Judgment Notes

- If the repo is mid-migration, do not frame everything as ordinary feature work.
- If old and new stacks coexist, document coexistence boundaries clearly.
- If the final product direction has shifted from older docs, say which documents look authoritative and which look stale.
- If workflow setup is missing, initialize the minimal useful set first instead of generating a huge governance pile.
- If the repository depends on a master enterprise architecture outside the repo, prefer local application and traceability docs over copying the full enterprise architecture into the project blindly.

## Related Skills

Use these when relevant:

- `product-shaping` for tightening evolving product direction
- `documentation-standard` for creating or updating repo docs
- `github-agentic-delivery-flow` for top-level GitHub workflow structure
- `github-conventions` for milestone, issue, and comment mapping
- `state-transitions` for workflow states
- `approval-or-escalation` for review and escalation rules
- `agentic-flow-terms` for shared workflow vocabulary
- central Obsidian vault governance notes and `.github-project.json`

## File Naming Conventions

When creating these document types, use:

- `ADR-001-short-kebab-case-title.md`
- `ARCH-001-short-kebab-case-title.md`
- `GOV-001-short-kebab-case-title.md`

Use zero-padded numbering and stable descriptive kebab-case titles.
