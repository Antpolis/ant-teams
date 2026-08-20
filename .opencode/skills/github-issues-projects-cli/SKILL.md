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

Prefer storing repository-specific defaults in:

`./.github-project.json`

Use `./.github-project.env` only as a fallback for older repos.

Use that file for:

- owner
- repo
- owner type
- project number and project ID
- field IDs
- status option IDs
- any future structured GitHub metadata that benefits from arrays or nested objects

This keeps prompts shorter and lets the helper script run without repeating the same owner and project number in every command.

This file is intended to be committed to the repository because it stores shared GitHub collaboration metadata rather than secrets.

Prefer JSON over env because GitHub project metadata often grows into structured mappings such as:

- status name to option ID
- field name to field ID
- arrays of common workflow states
- repo-level workflow defaults such as top-level `worktreeRoot`

## Common Actions To Support Explicitly

Be concrete when the user asks for any of these common GitHub collaboration actions:

- create an issue comment
- create an issue that represents a task
- create a milestone that represents a spec or deliverable
- find the GitHub Project item ID for an issue
- list `Todo` issues in a project board
- transition an issue to the next project-board status
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

1. `gh issue ...` for issue-native operations
2. `gh project ...` for supported project inspection commands
3. `gh api graphql` when GitHub Projects v2 mutations or richer joins are needed
4. `jq` to extract only the fields needed for the next step

Prefer structured output over human-formatted output:

- use `--json`
- use `--jq` for simple extraction
- use external `jq` for more involved transforms
- for repeated GitHub Project operations, prefer the bundled script `scripts/gh_project_helper.sh` to save tokens and avoid re-deriving GraphQL details
- prefer repo-local defaults from `.github-project.json` before asking the user again for owner or project number
- prefer repo-local IDs from `.github-project.json` before calling GitHub endpoints to rediscover stable field IDs and option IDs

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
2. Query the issue set with `gh issue list` or `gh issue view`.
3. Shape the output to show number, title, state, labels, assignees, milestone, and URL.
4. If mutating, run the smallest issue edit command possible.
5. Re-read the issue to verify labels, assignees, milestone, or state.

Common operations:

- list open issues by label, assignee, or milestone
- open an issue
- add labels
- set assignee
- attach milestone
- comment with handoff or blocker notes
- close or reopen issues

### 2. Project Board Inspection

Use this flow when the user wants to understand a GitHub Project board:

1. Identify owner type and owner login.
2. List projects and confirm the correct project number.
3. Read project fields and status options.
4. List project items in JSON.
5. Use `jq` to extract item titles, statuses, assignees, and linked issue URLs.
6. When a mutation targets a specific issue on the board, resolve the project item ID from the issue number before editing status fields.

Do not jump straight to mutation until the board schema is known.

### 3. Project Item State Change

Use this flow when the user wants to move issues across board states:

1. Find the project.
2. Find the project item for the issue.
3. Read the field schema and locate the status field.
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
gh issue comment ISSUE_NUMBER --repo OWNER/REPO --body "MESSAGE"
```

Use this for handoffs, blocker notes, status updates, and review-ready notes.

### Create Issue As A Task

Use:

```bash
gh issue create --repo OWNER/REPO \
  --title "TASK: short task title" \
  --body-file /tmp/issue.md \
  --label type:feature \
  --assignee USERNAME \
  --milestone "SPEC-001"
```

Prefer `--body-file` when the task template is more than a couple of lines.

### Create Milestone As A Spec

Use:

```bash
gh api repos/OWNER/REPO/milestones \
  -f title="SPEC-001: Deliverable name" \
  -f description="Short summary with spec link and owner"
```

Use `gh api` here because milestone creation is not covered by a dedicated `gh milestone create` command.

### Resolve Project Item ID For An Issue

Use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh item-id ISSUE_NUMBER
```

Assume issue-to-project linking is usually automatic in this repository workflow. Do not manually link an issue unless the board automation failed or the user explicitly asks for a manual add.

Use the project item ID whenever you need to update project status or any project field for that issue.

### List `Todo` Issues In Project Board

Use:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh list-todo
```

If the board uses `Inbox`, `Ready`, or another equivalent instead of `Todo`, inspect status options first and then adapt the filter.

### Transition Issue To Next Status On Project Board

Use a three-step flow:

1. discover the project item ID for the issue
2. discover the status field ID and target option ID
3. update the item with GraphQL

Do not skip the discovery steps. GitHub Projects v2 status changes depend on opaque IDs.

Preferred shortcut:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh set-status ISSUE_NUMBER "In Review"
```

When stable IDs are already stored in `.github-project.env`, prefer `gh project item-edit` over raw GraphQL because it uses fewer tokens and matches the installed CLI behavior better.

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
3. optionally add a completion comment

Issue close command:

```bash
gh issue close ISSUE_NUMBER --repo OWNER/REPO --comment "Completed and validated."
```

If the workflow requires board-state visibility, do not only close the issue. Also update the project status.

Typical sequence:

```bash
./.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh set-status ISSUE_NUMBER "Done"
gh issue close ISSUE_NUMBER --repo "${REPO:-OWNER/REPO}" --comment "Completed and validated."
```

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
- issue creation
- milestone creation
- project listing and schema inspection
- project item add
- project item queries
- todo-list filtering
- status option lookup
- GraphQL mutation templates
- PR creation and comments
- PR review reply mutations
- reporting filters

Use [scripts/gh_project_helper.sh](./scripts/gh_project_helper.sh) whenever the user asks for repeated GitHub Project operations and the goal is to minimize prompt tokens and avoid repeating raw GraphQL mutations.

If the repository is being bootstrapped, recommend creating `.github-project.env` during project initialization so future GitHub issue and project workflows work with minimal prompt overhead.

## Examples

**Example 1**

Input: "what `gh` command should I use to list open issues in this repo with the `blocked` label and show assignee + milestone?"

Output shape:

- a `gh issue list --json ...` command
- a `jq` filter if needed
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
