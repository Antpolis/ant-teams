# GitHub Issues And Projects Command Patterns

Adapt these patterns to the current repo, owner, project number, and field names. Prefer the bundled helper (which resolves the repository from `.github-project.env`) over hand-written `--repo` flags whenever it is available.

For repeated GitHub issue, milestone, or project actions, prefer the bundled helper:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh"
```

That keeps prompts smaller, keeps the repository resolved from the env, and avoids repeating the same `gh api graphql` mutation shapes.

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

Edit labels, assignees, or milestone:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" issue-edit ISSUE_NUMBER \
  --add-label blocked \
  --add-assignee USERNAME \
  --milestone "SPEC-001"
```

Close an issue and leave a completion note:

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

List projects for an owner:

```bash
gh project list --owner OWNER
```

View a project:

```bash
gh project view PROJECT_NUMBER --owner OWNER --format json
```

List project fields and status options:

```bash
gh project field-list PROJECT_NUMBER --owner OWNER --format json
```

Extract the canonical Workflow State field and option IDs:

```bash
gh project field-list PROJECT_NUMBER --owner OWNER --format json \
  | jq '.fields[]
    | select(.name == "Workflow State")
    | {
        field_id: .id,
        options: [
          .options[] | { name, id }
        ]
      }'
```

List project items:

```bash
gh project item-list PROJECT_NUMBER --owner OWNER --format json
```

Resolve the project item ID for an issue:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" item-id ISSUE_NUMBER
```

Find the project item for a specific issue number directly:

```bash
ISSUE_NUMBER=42
gh project item-list PROJECT_NUMBER --owner OWNER --format json \
  | jq --argjson n "$ISSUE_NUMBER" '.items[]
    | select(.content.number == $n)
    | {
        item_id: .id,
        title: .content.title,
        issue_number: .content.number,
        url: .content.url
      }'
```

Show issue-linked items with status and assignees:

```bash
gh project item-list PROJECT_NUMBER --owner OWNER --format json \
  | jq '.items[]
    | {
        item_id: .id,
        title: (.content.title // .title // ""),
        issue_number: (.content.number // null),
        url: (.content.url // ""),
        assignees: ((.content.assignees // []) | map(.login)),
        state: (.["workflow State"] // "")
      }'
```

Show items with no assignee:

```bash
gh project item-list PROJECT_NUMBER --owner OWNER --format json \
  | jq '.items[]
    | select(((.content.assignees // []) | length) == 0)
    | {
        title: (.content.title // ""),
        issue_number: (.content.number // null),
        state: (.["workflow State"] // ""),
        url: (.content.url // "")
      }'
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

All helper commands are env-only: owner, project number, and repository always resolve from `.github-project.env` (`ANT_TEAM_GITHUB_OWNER`, `ANT_TEAM_GITHUB_PROJECT_NUMBER`, `ANT_TEAM_GITHUB_REPO`); there are no positional owner/project arguments. To target a different owner or project for one call, point the helper at a directory whose `.github-project.env` carries those values.

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

Verify after mutation by re-listing the item:

```bash
gh project item-list PROJECT_NUMBER --owner OWNER --format json \
  | jq --argjson n "$ISSUE_NUMBER" '.items[]
    | select(.content.number == $n)
    | {
        issue_number: .content.number,
        title: .content.title,
        state: (.["workflow State"] // "")
      }'
```

Transition an issue to the next status using discovered IDs:

```bash
"$ANT_TEAM_SCRIPTS/gh_project_helper.sh" set-status ISSUE_NUMBER "In Review"
```

The helper resolves the project item ID from the issue number before calling `gh project item-edit`.

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

Create a PR when the issue is ready for review:

```bash
gh pr create --repo OWNER/REPO \
  --base main \
  --head BRANCH_NAME \
  --title "ISSUE-123: short task title" \
  --body-file /tmp/pr.md
```

Comment on a PR:

```bash
gh pr comment PR_NUMBER --repo OWNER/REPO \
  --body "Ready for another review pass. I addressed the findings and reran checks."
```

List PR review comments so you can find a comment ID to reply to:

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments \
  | jq '.[] | { id, path, user: .user.login, body, url }'
```

Reply to a specific PR review comment in-thread:

```bash
gh api graphql -f query='
mutation($commentId: ID!, $body: String!) {
  addPullRequestReviewCommentReply(input: {
    pullRequestReviewCommentId: $commentId,
    body: $body
  }) {
    comment {
      url
    }
  }
}' -F commentId=COMMENT_ID -F body='Reply message'
```

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
gh project item-list PROJECT_NUMBER --owner OWNER --format json \
  | jq '.items[]
    | select((.["workflow State"] // "") == "Blocked")
    | {
        title: (.content.title // ""),
        issue_number: (.content.number // null),
        url: (.content.url // "")
      }'
```
