# ant-teams

This repo contains the agentic delivery workflow for this company: project initialization, agent skills, and the GitHub-based multi-agent delivery pipeline.

## Record Split

- GitHub Milestones are spec-level delivery containers
- GitHub Issues are the canonical execution task records
- The GitHub Project `Workflow State` field is the canonical workflow board
- GitHub issue comments and PR comments carry only final decisions, status, closure, and code-review results
- The central Obsidian project folder is the canonical documentation, full agent communication, and role-memory record

## Workflow State Model

Canonical happy path:

`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`

Exception states:

- `Need attentions` — founder-only decision state, entered only after strategist and tech-lead review
- `Blocked` — exception state; any state may enter, typically `In Progress` or `In Review`

Tech-lead is the only role that merges. After merge, tech-lead owns cleanup: removing the task worktree and local branch once they are no longer needed for review, rollback, or follow-up fixes, using `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh`.

## Roles

- `orchestrator` — owns queue-driven execution orchestration across the roles
- `strategist` — challenges new ideas, sharpens them into practical MVPs, prepares implementation-ready specs
- `tech-lead` — verifies technical feasibility, shapes architecture and sequencing, sets builder guardrails, owns milestones, issues, merge, and cleanup
- `builder` — implements approved work with focused code changes and verification
- `reviewer` — reviews builder output for KISS, separation-of-concerns, and placement violations, plus lightweight smoke verification

## Commands

Slash command sources live in `templates/opencode/commands/` and are installed to `.opencode/commands/` and `~/.config/opencode/commands`:

- `deliver` — run the full spec, architecture, planning, development, review, and validation flow
- `new-spec` — collaborative spec shaping with founder, strategist, and tech-lead, then GitHub milestone and task setup
- `sync-spec` — sync Obsidian specs and plans into GitHub milestones and task issues
- `plan-sprint` — review attention items and milestones with the founder to choose the next sprint issues
- `sprint-clean` — reconcile recent delivered work against specs, tasks, board state, and docs before sprint planning
- `do-tasks` — continue or finish existing approved tasks
- `fix-bug` — investigate and fix bugs or regressions

## Start Here

1. Sync company config with `scripts/init-company.sh` (installs `templates/opencode/` to `.opencode/` and `~/.config/opencode`, repository-owned skills to `~/.agents/skills/`, and team scripts to `~/.agents/scripts`).
2. In a project repo, run `"$ANT_TEAM_SCRIPTS/init-project.sh"` to initialize the local agent runtime and seed `.github-project.env`.
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

`.github-project.env` is the runtime configuration source. Edit its values directly; re-running project initialization preserves values already set and only fills missing keys.

## Install Model

- `scripts/init-company.sh` copies `templates/opencode/` into `.opencode/` and `~/.config/opencode`, then runs `scripts/sync-managed-skills.sh --force` (always): a company install is an operator-initiated refresh, so locally modified managed entries in `~/.agents/skills/` are replaced from source. `--reset` first moves `~/.config/opencode`, `~/.agents/skills`, and `~/.agents/scripts` aside to `.bak.<UTC timestamp>` directories and reinstalls from scratch; `--force` is accepted as a deprecated no-op.
- `scripts/init-company.sh` also installs the canonical `templates/scripts/` tree to `~/.agents/scripts` (exported as `ANT_TEAM_SCRIPTS`). Run `ant-team-help.sh` (from `$ANT_TEAM_SCRIPTS`, or `templates/scripts/ant-team-help.sh` in this repo) to list every installed helper script with a one-line description.
- `$ANT_TEAM_SCRIPTS/init-project.sh` initializes a project-local agent runtime, seeds or updates `.github-project.env`, and ensures `opencode.json` or `opencode.jsonc` allows access to the issue-worktree root through `permission.external_directory`.
- Project initialization sets the default issue-worktree root to `~/Projects/worktree/<repo name>`.

### Managed Skill Mirror (`~/.agents/skills`)

- The canonical target `~/.config/opencode` is repo-owned and fully replaced on each sync.
- The managed target `~/.agents/skills/` is manifest-tracked: only entries recorded in `~/.agents/skills/.manifest.json` are managed. Unmanaged sibling content is never touched.
- Standalone `scripts/sync-managed-skills.sh` (no flags) is the non-destructive path: locally modified managed entries are preserved with a warning; `--force` overwrites them. Through `init-company.sh` the sync always runs forced.
- `scripts/sync-managed-skills.sh --dry-run` previews planned actions without writing. There is no top-level `init-company.sh --dry-run`.

See the central Obsidian project folder for the managed-skill sync runbook, architecture, and specification.

## Worktree Rule

- Prefer one dedicated git worktree per active issue so multiple tasks can run in parallel safely; create it with `"$ANT_TEAM_SCRIPTS/create-task-branch.sh"`.
- Reuse the existing issue worktree for normal continuation work.
- After the issue PR is merged or the task is explicitly abandoned, run `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh` (tech-lead owns post-merge cleanup).

## Where The Workflow Lives

- `templates/opencode/` — canonical editable OpenCode configuration, skills, and command source
- `.opencode/` — generated local OpenCode runtime; recreate it with `scripts/init-company.sh`
- `templates/scripts/` — canonical editable team-script source installed to `~/.agents/scripts` (`ant-team-help.sh`, `record-communication.sh`, worktree helpers, `validate-agents-md.sh`)
- `.github/ISSUE_TEMPLATE/task.yml` — execution-task issue template (tech-lead owned)
- `.github-project.env` — sole committed project config source (`ANT_TEAM_*` runtime exports)
- The central Obsidian project folder — canonical product, architecture, governance, runbook, and project documentation
- `scripts/` — company installation and managed-skill synchronization entrypoints

## First Useful Commands

```text
scripts/init-company.sh
"$ANT_TEAM_SCRIPTS/init-project.sh"
opencode deliver "<your request>"
bash templates/scripts/validate-agents-md.sh AGENTS.md
"$ANT_TEAM_SCRIPTS/ant-team-help.sh"
```
