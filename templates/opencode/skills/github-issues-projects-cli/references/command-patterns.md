# GitHub Issues And Projects Command Patterns

Adapt these patterns to the current repo, owner, project number, and field names. Prefer the bundled helper (which resolves the repository from `.github-project.env`) over hand-written `--repo` flags whenever it is available.

For repeated GitHub issue, milestone, project, PR/review, CI/testing, release, or dual-record sync actions, prefer the bundled helper:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh"
```

That keeps prompts smaller, keeps the repository resolved from the env, and avoids repeating the same `gh api graphql` mutation shapes. Raw `gh` commands remain a fallback only for operations the helper does not cover (for example operating outside a repository with `.github-project.env`).

Important:

- GitHub issue number is not the same as GitHub Project item ID
- board status updates require the project item ID
- in this repository workflow, issues are usually auto-linked to the project, so manual linking is a fallback rather than the default

Store repo defaults in the sole committed project config source:

`./.github-project.env`

Source it instead of re-deriving config on every command:

```bash
source ./.github-project.env
# exports ANT_TEAM_GITHUB_OWNER, ANT_TEAM_GITHUB_PROJECT_NUMBER,
# ANT_TEAM_GITHUB_PROJECT_ID, ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID,
# ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_<STATE>_ID, ...
```

`.github-project.env` is seeded and updated by project initialization itself (`"$ANT_TEAM_SCRIPTS/init-project.sh"` after `scripts/init-company.sh`; there is no standalone generator and no JSON config): existing values are preserved and missing keys are filled. Edit values directly when verified remote IDs change; the bundled `gh_project_helper.sh` sources the env as its sole local runtime config.

Example `.github-project.env`:

```bash
cat > ./.github-project.env <<'EOF'
# Project runtime configuration (ANT_TEAM_* exports) — the sole committed project config source.
# Seeded and updated by init-project: existing values are preserved, missing keys are filled.
# Edit values directly; re-running init-project never overwrites a value already set here.
# Safe to commit: shared project metadata only, no secrets.

export ANT_TEAM_GITHUB_OWNER='your-github-owner'
export ANT_TEAM_GITHUB_OWNER_TYPE='org'
export ANT_TEAM_GITHUB_REPO='your-github-owner/your-repo'
export ANT_TEAM_GITHUB_PROJECT_NUMBER='1'
export ANT_TEAM_GITHUB_PROJECT_ID='PVT_kwDOEXAMPLE'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID='workflow-state-field-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_OPEN_ID='open-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_BACKLOG_ID='backlog-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_NEED_ATTENTIONS_ID='need-attentions-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_READY_ID='ready-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_IN_PROGRESS_ID='in-progress-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_IN_REVIEW_ID='in-review-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_READY_TO_MERGE_ID='ready-to-merge-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_BLOCKED_ID='blocked-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_DONE_ID='done-option-id'
EOF
```

This file is safe to commit if it only contains shared repository metadata and no secrets.

Use the sourced env IDs for stable project metadata whenever possible. This avoids spending tokens rediscovering:

- project ID
- Workflow State field and option IDs (the only board field this workflow drives)
- worktree root and documentation paths (`ANT_TEAM_WORKTREE_ROOT`, `ANT_TEAM_DOCS_*`)

## Repo Context

```bash
gh repo view --json nameWithOwner,defaultBranchRef,url
```

```bash
gh repo view OWNER/REPO --json nameWithOwner,defaultBranchRef,url
```

## Issues

Prefer the bundled helper for issue operations; it resolves the repository from `.github-project.env` (`ANT_TEAM_GITHUB_REPO`), so no `--repo` is repeated. Use raw `gh issue --repo OWNER/REPO` only outside a repository with `.github-project.env`.

Create a task issue:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-create "TASK: short task title" \
  --body-file /tmp/issue.md \
  --label type:feature \
  --assignee USERNAME \
  --milestone "SPEC-001"
```

Create a comment on an issue (final decisions, status, closure, and review outcomes only):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-comment ISSUE_NUMBER \
  --body "Status: implementation complete and verification passed; ready for review."
```

List open issues with useful collaboration fields (the helper's curated default JSON):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-list \
  --state open \
  --limit 100
```

List blocked issues in a compact table:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-list \
  --state open \
  --label blocked \
  --limit 100 \
  | jq -r '.[] | [
      "#\(.number)",
      .title,
      ((.assignees | map(.login) | join(",")) // ""),
      (.milestone.title // ""),
      .url
    ] | @tsv'
```

View one issue with the fields that usually matter for collaboration (curated default; pass `--comments` or your own `--json` to change the shape):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-view ISSUE_NUMBER
```

Edit labels, assignees, or milestone (mutate, then the helper re-reads the issue and prints `{"number", "title", "state", "url"}` with the post-edit values):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-edit ISSUE_NUMBER \
  --add-label blocked \
  --add-assignee USERNAME \
  --milestone "SPEC-001"
```

Close an issue and leave a completion note (same curated post-mutation output, `state: "CLOSED"` verified by the re-read):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-close ISSUE_NUMBER \
  --comment "Completed and validated."
```

## Milestones

The helper wraps the REST milestones API via `gh api` (there is no dedicated `gh milestone` command) and prints a curated summary.

Create a milestone that represents a spec or deliverable:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" milestone-create \
  "SPEC-001: Deliverable name" \
  "Short summary with spec link and owner"
```

List milestones (default `open`; `closed` and `all` also accepted):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" milestone-list
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" milestone-list all
```

Edit a milestone (pass-through `gh api` `-f` fields):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" milestone-edit MILESTONE_NUMBER \
  -f title="SPEC-001: Revised name" \
  -f description="Updated summary"
```

Close a milestone:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" milestone-close MILESTONE_NUMBER
```

## Projects

List projects for an owner (curated JSON array sorted by number; the owner resolves `--owner` flag → env → legacy and is never positional):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" project-list [--owner OWNER]
# [{"number":9,"title":"Ant Teams","url":"...","public":false,"closed":false,"items_count":25,"fields_count":14}]
```

View a project (curated JSON object):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" project-view PROJECT_NUMBER [--owner OWNER] [--format json]
# {"number":9,"title":"Ant Teams","url":"...","public":false,"closed":false,"items_count":25,"fields_count":14,"owner":"Antpolis"}
```

List project fields and status options (`options` appears only on single-select fields; `PROJECT_NUMBER` is validated numeric and `--format` accepts only json, both before any call):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" project-field-list PROJECT_NUMBER [--owner OWNER] [--format json]
# {"total_count":14,"fields":[{"id":"PVTF_...","name":"Title","type":"ProjectV2Field"},{"id":"PVTSSF_...","name":"Workflow State","type":"ProjectV2SingleSelectField","options":[{"name":"Inbox","id":"eb66d5a6"}]}]}
```

The Workflow State field and its option ids are simply the `Workflow State` entry of that output — use the option ids for option-id-based board filtering and status edits.

List project items (issue-linked items with REAL assignees from the ONE shared GraphQL items engine; `first:100` cursor pages follow `pageInfo` until the board is exhausted, bounded at 10 pages / 1000 items with a stderr truncation warning):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-items
# {"item_id":"PVTI_...","issue_number":37,"title":"...","state":"Ready","assignees":["chrissim"],"url":"..."}
```

Resolve the project item ID for an issue (exits non-zero naming the issue when it has no board item):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" item-id ISSUE_NUMBER
# {"item_id":"PVTI_...","issue_number":37,"title":"...","url":"...","state":"Ready"}
```

Read-only board-state recovery after a failed or interrupted status mutation (`state` is the remote option name as-is; `canonical_state` is reverse-mapped from the option id against the env-pinned canonical option IDs, `null` when unknown):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" item-state ISSUE_NUMBER
# {"item_id":"PVTI_...","issue_number":37,"title":"...","state":"Shaping","url":"...","canonical_state":"Backlog"}
```

Curated board query output contract: `set-status`, `set-status-id`, `list-items`, `list-unassigned`, and `item-id` print curated JSON objects that always carry `issue_number`, `title`, `state`, and `url` (locked by `tests/test_gh_project_helper_board_output.js`, `tests/test_gh_project_helper_board_project_queries.js`, and `tests/test_gh_project_helper_hardening.js`). The two mutators re-read the board item AFTER the edit and verify by option id, so their printed `state` is the post-edit verification value; they are idempotent (an item already in the requested state is re-verified with no duplicate mutation) and a post-edit mismatch exits non-zero — parse the output directly instead of re-querying the board:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" set-status 37 "Ready"
# {"issue_number":37,"title":"SPEC-003-T7: Local-first dual-record sync","state":"Ready","url":"https://github.com/Antpolis/ant-teams/issues/37"}

"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" item-id 37
# {"item_id":"PVTI_...","issue_number":37,"title":"...","url":"...","state":"Ready"}

"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-items "Ready"
# {"item_id":"PVTI_...","issue_number":37,"title":"...","state":"Ready","assignees":["chrissim"],"url":"..."}
```

`list-items` additionally reports `item_id` and real `assignees`; `list-unassigned` prints the same shape for zero-assignee items.

Workflow State semantics (founder-confirmed 2026-08-23): the printed `state` is the REMOTE option name preserved as-is (never translated to the canonical name), while `list-items STATE` accepts a canonical state name and filters by option id via the same env-first resolver as `set-status` — name-agnostic, so the filter stays correct under any remote display name (e.g. a legacy rename of the Backlog state). An unknown state exits non-zero with guidance.

Curated mutator output contract (locked by `tests/test_gh_project_helper_mutator_output.js`): every mutator except the two comment commands returns useful structured JSON, never raw `gh` output. `issue-create` and `pr-create` reuse the mutation's URL response and print `{"number", "title", "state", "url"}` with the deterministic `OPEN` state; `issue-edit`, `issue-close`, `pr-close`, and `pr-merge` re-read the object AFTER the mutation and print the same four-field shape, so the printed state is the post-mutation verification value; `release-create` and `release-edit` re-read and print the `release-view` shape; `release-delete` prints `{"tagName", "url", "deleted": true}`; `workflow-run` prints `{"workflow", "repo", "status": "dispatched"}`. Parse these outputs directly instead of re-querying after a mutation:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-close 42 --comment "Completed and validated."
# {"number":42,"title":"SPEC-003-followup: curated structured output","state":"CLOSED","url":"https://github.com/Antpolis/ant-teams/issues/42"}

"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" pr-merge 51 --squash
# {"number":51,"title":"SPEC-003-T1: Extend helper with PR subcommands","state":"MERGED","url":"https://github.com/Antpolis/ant-teams/pull/51"}

"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" workflow-run ci.yml --ref feat/issue-45
# {"workflow":"ci.yml","repo":"Antpolis/ant-teams","status":"dispatched"}
```

Find the project item for a specific issue number directly:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" item-id ISSUE_NUMBER
```

Show issue-linked items with status and assignees:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-items
```

Show items with no assignee:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-unassigned
```

List project items in a canonical Workflow State (e.g. `Ready`):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-items "Ready"
```

List all available Workflow State option names:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-statuses
```

List items for any one status:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-items "In Review"
```

All helper commands are env-only: owner, project number, and repository always resolve from `.github-project.env` (`ANT_TEAM_GITHUB_OWNER`, `ANT_TEAM_GITHUB_PROJECT_NUMBER`, `ANT_TEAM_GITHUB_REPO`); there are no positional owner/project arguments — the project metadata family (`project-list`/`project-view`/`project-field-list`) takes an optional `--owner` flag instead (flag → env → legacy fallback, never positional). To target a different board for the item commands, point the helper at a directory whose `.github-project.env` carries those values.

## GraphQL Lookup Patterns

Use GraphQL when the `gh project` subcommands are not enough for the intended mutation.

Project and fields lookup:

```bash
gh api graphql -f query='
query($owner: String!, $number: Int!) {
  user(login: $owner) {
    projectV2(number: $number) {
      id
      title
      fields(first: 50) {
        nodes {
          ... on ProjectV2FieldCommon {
            id
            name
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}' -F owner=OWNER -F number=PROJECT_NUMBER
```

If the owner is an organization, switch `user(login: ...)` to `organization(login: ...)`.

## Mutation Pattern: Update Project Status

Use this after discovering:

- `PROJECT_ID`
- `ITEM_ID`
- `FIELD_ID`
- `OPTION_ID`

```bash
gh api graphql -f query='
mutation($project:ID!, $item:ID!, $field:ID!, $option:String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $project
    itemId: $item
    fieldId: $field
    value: { singleSelectOptionId: $option }
  }) {
    projectV2Item {
      id
    }
  }
}' -F project=PROJECT_ID -F item=ITEM_ID -F field=FIELD_ID -F option=OPTION_ID
```

Verify after mutation by re-reading the item (the curated `item-id` output doubles as a state check; exits non-zero naming the issue when it has no board item):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" item-id ISSUE_NUMBER
```

Transition an issue to the next status using discovered IDs:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" set-status ISSUE_NUMBER "In Review"
```

The helper resolves the project item through the shared GraphQL engine before calling `gh project item-edit`, skips the mutation when the item already carries the requested option id, and verifies the post-edit state by option id (a mismatch exits non-zero with the actual board state).

For a guarded transition, `next-status` first enforces a precondition — the item must currently sit in CURRENT (matched by option id, so a legacy remote display name cannot fool it) or the command fails non-zero without mutating and points at `item-state` for recovery:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" next-status ISSUE_NUMBER "Ready" "In Progress"
```

Transient board read failures (rate limit, network) are retried a bounded number of times and then exit 3 — safe to retry later. Mutations are never retried automatically.

Direct `gh project item-edit` wrapper using repo config:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" gh-item-edit ITEM_ID "$STATUS_FIELD_ID" "$STATUS_OPTION_IN_REVIEW_ID"
```

Set status by option ID instead of by name:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" set-status-id ISSUE_NUMBER "$STATUS_OPTION_IN_REVIEW_ID"
```

When the owner is a user rather than an organization, use `user` instead of `org`:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" set-status ISSUE_NUMBER "In Review" user
```

## Pull Requests

Prefer the bundled helper for PR operations; it resolves the repository from `.github-project.env` (`ANT_TEAM_GITHUB_REPO`), so no `--repo` is repeated. Use the raw `gh` PR commands only outside a repository with `.github-project.env`.

Create a PR when the issue is ready for review:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" pr-create "ISSUE-123: short task title" \
  --base master \
  --head BRANCH_NAME \
  --body-file /tmp/pr.md
```

The first positional is the required title; every other flag passes straight through to the underlying PR-create command. Prefer `--body-file` so the PR includes task link, summary, verification, and review notes. The command prints the curated `{"number", "title", "state", "url"}` result derived from the creation response.

Comment on a PR (final decisions, status, closure, and code-review outcomes only; durable handoffs live in the central Obsidian project folder):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" pr-comment PR_NUMBER \
  --body "Ready for another review pass. I addressed the findings and reran checks."
```

View and list PRs (curated collaboration JSON by default; pass `--json`, `--jq`, `--template`, `--comments`, or `--web` to control the shape yourself):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" pr-view PR_NUMBER
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" pr-list --state open
```

`pr-merge` and `pr-close` are policy-controlled: caller flags pass through only; approval gates are never bypassed. Both mutate, re-read the PR, and print `{"number", "title", "state", "url"}` carrying the post-mutation state (`CLOSED` / `MERGED`) — the printed state is the verification, so parse it instead of re-querying.

Reply to a specific PR review comment in-thread:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" pr-review-reply COMMENT_ID "Reply message"
```

The helper posts the reply through a fixed, parameterized GraphQL mutation; user input travels only as GraphQL variables, never inside the query text. Discovering an inline review-comment node ID has no helper subcommand yet — when you need one, fall back to raw `gh api` against the pull-request review-comments endpoint for that discovery step only, or take the comment node ID from the review thread itself.

## CI And Workflow Runs

Use the bundled helper for CI/testing-loop inspection and dispatch; it resolves the repository from the env and never executes workflows' tests locally.

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" run-list --limit 10
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" run-view RUN_ID
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" workflow-list
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" workflow-run WORKFLOW_ID_OR_NAME --ref BRANCH_NAME
```

- `run-list`, `run-view`, and `workflow-list` print curated JSON by default; pass `--json`, `--jq`, `--template`, or `--web` to control the output shape yourself.
- `workflow-run` (dispatch) prints the curated dispatch summary `{"workflow", "repo", "status": "dispatched"}` — the dispatch response carries no run id, so no run read is invented; follow up with `run-list` / `run-view`. It is policy-controlled: caller flags pass through only and never bypass approval gates.

Filter failed runs for a branch (pass-through filters):

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" run-list \
  --branch BRANCH_NAME \
  --status failure \
  --limit 20
```

## Releases

Use the bundled helper for release operations; the tag is validated against the canonical Git tag rules before the underlying release command runs.

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" release-create v1.2.3 \
  --title "v1.2.3" \
  --notes-file /tmp/release-notes.md
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" release-list
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" release-view v1.2.3
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" release-edit v1.2.3 --notes-file /tmp/release-notes.md
```

`release-view` and `release-list` print curated JSON by default; pass `--json`, `--jq`, `--template`, or `--web` to control the output shape yourself. `release-create` and `release-edit` mutate, then re-read the release and print the same curated shape as `release-view` (the mutation response is only a URL, which carries no name/draft/prerelease state). `release-delete` prints `{"tagName", "url", "deleted": true}` — a deleted release is never re-read. `release-delete` is policy-controlled and destructive: caller flags pass through only and the `--yes` auto-confirm is never injected.

## Dual-Record Sync (Local Obsidian First, GitHub Second)

The mutating issue and milestone CRUD commands are local-first: `issue-create`, `issue-edit`, `issue-close`, `milestone-create`, `milestone-edit`, and `milestone-close` write the local Obsidian record under `ANT_TEAM_DOCS_PROJECT_PATH/issue/` or `.../spec/` FIRST, then synchronize it to GitHub when online.

Canonical-source rule:

| Artifact | Location | Role | Authoritative for |
|---|---|---|---|
| OpenCode implementation (helper engine, skills, commands, prompts) | `templates/opencode/` | Canonical implementation source | Helper behavior, command contracts, agent-facing guidance |
| Local Obsidian issue/spec records | `ANT_TEAM_DOCS_PROJECT_PATH/issue/` and `.../spec/` | Local-first working source (primary durable record) | Durable spec/issue text, "Local Notes", offline working copy |
| GitHub issues, milestones, project board | `Antpolis/ant-teams` | Online execution board/state (when connected) | Workflow State, closure, assignees, labels, milestone link |

Deterministic mapping: issue number → `issue/ISSUE-0NN-*.md` (frontmatter `github_number`); milestone number → `spec/SPEC-0NN-*.md` (frontmatter `github_milestone`). The "Local Notes" section and any local-only frontmatter are always preserved across writes.

Offline or on GitHub failure, the local write is kept and marked `pending_sync: true`; the command exits `3` and names the recovery command on stderr. The local write is never rolled back. Recover and converge with:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-sync ISSUE_NUMBER
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" milestone-sync MILESTONE_NUMBER
```

Both are idempotent: pending local durable content (title, body) is pushed to GitHub; GitHub execution-state fields (state/closure, labels, assignees, milestone link, URL) are pulled into the local record. On conflict (both sides changed since the last sync), durable content resolves toward the local record and execution-state toward GitHub; unresolved conflicts are reported on stderr.

Additional guarantees: read commands fall back to the local record when GitHub is unreachable and never write it; `issue-comment` and board commands stay GitHub-only; local record writes are atomic (temp file + rename), slugified, and confined to `ANT_TEAM_DOCS_PROJECT_PATH/{issue,spec}/`; the helper never runs Git commit or push on the vault and never edits `.github-project.env`.

## Reporting Patterns

Count issues by milestone:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-list --state open --limit 200 \
  --json number,milestone \
  | jq '
    group_by(.milestone.title // "No milestone")
    | map({
        milestone: (.[0].milestone.title // "No milestone"),
        count: length
      })'
```

Find issues not on any project:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-list --state open --limit 200 \
  --json number,title,projectItems,url \
  | jq '.[] | select((.projectItems | length) == 0)
    | { number, title, url }'
```

Find project items currently blocked:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" list-items "Blocked"
```
