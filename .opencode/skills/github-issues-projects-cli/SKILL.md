---
name: github-issues-projects-cli
description: Use whenever the user wants to inspect, create, update, triage, or report on GitHub Issues or GitHub Projects using the `gh` CLI, especially when the task involves figuring out the right `gh` command, GraphQL shape, field IDs, option IDs, or `jq` filters. Trigger on requests about issue queues, project boards, backlog grooming, status changes, assignees, labels, milestone linkage, project item movement, or "what gh command should I use?" for GitHub collaboration workflows.
---

# GitHub Issues And Projects CLI

Use this skill when GitHub Issues and GitHub Projects are the collaboration surface and the main risk is wasting time guessing `gh` commands, GraphQL arguments, or `jq` filters.

This skill is about operational fluency, not just raw command execution. The goal is to make GitHub collaboration changes predictable, inspectable, and reversible before mutating anything important.

Use `github-agentic-delivery-flow` for the overall operating model and `github-conventions` for repository workflow rules. Use this skill for the command-level mechanics.

## Purpose

Use `gh` as the primary interface for GitHub collaboration artifacts:

- issues
- milestones
- labels
- comments
- assignees
- project items
- project fields and status options
- board and backlog reporting

Use `jq` to shape JSON outputs so the user gets the exact answer or exact mutation target without trial-and-error loops.

## Repository Configuration

Repository-specific defaults live in the sole committed project config source:

`./.github-project.env`

```bash
source ./.github-project.env
```

That file stores every config value with the `ANT_TEAM_` prefix (`ANT_TEAM_GITHUB_OWNER`, `ANT_TEAM_GITHUB_PROJECT_NUMBER`, `ANT_TEAM_GITHUB_PROJECT_ID`, `ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID`, `ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_IN_REVIEW_ID`, `ANT_TEAM_WORKTREE_ROOT`, `ANT_TEAM_DOCS_PROJECT_PATH`, and so on), covering:

- owner, repo, owner type
- project number and project ID
- field IDs (including the canonical `Workflow State` field)
- Workflow State option IDs (one `ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_<STATE>_ID` per canonical state)
- the default `ANT_TEAM_WORKTREE_ROOT` and the `ANT_TEAM_DOCS_*` documentation routing exports

Prefer sourcing it over any other config lookup. The env is seeded and updated by project initialization itself (`"$ANT_TEAM_SCRIPTS/init-project.sh"` after `scripts/init-company.sh`; there is no standalone generator and no JSON config): existing values are preserved and missing keys are filled. The bundled `gh_project_helper.sh` sources the env as its sole local runtime config; `"$ANT_TEAM_SCRIPTS/gh_project_helper.sh"` is the thin centralized wrapper that invokes it (with `bash`, so mirror execute bits are never required).

The env file is intended to be committed to the repository because it stores shared GitHub collaboration metadata rather than secrets.

Keep the JSON as the structured source of truth because GitHub project metadata often grows into structured mappings such as:

- Workflow State name to option ID
- field name to field ID
- arrays of common workflow states
- repo-level workflow defaults such as top-level `worktreeRoot`

## Common Actions To Support Explicitly

Be concrete when the user asks for any of these common GitHub collaboration actions:

- create an issue comment
- create an issue that represents a task
- create a milestone that represents a spec or deliverable
- find the GitHub Project item ID for an issue
- list issues in a given Workflow State on a project board
- transition an issue to the next Workflow State
- complete an issue
- create a PR when an issue is ready for code review
- comment on a PR
- reply to a PR review comment

For these actions, prefer returning the exact command sequence rather than only describing the workflow.

## Default Mindset

Start with discovery before mutation.

That usually means:

1. Confirm repository and owner context.
2. Inspect the current issue or project state.
3. Discover the exact field IDs, item IDs, and option IDs needed.
4. Show or summarize the planned mutation when the command is non-obvious.
5. Execute the smallest safe mutation.
6. Re-read the affected resource to verify the result.

Do not guess field names, single-select option IDs, or project item IDs.

## Command Strategy

Prefer commands in this order:

1. the bundled helper for issue and milestone operations (`issue-create`, `issue-view`, `issue-list`, `issue-edit`, `issue-comment`, `issue-close`, `milestone-create`, `milestone-list`, `milestone-edit`, `milestone-close`) — thin wrappers around `gh issue` / `gh api` that resolve the target repository from `.github-project.env` (`ANT_TEAM_GITHUB_REPO`) so no `--repo` has to be repeated
2. `gh issue ...` directly when operating outside a repository with `.github-project.env`
3. `gh project ...` for supported project inspection commands
4. `gh api graphql` when GitHub Projects v2 mutations or richer joins are needed
5. `jq` to extract only the fields needed for the next step

Prefer structured output over human-formatted output:

- use `--json`
- use `--jq` for simple extraction
- use external `jq` for more involved transforms
- the helper's `issue-view` and `issue-list` print curated collaboration JSON by default; pass `--json`, `--jq`, `--template`, `--comments`, or `--web` to control the shape yourself (all other flags pass straight through to `gh issue`)
- for repeated GitHub Project operations, prefer the centralized wrapper `"$ANT_TEAM_SCRIPTS/gh_project_helper.sh"` (it routes to this skill's bundled engine and saves tokens by avoiding re-derived GraphQL details)
- prefer repo-local defaults (source `./.github-project.env` — the sole committed project config source — for `ANT_TEAM_*` values) before asking the user again for owner or project number
- prefer repo-local IDs from the sourced env before calling GitHub endpoints to rediscover stable field IDs and option IDs

## Required Behavior

- Resolve repo context before acting. Use explicit `--repo owner/name` when ambiguity is possible.
- Read before writing. Inspect the current issue, project, item, or field state first.
- When working with a project, discover the project ID, item ID, field ID, and option ID instead of assuming them.
- Remember that a GitHub issue ID and a GitHub Project item ID are different identifiers. Status updates on the project board require the project item ID, not the issue number alone.
- Prefer listing and filtering JSON once over repeated trial commands.
- If a command mutates GitHub state, re-read the resource afterward and report the changed state.
- If the user asks for a bulk change, preview the candidate targets first unless they explicitly want direct execution.
- Keep comments and updates concise, durable, and collaboration-friendly.

## Standard Workflows

### 1. Issue Triage

Use this flow when the user wants to inspect or update one or more issues:

1. Identify repo context.
2. Query the issue set with the helper (`issue-list`, `issue-view`) or raw `gh issue list` / `gh issue view` outside a configured repo.
3. Shape the output to show number, title, state, labels, assignees, milestone, and URL.
4. If mutating, run the smallest issue edit command possible (`issue-edit`, `issue-comment`, `issue-close`).
5. Re-read the issue to verify labels, assignees, milestone, or state.

Common operations:

- list open issues by label, assignee, or milestone
- open an issue
- add labels
- set assignee
- attach milestone
- comment with final decisions, status, closure, or review outcomes
- close or reopen issues

### 2. Project Board Inspection

Use this flow when the user wants to understand a GitHub Project board:

1. Identify owner type and owner login.
2. List projects and confirm the correct project number.
3. Read project fields and Workflow State options.
4. List project items in JSON.
5. Use `jq` to extract item titles, statuses, assignees, and linked issue URLs.
6. When a mutation targets a specific issue on the board, resolve the project item ID from the issue number before editing status fields.

Do not jump straight to mutation until the board schema is known.

### 3. Project Item State Change

Use this flow when the user wants to move issues across board states:

1. Find the project.
2. Find the project item for the issue.
3. Read the field schema and locate the canonical `Workflow State` field.
4. Find the option ID for the target state.
5. Execute the mutation.
6. Re-read the item or project listing to confirm the new state.

This matters because GitHub Projects v2 updates often require opaque IDs rather than human-readable names.

### 4. Backlog Or Status Reporting

Use this flow when the user wants summaries or filtered views:

1. Pull JSON from issues or project items.
2. Use `jq` to group or filter by milestone, label, assignee, or status.
3. Return a compact table or bullet summary rather than dumping raw JSON.

Good examples:

- issues by milestone
- blocked items on the board
- items in review with no assignee
- tasks missing milestones
- open issues not on the project board

## Command-First Playbook

When the user asks for a common action, start from these defaults and adapt them to the repo and project context.

### Create Comment On An Issue

Use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh issue-comment ISSUE_NUMBER \
  --body "Final decision: approved with the follow-up filed as #51."
```

Comments carry only final decisions, status, closure, and code-review outcomes; durable handoffs and reasoning live in the central Obsidian project folder. Pass `--body-file` for longer notes.

### Create Issue As A Task

Use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh issue-create "TASK: short task title" \
  --body-file /tmp/issue.md \
  --label type:feature \
  --assignee USERNAME \
  --milestone "SPEC-001"
```

The first positional is the required title; every other flag passes straight through to `gh issue create`. Prefer `--body-file` when the task template is more than a couple of lines.

### Create Milestone As A Spec

Use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh milestone-create "SPEC-001: Deliverable name" \
  "Short summary with spec link and owner"
```

The description is optional. The helper wraps the REST milestones API via `gh api` (there is no dedicated `gh milestone create` command) and prints a curated summary (number, title, state, counts, URL). Related commands:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh milestone-list            # open milestones
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh milestone-list all
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh milestone-edit MILESTONE_NUMBER -f title="SPEC-001: Revised name"
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh milestone-close MILESTONE_NUMBER
```

### Resolve Project Item ID For An Issue

Use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh item-id ISSUE_NUMBER
```

Assume issue-to-project linking is usually automatic in this repository workflow. Do not manually link an issue unless the board automation failed or the user explicitly asks for a manual add.

Use the project item ID whenever you need to update project status or any project field for that issue.

### List Issues In A Workflow State

Use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh list-items "Ready"
```

All helper commands are env-only: owner, project number, and repository resolve from `.github-project.env`; there are no positional owner/project arguments. To list repo issues instead of board items:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh issue-list --label blocked --state open
```

All board operations target the canonical `Workflow State` field. Canonical states: `Open`, `Backlog`, `Ready`, `In Progress`, `In Review`, `Ready to Merge`, `Done`, plus exceptions `Need attentions` (founder-only) and `Blocked`. If the remote board still carries a legacy option name (e.g. `Inbox` for `Open`, `Shaping` for `Backlog`), inspect options with `list-statuses` and never rename remote options without explicit founder-approved handling.

### Transition Issue To Next Status On Project Board

Use a three-step flow:

1. discover the project item ID for the issue
2. discover the Workflow State field ID and target option ID
3. update the item with GraphQL

Do not skip the discovery steps. GitHub Projects v2 status changes depend on opaque IDs.

Preferred shortcut:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh set-status ISSUE_NUMBER "In Review"
```

The helper resolves the Workflow State field and option IDs from `.github-project.env` (its sole local runtime config), then from the remote board by exact option name. It never creates or renames remote options; if a canonical name has no matching remote option, it fails with guidance instead of mutating the board. When stable IDs are already stored in `.github-project.env`, prefer `gh project item-edit` over raw GraphQL because it uses fewer tokens and matches the installed CLI behavior better.

Important:

- `gh project item-list`, `gh project field-list`, and `gh project view` use `--owner` and the project number
- `gh project item-edit` does not accept `--owner`
- `gh project item-edit` requires `--project-id`

If the user hits `unknown flag: --owner`, switch immediately to `gh project item-edit --project-id ...`.

For direct low-level editing with pre-resolved IDs, use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh gh-item-edit ITEM_ID STATUS_FIELD_ID STATUS_OPTION_IN_REVIEW_ID
```

### Complete Issue

Use both collaboration surfaces when appropriate:

1. move the project item to `Done`
2. close the issue
3. optionally add a completion comment (final outcome only)

Typical sequence:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh set-status ISSUE_NUMBER "Done"
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh issue-close ISSUE_NUMBER --comment "Completed and validated."
```

If the workflow requires board-state visibility, do not only close the issue. Also update the project status.

### Create PR When Issue Is Ready For Code Review

Use:

```bash
gh pr create --repo OWNER/REPO \
  --base main \
  --head BRANCH_NAME \
  --title "ISSUE-123: short task title" \
  --body-file /tmp/pr.md
```

Prefer `--body-file` so the PR includes task link, summary, verification, and review notes.

### Comment On A PR

Use:

```bash
gh pr comment PR_NUMBER --repo OWNER/REPO --body "MESSAGE"
```

Use this for review handoffs, retest notes, or high-level review conversation.

### Reply To A PR Review Comment

Prefer the review-comment API when the user specifically wants to reply in-thread to an existing review comment.

Use:

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

If the user only needs a general PR response and not an in-thread reply, `gh pr comment` is simpler.

## GitHub Projects Notes

Assume GitHub Projects v2 unless the repository clearly uses something else.

For Projects v2:

- field names are not enough for mutation
- single-select values usually need option IDs
- item updates often require `gh api graphql`
- read operations should still begin with `gh project field-list` and `gh project item-list` when available

If the CLI subcommand does not support the exact mutation needed, use `gh api graphql` rather than inventing a brittle workaround.

## Output Style

When answering the user, prefer:

- the exact command to run
- a one-line explanation of why that command is the right one
- a short note on what to verify next

When the workflow takes multiple commands, present them as a small sequence with the dependency between steps made explicit.

## Safety And Collaboration Rules

- Avoid bulk edits without previewing targets first.
- Avoid hard-coding IDs that were not freshly discovered.
- Avoid acting on the wrong owner or repo because of local defaults.
- Prefer individual Obsidian communication event files for agent handoffs, blockers, and reasoning. Use GitHub comments for final closing messages, status-critical updates, and links to the Obsidian event.
- If a mutation could affect many items, summarize the intended scope before executing.

## Reference File

Read [references/command-patterns.md](./references/command-patterns.md) whenever you need ready-to-adapt `gh` + `jq` recipes for:

- issue lookup and triage
- issue comments
- issue creation, editing, and closure
- milestone creation, listing, editing, and closure
- project listing and schema inspection
- project item add
- project item queries
- workflow-state filtering
- status option lookup
- GraphQL mutation templates
- PR creation and comments
- PR review reply mutations
- reporting filters

Use [scripts/gh_project_helper.sh](./scripts/gh_project_helper.sh) (the bundled engine; `"$ANT_TEAM_SCRIPTS/gh_project_helper.sh"` is its thin centralized wrapper) whenever the user asks for repeated GitHub Project, issue, or milestone operations and the goal is to minimize prompt tokens, avoid repeating raw GraphQL mutations, and keep the repository resolved from `.github-project.env`.

If the repository is being bootstrapped, recommend creating `.github-project.env` during project initialization so future GitHub issue and project workflows work with minimal prompt overhead.

## Examples

**Example 1**

Input: "what `gh` command should I use to list open issues in this repo with the `blocked` label and show assignee + milestone?"

Output shape:

- the helper command `gh_project_helper.sh issue-list --label blocked` (curated JSON: number, title, state, assignees, labels, milestone, url)
- a `jq` filter if a tighter shape is needed
- a short explanation of the selected fields

**Example 2**

Input: "move issue 42 to In Review on our GitHub project board"

Output shape:

- commands to discover project, item, field, and option IDs
- the mutation command
- the verification command

**Example 3**

Input: "show me what work is on the project board but has no assignee"

Output shape:

- project item listing command
- `jq` filter for missing assignees
- concise summary of results
