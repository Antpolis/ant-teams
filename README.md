# one-person-company

This repo contains the agentic delivery workflow for this company.

The workflow is GitHub-first and GitHub-only for task execution:

- repository docs hold the canonical spec and architecture guidance
- GitHub Milestones hold spec-level tracking
- GitHub Issues are the canonical task records
- GitHub Project status is the canonical workflow board
- GitHub issue comments and PR comments are the canonical handoff and review log

## Start Here

1. Sync company config with `scripts/sync-company.sh`.
2. If you want only project docs plus global config, run `scripts/init-project.sh` in the project repo.
3. `scripts/init-company.sh` and `scripts/update-company.sh` are aliases to `scripts/sync-company.sh`.
4. Restart opencode after any config changes.
5. Run a delivery request with the `deliver` command.

## Install Model

- `scripts/sync-company.sh` copies `.opencode/` into `~/.config/opencode` by default.
- `scripts/init-company.sh` and `scripts/update-company.sh` both run `scripts/sync-company.sh`.
- The global install at `~/.config/opencode` includes `tools/`, `skills/`, `plugins/`, `scripts/`, `docs/`, and `opencode.json`.
- `scripts/init-project.sh` copies the company docs into a project repo and uses the global config.
- `scripts/init-project-docs.sh` is the underlying project docs initializer.
- `scripts/init-project-docs.sh` also ensures `.github-project.json` stores the default issue-worktree root.
- `scripts/init-project-docs.sh` also ensures `opencode.json` or `opencode.jsonc` allows access to the issue-worktree root through `permission.external_directory`.
- `scripts/update-company.sh` refreshes the installed company config from this source tree.
- `.opencode/commands/` holds the slash commands and is copied to `~/.config/opencode/commands`.
- Project docs are local overrides for repo-specific architecture and workflow state.
- Global docs act as enterprise defaults.
- Project docs override global architecture guidance when both exist.
- When using the global workflow scripts for a project, run them from the project repo and set `DOC_ROOT=docs` (or `DOC_ROOT=.docs`) so they target the local project tree.
- Project initialization sets the default issue-worktree root to `~/Projects/worktree/<repo name>`.

Example:

```text
opencode deliver "add user activity reporting"
```

## What It Does

The workflow runs through:

- product owner research and spec writing
- CPO review
- CTO review
- architecture review
- task planning
- implementation
- code review
- QA smoke

## Work Modes

### 1. Start a New Spec

Use this when the request changes product direction, architecture, or scope.

```text
opencode create-spec "<new request>"
```

### Command Shortcuts


- `create-spec` for a new spec
- `deliver` for a new spec plus the full downstream workflow
- `do-tasks` for continuing an existing approved task or finishing the remaining work
- `fix-bug` for a regression, defect, or unexpected failure
- `migrate` for converting legacy specs into the current project-management format

Defaults:

- `/create-spec` -> `product-owner`
- `/deliver` -> `product-owner`
- `/do-tasks` -> `developer`
- `/fix-bug` -> `developer`
- `/migrate` -> `delivery-manager`

These are also available in the TUI as `/create-spec`, `/deliver`, `/do-tasks`, `/fix-bug`, and `/migrate`.

### Scripts By Role

- `product-owner`: `scripts/create-spec.sh`, `scripts/create-spec-tasks.sh`
- `delivery-manager`: `scripts/create-task.sh`, `scripts/create-task-branch.sh`, `scripts/list-tasks.sh`, `scripts/update-task-status.sh`
- `developer`: `scripts/create-task-branch.sh`, `scripts/cleanup-task-worktree.sh`, `scripts/record-pr.sh`, `scripts/record-review-result.sh`
- `architect`: `scripts/record-loop-breaker.sh`, `scripts/create-defer-task.sh`, `scripts/close-task.sh`
- `qa-smoke`: `scripts/record-qa-smoke.sh`
- `workflow roles`: `scripts/update-document-index.sh`, `scripts/update-task-owner.sh`, `scripts/add-task-dependency.sh`, `scripts/record-merge.sh`, `scripts/record-pr-comment.sh`

Examples:

```text
opencode create-spec "add user activity reporting"
opencode do-tasks "TASK-014"
opencode fix-bug "login fails after deploy"
```

### 2. Start On An Existing Task

Use this when the spec already exists and the work is already split into tasks.

- Open the GitHub issue for the task
- Read the linked spec, relevant docs, issue comments, and PR discussion
- Continue in the existing issue worktree and on the existing task branch
- Update the GitHub Project status and GitHub handoff notes as you work

### 3. Continue A Task

Use this when you already started work and need to keep going on the same task.

- Stay on the same task branch
- Stay in the same issue worktree
- Keep the GitHub Project status updated
- Add new notes to the GitHub issue or PR

### Worktree Rule

- Prefer one dedicated git worktree per active issue so multiple tasks can run in parallel safely.
- Reuse the existing issue worktree for normal continuation work.
- After the issue PR is merged or the task is explicitly abandoned, run `scripts/cleanup-task-worktree.sh` to remove the no-longer-needed worktree and local branch.

### 4. Bug Found

Use this when you find a regression or defect.

- If it belongs to the current approved spec, add it to the existing GitHub task issue if it is in scope
- If it changes scope or needs separate handling, create a new bug spec and GitHub task issue
- If it blocks the current work, record it as a blocker in GitHub

## Where The Workflow Lives

- `.opencode/opencode.json` - project config source used by the installer, including inline agent definitions and config
- `.opencode/tools/` - TypeScript custom tools for workflow scripts (one file per tool)
- `.opencode/skills/` - reusable workflow skills
- `.opencode/plugins/` - config-time plugins
- `.opencode/commands/` - slash commands for the TUI
- `docs/` - architecture decisions and project-management docs
- `scripts/` - workflow automation

## Project Management Files

- `docs/DOCUMENT_INDEX.md` - document index
- `docs/arch/ARCH-001-skill-delegation.md` - skill delegation policy
- `.github-project.json` - repository GitHub Project metadata used by the workflow
- `docs/` - canonical specs, architecture, ADRs, GOV docs, and related repository guidance linked from GitHub workflow artifacts

## Working Rule

Use GitHub issues, milestones, project status, and PR comments as the operational workflow surface. Use repository docs for canonical specs and guidance, not as the task board or handoff log.

## First Useful Commands

```text
scripts/init-company.sh
scripts/init-project.sh
scripts/init-project-docs.sh
scripts/update-company.sh
opencode deliver "<your request>"
scripts/list-tasks.sh
scripts/validate-project-state.sh
```
