---
name: project-initialization
description: Use whenever a repository needs to be initialized for real delivery work from existing code and changing product docs. Trigger on requests to initialize a project, set up project docs, prepare implementation-ready specs from an existing repo, understand the product from code and docs, assess the current tech stack, define agent workflow context, or plan stack migration. Always use this skill when the user wants to start work in a repo that already has code and expects the workflow to account for the current stack, target stack, and migration path.
---

# Project Initialization

Use this skill when a repository needs a serious starting point for delivery work.

This skill is for projects where the product definition may change over time, the codebase already exists, the current stack may not match the target stack, and the repo needs a clean initialization pass before execution begins.

The point is not to invent a greenfield plan from thin air. The point is to read what already exists, understand what the product is supposed to become, understand what the system currently is, and initialize the repo so future work starts from reality instead of assumptions.

## Bundled Tools

This skill includes bundled setup assets.

Use `scripts/setup_project_docs.sh [DOC_ROOT]` when the repo needs initial documentation folders for:

- ADRs
- architecture docs
- governance docs
- GitHub collaboration config

The script creates the folders and adds `README.md` guidance in each folder explaining:

- what belongs there
- when to create a document there
- file naming conventions

The script also creates `agent.md` in the repository root to tell future agents which documentation root this repository uses. The docs root is not assumed; it should match the user-specified root passed into the setup step.

The script also creates `.github-project.json` in the repository root if it does not exist. This file is meant to be committed and should store shared GitHub collaboration metadata such as owner, project number, project ID, field IDs, common status option IDs, and the issue-worktree root. Use JSON so future metadata can be stored as nested objects and arrays without inventing more env variable names.

The project initialization flow should also ensure `.github-project.json` stores the default issue worktree root as top-level field `worktreeRoot`. Unless the user asks for something else, initialize it to `~/Projects/worktree/<repo name>`.

Use `scripts/init_project_docs.sh [--project-dir PATH] [--docs-root docs] [--worktree-root PATH]` when the repo needs the full project-local workflow bootstrap, including copied docs, `.github-project.json`, and the default issue worktree root.

That same initialization flow should also ensure the repository has an `opencode.jsonc` or `opencode.json` with:

```json
{
  "permission": {
    "external_directory": {
      "<worktree root>/**": "allow"
    }
  }
}
```

If a repo config already exists, inspect it first and add the external-directory permission only when it is missing.

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
- `docs/adr/`, `docs/architecture/`, `docs/governance/`, `docs/arch/`, and related README guidance if present
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
- architecture or migration notes under `docs/architecture/`, `docs/arch/`, `docs/adr/`, or `docs/governance/` as appropriate for the repo
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
- `agent.md` pointing agents to the correct docs root
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
- `agent.md` documenting the repository docs root and document naming conventions
- `.github-project.json` documenting GitHub owner, project number, project ID, common status IDs, and top-level `worktreeRoot`
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
- `docs/gov/GOV-002-master-enterprise-architecture-reference-and-local-application.md` or the repo's equivalent local governance rule for how external enterprise architecture is applied here

## File Naming Conventions

When creating these document types, use:

- `ADR-001-short-kebab-case-title.md`
- `ARCH-001-short-kebab-case-title.md`
- `GOV-001-short-kebab-case-title.md`

Use zero-padded numbering and stable descriptive kebab-case titles.
