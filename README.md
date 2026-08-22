# ant-teams

This repo contains the agentic delivery workflow for this company: project initialization, agent skills, and the GitHub-based multi-agent delivery pipeline.

## Record Split

- GitHub Milestones are spec-level delivery containers
- GitHub Issues are the canonical execution task records
- The GitHub Project `Workflow State` field is the canonical workflow board
- GitHub issue comments and PR comments carry only final decisions, status, closure, and code-review results
- The central Obsidian project folder is the canonical full agent communication and role-memory record
- Repository docs (`docs/`) hold code-adjacent guidance: canonical specs, architecture, ADRs, GOV docs, and runbooks

## Workflow State Model

Canonical happy path:

`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`

Exception states:

- `Need attentions` — founder-only decision state, entered only after strategist and tech-lead review
- `Blocked` — exception state; any state may enter, typically `In Progress` or `In Review`

Tech-lead is the only role that merges. After merge, tech-lead owns cleanup: removing the task worktree and local branch once they are no longer needed for review, rollback, or follow-up fixes, using `scripts/cleanup-task-worktree.sh`.

## Roles

- `orchestrator` — owns queue-driven execution orchestration across the roles
- `strategist` — challenges new ideas, sharpens them into practical MVPs, prepares implementation-ready specs
- `tech-lead` — verifies technical feasibility, shapes architecture and sequencing, sets builder guardrails, owns milestones, issues, merge, and cleanup
- `builder` — implements approved work with focused code changes and verification
- `reviewer` — reviews builder output for KISS, separation-of-concerns, and placement violations, plus lightweight smoke verification

## Commands

Slash commands live in `.opencode/commands/` and are installed to `~/.config/opencode/commands`:

- `deliver` — run the full spec, architecture, planning, development, review, and validation flow
- `new-spec` — collaborative spec shaping with founder, strategist, and tech-lead, then GitHub milestone and task setup
- `sync-spec` — sync local specs and plans into GitHub milestones and task issues
- `plan-sprint` — review attention items and milestones with the founder to choose the next sprint issues
- `sprint-clean` — reconcile recent delivered work against specs, tasks, board state, and docs before sprint planning
- `do-tasks` — continue or finish existing approved tasks
- `fix-bug` — investigate and fix bugs or regressions

## Start Here

1. Sync company config with `scripts/sync-company.sh` (installs `.opencode/` to `~/.config/opencode`, repository-owned skills to `~/.agents/skills/`, and team scripts to `~/.agents/scripts`; `scripts/init-company.sh` and `scripts/update-company.sh` are aliases).
2. In a project repo, run `scripts/init-project.sh` (or the underlying `scripts/init-project-docs.sh`) to copy project docs, skills, and `AGENTS.md`, and to seed `.github-project.env`.
3. Restart opencode after any config changes.
4. Source `./.github-project.env` before GitHub API/project operations, documentation access, or worktree operations.
5. Run a delivery request with the `deliver` command, for example:

```text
opencode deliver "add user activity reporting"
```

## Environment-Only Project Config

`.github-project.env` is the sole committed project config source. It holds `ANT_TEAM_*` runtime exports seeded and updated by project initialization:

- GitHub owner, repo, project number and ID
- the canonical `Workflow State` field ID and the nine state option IDs
- the default issue-worktree root (`ANT_TEAM_WORKTREE_ROOT`; expand a literal `~` against `$HOME` before use)
- the central Obsidian vault and project documentation paths (`ANT_TEAM_DOCS_*`)

There is no `.github-project.json` and no other runtime config file. Edit the env values directly; re-running project initialization preserves values already set and only fills missing keys.

## Install Model

- `scripts/sync-company.sh` copies `.opencode/` into `~/.config/opencode` (the canonical OpenCode install), then runs `scripts/sync-managed-skills.sh`, a managed, non-destructive sync of repository-owned skills into `~/.agents/skills/`.
- `scripts/sync-company.sh` also installs the repository `scripts/` tree to `~/.agents/scripts` (exported as `ANT_TEAM_SCRIPTS`). Run `ant-team-help.sh` (from `$ANT_TEAM_SCRIPTS`, or `scripts/ant-team-help.sh` in this repo) to list every installed helper script with a one-line description.
- `scripts/init-project.sh` copies the company docs into a project repo and uses the global config; `scripts/init-project-docs.sh` is the underlying initializer and also seeds/updates `.github-project.env` and ensures `opencode.json` or `opencode.jsonc` allows access to the issue-worktree root through `permission.external_directory`.
- Project initialization sets the default issue-worktree root to `~/Projects/worktree/<repo name>`.

### Managed Skill Mirror (`~/.agents/skills`)

- The canonical target `~/.config/opencode` is repo-owned and fully replaced on each sync.
- The managed target `~/.agents/skills/` is manifest-tracked: only entries recorded in `~/.agents/skills/.manifest.json` are managed. Unmanaged sibling content is never touched.
- Locally modified managed entries are preserved with a warning by default; `--force` is the only path to overwriting them.
- `scripts/sync-managed-skills.sh --dry-run` previews planned actions without writing. There is no top-level `sync-company.sh --dry-run`.

See `docs/runbooks/RB-001-managed-skill-sync.md` for the operator runbook, and `docs/arch/ARCH-004-managed-skill-sync-architecture.md` plus `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md` for the canonical architecture and spec.

## Worktree Rule

- Prefer one dedicated git worktree per active issue so multiple tasks can run in parallel safely; create it with `scripts/create-task-branch.sh`.
- Reuse the existing issue worktree for normal continuation work.
- After the issue PR is merged or the task is explicitly abandoned, run `scripts/cleanup-task-worktree.sh` (tech-lead owns post-merge cleanup).

## Where The Workflow Lives

- `.opencode/opencode.json` — project config source used by the installer, including inline agent definitions
- `.opencode/skills/` — reusable workflow skills
- `.opencode/commands/` — slash commands for the TUI
- `.github/ISSUE_TEMPLATE/task.yml` — execution-task issue template (tech-lead owned)
- `.github-project.env` — sole committed project config source (`ANT_TEAM_*` runtime exports)
- `docs/` — code-adjacent guidance: architecture decisions, specs, runbooks, and the document index
- `scripts/` — current operational scripts (company sync, project initialization, worktree helpers, `validate-agents-md.sh`, `ant-team-help.sh`, `record-communication.sh`)

## First Useful Commands

```text
scripts/sync-company.sh
scripts/init-project.sh
opencode deliver "<your request>"
bash scripts/validate-agents-md.sh AGENTS.md
"$ANT_TEAM_SCRIPTS/ant-team-help.sh"
```
