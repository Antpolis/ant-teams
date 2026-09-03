#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_ENV_FILE="$REPO_ROOT/.github-project.env"

# Canonical board field. The legacy "Status" field (Todo/In Progress/Done) is
# no longer targeted by this helper.
readonly CANONICAL_FIELD_NAME="Workflow State"

# Board item reads page through the shared GraphQL project-items engine
# with bounded cursor pagination (gh project item-list is limit-bounded and
# carries neither assignees nor option ids, so the engine never depends on
# it). The page bound caps runaway boards; truncation is warned, never
# silent.
readonly PROJECT_ITEMS_PAGE_SIZE=100
readonly PROJECT_ITEMS_MAX_PAGES=10

# Default JSON field sets for issue and PR read commands:
# collaboration-shaped, safe output. Callers take over the output shape by
# passing --json, --jq, --template, --comments, or --web themselves.
readonly ISSUE_VIEW_FIELDS="number,title,body,state,assignees,labels,milestone,projectItems,url"
readonly ISSUE_LIST_FIELDS="number,title,state,assignees,labels,milestone,url"
readonly PR_VIEW_FIELDS="number,title,state,body,headRefName,baseRefName,author,labels,reviewDecision,isDraft,url"
readonly PR_LIST_FIELDS="number,title,state,headRefName,baseRefName,author,isDraft,updatedAt,url"
# gh (2.45) run/workflow JSON fields: runs expose displayTitle (no "title"
# alias) and workflow list supports exactly id,name,path,state.
readonly RUN_VIEW_FIELDS="number,displayTitle,workflowName,status,conclusion,event,headBranch,headSha,createdAt,updatedAt,url"
readonly RUN_LIST_FIELDS="number,displayTitle,workflowName,status,conclusion,event,headBranch,createdAt,updatedAt,url"
readonly WORKFLOW_LIST_FIELDS="id,name,path,state"
# gh (2.45) release JSON fields: view exposes the collaboration shape
# below; list supports exactly the curated fields (no url).
readonly RELEASE_VIEW_FIELDS="name,tagName,targetCommitish,isDraft,isPrerelease,createdAt,publishedAt,author,body,url"
readonly RELEASE_LIST_FIELDS="name,tagName,isDraft,isPrerelease,isLatest,createdAt,publishedAt"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

usage() {
  cat <<'EOF'
Usage:
  gh_project_helper.sh gh-item-edit <item_id> <field_id> <single_select_option_id>
  gh_project_helper.sh item-id <issue_number>
  gh_project_helper.sh item-state <issue_number>
  gh_project_helper.sh list-statuses
  gh_project_helper.sh list-items [state_name]
  gh_project_helper.sh list-unassigned
  gh_project_helper.sh add-issue <issue_url>
  gh_project_helper.sh set-status <issue_number> <state_name> [owner_type]
  gh_project_helper.sh set-status-id <issue_number> <single_select_option_id> [owner_type]
  gh_project_helper.sh next-status <issue_number> <current_state> <next_state> [owner_type]

  gh_project_helper.sh project-list [--owner OWNER] [--format json]
  gh_project_helper.sh project-view PROJECT_NUMBER [--owner OWNER] [--format json]
  gh_project_helper.sh project-field-list PROJECT_NUMBER [--owner OWNER] [--format json]

  gh_project_helper.sh issue-create <title> [gh issue flags...]
  gh_project_helper.sh issue-view <issue_number> [gh issue flags...]
  gh_project_helper.sh issue-list [gh issue flags...]
  gh_project_helper.sh issue-edit <issue_number> [gh issue flags...]
  gh_project_helper.sh issue-comment <issue_number> [gh issue flags...]
  gh_project_helper.sh issue-close <issue_number> [gh issue flags...]

  gh_project_helper.sh pr-create <title> [gh pr flags...]
  gh_project_helper.sh pr-view <pr_number> [gh pr flags...]
  gh_project_helper.sh pr-list [gh pr flags...]
  gh_project_helper.sh pr-comment <pr_number> [gh pr flags...]
  gh_project_helper.sh pr-close <pr_number> [gh pr flags...]
  gh_project_helper.sh pr-merge <pr_number> [gh pr flags...]
  gh_project_helper.sh pr-checks <pr_number> [gh pr flags...]
  gh_project_helper.sh pr-review-reply <review_comment_id> <reply_body>

  gh_project_helper.sh run-list [gh run flags...]
  gh_project_helper.sh run-view <run_id> [gh run flags...]
  gh_project_helper.sh workflow-list [gh workflow flags...]
  gh_project_helper.sh workflow-run <workflow_id_or_name> [gh workflow flags...]

  gh_project_helper.sh milestone-create <title> [description]
  gh_project_helper.sh milestone-list [state]
  gh_project_helper.sh milestone-edit <milestone_number> [gh api -f flags...]
  gh_project_helper.sh milestone-close <milestone_number>

  gh_project_helper.sh issue-sync <issue_number>
  gh_project_helper.sh milestone-sync <milestone_number>

  gh_project_helper.sh release-create <tag> [gh release flags...]
  gh_project_helper.sh release-list [gh release flags...]
  gh_project_helper.sh release-view <tag> [gh release flags...]
  gh_project_helper.sh release-edit <tag> [gh release flags...]
  gh_project_helper.sh release-delete <tag> [gh release flags...]

Notes:
  - all board operations target the canonical "Workflow State" project field
  - board item queries (list-items, list-unassigned, item-id, item-state)
    and every set-status item lookup/verification run ONE shared GraphQL
    project-items engine: gh project item-list is limit-bounded and returns
    neither assignees nor option ids, so the engine never depends on it.
    Reads are pagination-safe: items are paged with first:100 cursor pages
    (bounded at 10 pages / 1000 items; truncation beyond the bound is
    warned on stderr, never silent). list-items/list-unassigned print
    {item_id, issue_number, title, state, assignees, url} per issue-linked
    item with REAL assignees; "state" is the REMOTE Workflow State option
    name preserved/displayed as-is (never translated to the canonical
    name). An optional state argument filters by canonical state resolved
    to its option id via the same resolver as set-status (name-agnostic:
    correct even when the remote display name is a legacy rename); an
    unknown state fails non-zero with guidance before any query results
    are printed. item-id prints {item_id, issue_number, title, url, state};
    item-id and item-state fail non-zero naming the issue when it has no
    board item
  - item-state <issue_number> is the read-only recovery command: it prints
    {item_id, issue_number, title, state, url, canonical_state} where
    canonical_state is reverse-mapped from the item's option id against
    the env-pinned canonical option IDs (null when the option id is
    unknown locally). Run it after any failed or interrupted status
    mutation to see where the item actually sits; it never mutates
  - verified + idempotent status mutations: set-status, set-status-id, and
    next-status find the item by issue number through the shared engine,
    skip the mutation when the item already carries the requested OPTION
    id (no duplicate edit, stderr notes the skip), perform exactly one
    item-edit attempt, then re-read the item and verify by option id —
    independent of the remote display name. A post-edit mismatch exits
    non-zero with the actual board state on stderr. next-status
    ISSUE_NUMBER CURRENT NEXT additionally enforces a precondition: the
    item must currently sit in CURRENT (matched by option id) or the
    command fails non-zero without mutating
  - bounded read-only retry: board read calls (the shared items engine,
    Workflow State field/option id discovery, project id discovery, and
    list-statuses) retry transient failures (rate limit, network) up to 3
    attempts with a short pause, then exit 3 — safe to retry later.
    Mutations are NEVER retried: a failed mutation fails immediately.
    Exit 3 is the shared "retryable" exit (also used by the dual-record
    offline deferral below); hard usage/config errors stay exit 1
  - project-list, project-view, and project-field-list are thin
    gh project list/view/field-list wrappers plus curated jq output; they
    never use the GraphQL items engine (field-list already returns
    single-select options). The owner resolves --owner flag ->
    ANT_TEAM_GITHUB_OWNER env -> legacy OWNER and must be non-empty (the
    underlying list command without an owner silently targets the
    authenticated user — a cross-owner footgun); the owner is never a
    positional argument. PROJECT_NUMBER is a required positional validated
    numeric, and --format accepts only json — both checked before gh runs
  - curated board output contract: set-status, set-status-id, list-items, and
    item-id print curated JSON objects that always carry issue_number, title,
    state, and url (list-items also reports assignees; item-id also reports
    item_id). set-status / set-status-id re-read the board item AFTER the
    edit and verify by option id, so the printed state is the post-edit
    verification value and an edit that silently failed cannot report a
    stale state
  - curated mutator output contract: every mutator except issue-comment and
    pr-comment returns useful structured JSON, never raw gh output.
    issue-create and pr-create print {number, title, state, url}, reusing
    the mutation's URL response plus the caller's title and the
    deterministic OPEN state (no extra read). issue-edit, issue-close,
    pr-close, and pr-merge re-read the object AFTER the mutation and print
    {number, title, state, url} — the re-read IS the verification.
    release-create and release-edit re-read the release and print the same
    curated shape as release-view. release-delete prints {tagName, url,
    deleted: true} (a deleted release cannot be re-read; mutation success
    is the verification). workflow-run prints {workflow, repo,
    status: "dispatched"} (the dispatch response carries no run id; use
    run-list / run-view for run summaries). issue-comment and pr-comment
    keep their URL permalink output: the permalink IS the useful result
  - canonical state model: Open -> Backlog -> Ready -> In Progress -> In Review
    -> Ready to Merge -> Done; exceptions: Need attentions (founder-only) and
    Blocked
  - runtime config resolution: .github-project.env (ANT_TEAM_* exports) is
    the sole project config source; it is seeded and updated by
    init-project ("$ANT_TEAM_SCRIPTS/init-project.sh" after
    scripts/init-company.sh). Legacy unprefixed env names (OWNER,
    PROJECT_NUMBER, ...) are a last-resort fallback
  - option IDs are resolved from the env config first, then from the remote
    board by exact option name
  - this helper never mutates remote board option names; renaming a remote
    option (e.g. legacy "Inbox" -> "Open", "Shaping" -> "Backlog") requires
    explicit founder-approved handling. After such a rename, update the
    .github-project.env option IDs with the verified remote IDs
  - issue-* wrap gh issue and milestone-* wrap the REST milestones API via
    gh api. The target repository always resolves from
    .github-project.env (ANT_TEAM_GITHUB_REPO, legacy REPO fallback) and
    is never a positional argument; a pass-through --repo flag cannot
    override it
  - pr-* wrap gh pr with the same env-only repo contract as issue-*;
    pr-view and pr-list print curated JSON by default, and pr-checks
    curates gh's tabular checks output into JSON (gh pr checks has no
    --json). Pass --json, --jq, --template, --comments, or --web to
    control the output shape yourself
  - pr-merge and pr-close are policy-controlled: they pass caller flags
    through only and never inject --admin or bypass approval gates
  - pr-review-reply posts an in-thread reply to a PR review comment via a
    fixed parameterized GraphQL mutation; user input travels only as
    GraphQL variables, never inside the query text
  - run-* and workflow-* wrap gh run / gh workflow with the same env-only
    repo contract as issue-*; run-list, run-view, and workflow-list print
    curated JSON by default (pass --json, --jq, --template, or --web to
    control the output shape yourself). This helper never executes
    workflows' tests locally and performs no Git operations
  - workflow-run (dispatch) is policy-controlled: it passes caller flags
    through only and never injects --admin or bypasses approval gates
  - release-* wrap gh release with the same env-only repo contract as
    issue-*; release-view and release-list print curated JSON by default
    (pass --json, --jq, --template, or --web to control the output shape
    yourself)
  - release-create, release-edit, and release-delete validate the tag
    against the canonical Git tag rules and fail before invoking gh;
    release-delete is policy-controlled and destructive: it passes caller
    flags through only, never injects --admin, never defaults the --yes
    auto-confirm, and never bypasses approval gates
  - extra flags after the required positional argument pass straight
    through to gh issue / gh api; issue-view and issue-list print curated
    JSON by default (pass --json, --jq, --template, --comments, or --web
    to control the output shape yourself)
  - issue-comment exists for final decisions, status, closure, and
    code-review outcomes only; durable handoffs live in the central
    Obsidian project folder
  - local-first dual-record sync: mutating issue/milestone CRUD commands
    (issue-create, issue-edit, issue-close, milestone-create,
    milestone-edit, milestone-close) write the local Obsidian record under
    ANT_TEAM_DOCS_PROJECT_PATH/issue/ or .../spec/ FIRST, then synchronize
    to GitHub when online. Mapping is deterministic: issue number ->
    issue/ISSUE-0NN-*.md by github_number frontmatter; milestone number ->
    spec/SPEC-0NN-*.md by github_milestone frontmatter. The "Local Notes"
    section and local-only frontmatter are always preserved
  - offline / GitHub failure: the local write is kept and marked
    pending_sync: true; the command exits 3 with a stderr warning naming
    the recovery command (issue-sync <n> / milestone-sync <n>); the local
    write is never rolled back
  - issue-sync <n> and milestone-sync <n> converge the local record and
    GitHub idempotently: pending local durable content (title, body) is
    pushed, GitHub execution-state fields (state/closure, labels,
    assignees, milestone link, URL) are pulled. On conflict (both sides
    changed since the last sync) durable content resolves toward the local
    record, execution-state toward GitHub, and resolved conflicts are
    reported on stderr
  - reads fall back to the local record when GitHub is unreachable and
    never write it; issue-comment and board commands stay GitHub-only
  - local record writes are atomic (temp file + rename), slugified, and
    confined to ANT_TEAM_DOCS_PROJECT_PATH/{issue,spec}/; the helper never
    runs git commit / git push on the vault and never edits
    .github-project.env
  - owner_type defaults to "org". Use "user" for personal projects.
  - Requires gh and jq.
EOF
}

# Source the project env when present. It exports the ANT_TEAM_* variables
# that make up the sole committed project config (seeded and updated by
# init-project directly).
load_config() {
  if [[ -f "$CONFIG_ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_ENV_FILE"
  fi
}

require_value() {
  local name="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    echo "Missing required value: $name" >&2
    echo "Pass it explicitly or set it in $CONFIG_ENV_FILE" >&2
    exit 1
  fi
}

# Board status/lookup commands: the issue number is a required numeric
# positional and the optional owner_type accepts exactly org or user. Both
# are checked BEFORE gh runs, so a positional owner can never reach a gh
# call (the env-only contract shared with the query family).
validate_board_status_args() {
  local issue_number="$1"
  local owner_type="${2:-}"
  local cmd_name="$3"

  if [[ ! "$issue_number" =~ ^[0-9]+$ ]]; then
    echo "Invalid issue number '$issue_number' for $cmd_name: must be a positive integer (the owner is never a positional argument)" >&2
    exit 1
  fi
  if [[ -n "$owner_type" && "$owner_type" != "org" && "$owner_type" != "user" ]]; then
    echo "Invalid owner_type '$owner_type' for $cmd_name: must be org or user" >&2
    exit 1
  fi
}

# Config resolution: explicit argument -> ANT_TEAM_* export from
# .github-project.env (the sole project config source) -> legacy unprefixed
# env name. Remote discovery happens at the call sites when all three are
# empty.
resolve_owner() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
  elif [[ -n "${ANT_TEAM_GITHUB_OWNER:-}" ]]; then
    printf '%s\n' "$ANT_TEAM_GITHUB_OWNER"
  else
    printf '%s\n' "${OWNER:-}"
  fi
}

resolve_project_number() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
  elif [[ -n "${ANT_TEAM_GITHUB_PROJECT_NUMBER:-}" ]]; then
    printf '%s\n' "$ANT_TEAM_GITHUB_PROJECT_NUMBER"
  else
    printf '%s\n' "${PROJECT_NUMBER:-}"
  fi
}

resolve_owner_type() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
  elif [[ -n "${ANT_TEAM_GITHUB_OWNER_TYPE:-}" ]]; then
    printf '%s\n' "$ANT_TEAM_GITHUB_OWNER_TYPE"
  else
    printf '%s\n' "${OWNER_TYPE:-org}"
  fi
}

# Target repository for issue-* and milestone-* subcommands. Resolution
# order: ANT_TEAM_GITHUB_REPO export from .github-project.env (the sole
# project config source) -> legacy unprefixed REPO. Never a positional
# argument.
resolve_repo() {
  if [[ -n "${ANT_TEAM_GITHUB_REPO:-}" ]]; then
    printf '%s\n' "$ANT_TEAM_GITHUB_REPO"
  else
    printf '%s\n' "${REPO:-}"
  fi
}

# Issue and milestone subcommands have no repo argument to fall back to;
# the env config is the only source.
require_repo() {
  local repo="$1"
  if [[ -z "$repo" ]]; then
    echo "Missing required value: ANT_TEAM_GITHUB_REPO" >&2
    echo "Set it in $CONFIG_ENV_FILE (issue and milestone subcommands take no repo argument)" >&2
    exit 1
  fi
}

resolve_project_id_from_env() {
  if [[ -n "${ANT_TEAM_GITHUB_PROJECT_ID:-}" ]]; then
    printf '%s\n' "$ANT_TEAM_GITHUB_PROJECT_ID"
  else
    printf '%s\n' "${PROJECT_ID:-}"
  fi
}

# Field ID for the canonical Workflow State single-select field.
# Resolution order: env pin (ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID) ->
# legacy unprefixed env pin -> remote discovery.
resolve_state_field_id_from_env() {
  if [[ -n "${ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID:-}" ]]; then
    printf '%s\n' "$ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID"
  else
    printf '%s\n' "${WORKFLOW_STATE_FIELD_ID:-${STATUS_FIELD_ID:-}}"
  fi
}

# Option ID for a Workflow State value by display name (e.g. "In Review",
# "Need attentions"). Resolution order: env pin (variable key = lowercase,
# spaces -> dashes, uppercase, dashes -> underscores) -> legacy unprefixed
# env pin -> remote discovery by exact option name.
resolve_state_option_id_from_env() {
  local state_name="$1"
  local var_name="ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_$(printf '%s' "$state_name" | tr '[:lower:]' '[:upper:]' | tr ' -' '__')_ID"
  local legacy_var_name="WORKFLOW_STATE_OPTION_$(printf '%s' "$state_name" | tr '[:lower:]' '[:upper:]' | tr ' -' '__')_ID"
  if [[ -n "${!var_name:-}" ]]; then
    printf '%s\n' "${!var_name}"
  else
    printf '%s\n' "${!legacy_var_name:-}"
  fi
}

require_cmd gh
require_cmd jq
load_config

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

cmd="$1"
shift

# --- bounded read-only retry (rate limit / transient network) -------------------
#
# gh_read wraps READ-ONLY gh invocations with a bounded retry: transient
# failures (rate limit, network) are retried a fixed number of times and
# then reported with exit 3 — the "safe to retry later" exit shared with
# the dual-record sync deferral. Non-transient failures propagate
# immediately with gh's own exit code. Mutations are NEVER routed through
# this wrapper: a failed mutation is never retried automatically.
readonly GH_READ_ATTEMPTS=3
readonly GH_READ_RETRY_SLEEP=2
readonly GH_READ_TRANSIENT_EXIT=3
# Case-insensitive transient signatures matched against gh's stderr.
readonly GH_READ_TRANSIENT_RE='rate limit|error connecting|could not resolve host|timed out|HTTP 50[0-9]|bad gateway|service unavailable'

gh_read() {
  local attempt=1 err_file out rc err_text
  err_file="$(mktemp)"
  while :; do
    set +e
    out="$(gh "$@" 2>"$err_file")"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      rm -f "$err_file"
      printf '%s\n' "$out"
      return 0
    fi
    err_text="$(cat "$err_file")"
    if ! grep -qiE "$GH_READ_TRANSIENT_RE" "$err_file"; then
      rm -f "$err_file"
      printf '%s\n' "$err_text" >&2
      return "$rc"
    fi
    if [[ $attempt -ge $GH_READ_ATTEMPTS ]]; then
      rm -f "$err_file"
      printf '%s\n' "$err_text" >&2
      echo "read-only gh call failed after $GH_READ_ATTEMPTS attempts (transient): gh $*" >&2
      echo "safe to retry: no mutation was attempted" >&2
      return "$GH_READ_TRANSIENT_EXIT"
    fi
    echo "read-only gh call attempt $attempt failed (transient); retrying in ${GH_READ_RETRY_SLEEP}s" >&2
    sleep "$GH_READ_RETRY_SLEEP"
    attempt=$((attempt + 1))
  done
}

list_statuses() {
  local owner="$1"
  local project_number="$2"

  gh_read project field-list "$project_number" --owner "$owner" --format json \
    | jq -r --arg field "$CANONICAL_FIELD_NAME" '.fields[]
      | select(.name == $field)
      | .options[]
      | .name'
}

# --- shared GraphQL project-items engine (board ITEM query family) --------------
#
# ONE shared engine backs list-items, list-unassigned, item-id, item-state,
# the set-status item lookup, and the set-status verification re-read. gh
# project item-list (gh 2.45) is limit-bounded and returns neither
# assignees nor single-select option ids (values are flattened to top-level
# display-name keys), so every item read, lookup, and verification goes
# through this GraphQL join. Reads are pagination-safe: items are paged
# with first:100 cursor pages (bounded at PROJECT_ITEMS_MAX_PAGES; a board
# larger than the bound is listed partially with a stderr truncation
# warning).
#
# The page-1 query deliberately omits the cursor variable instead of
# relying on null-variable coercion: gh's -f/-F flags cannot express a
# JSON null portably, so follow-up pages use a query variant that declares
# $cursor and passes it as a plain string.

# One canonical query body; __QUERY_VARS__ and __ITEMS_ARGS__ are filled
# per page variant (bash ${var/pat/repl} replacements are literal).
project_items_query_body() {
  cat <<'EOF'
query__QUERY_VARS__ {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100__ITEMS_ARGS__) {
        nodes {
          id
          content {
            ... on Issue {
              number
              title
              url
              assignees(first: 10) {
                nodes { login }
              }
            }
            ... on PullRequest {
              number
              title
              url
              assignees(first: 10) {
                nodes { login }
              }
            }
          }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                optionId
                field {
                  ... on ProjectV2FieldCommon {
                    id
                  }
                }
              }
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}
EOF
}

# Page-1 query (no cursor) when $1 is empty; follow-up query (after:
# $cursor) when $1 is non-empty.
project_items_query() {
  local body vars items_args
  body="$(project_items_query_body)"
  if [[ -n "${1:-}" ]]; then
    vars='($projectId: ID!, $cursor: String!)'
    items_args=', after: $cursor'
  else
    vars='($projectId: ID!)'
    items_args=''
  fi
  body="${body/__QUERY_VARS__/$vars}"
  body="${body/__ITEMS_ARGS__/$items_args}"
  printf '%s' "$body"
}

# Fetch and curate the board's issue-linked items across bounded cursor
# pages. Prints a compact JSON array of
#   {item_id, issue_number, title, url, assignees, state, state_option_id}
# where "state" is the REMOTE option name preserved as-is (never translated
# to the canonical name; founder-confirmed 2026-08-23) and state_option_id
# is the internal, name-agnostic key used for filtering, verification, and
# canonical reverse-mapping. Draft items (content without a number) are
# not issue-linked and are dropped.
fetch_project_items() {
  local owner="$1"
  local project_number="$2"

  local project_id field_id
  project_id="$(resolve_project_id_from_env)"
  if [[ -z "$project_id" ]]; then
    project_id="$(resolve_project_id "$owner" "$project_number" "$(resolve_owner_type "")")" || exit $?
  fi
  if [[ -z "$project_id" || "$project_id" == "null" ]]; then
    echo "Could not resolve project ID" >&2
    exit 1
  fi
  field_id="$(resolve_state_field_id "$owner" "$project_number")" || exit $?
  if [[ -z "$field_id" || "$field_id" == "null" ]]; then
    echo "Could not resolve Workflow State field ID" >&2
    exit 1
  fi

  # NOTE: bash does not reliably inherit `set -e` through nested command
  # substitution subshells, so every capture below handles its failure
  # explicitly — a transient-exhausted read (exit 3) must abort the fetch,
  # never continue with an empty payload.
  local payload nodes items='[]' has_next cursor page=0
  while :; do
    page=$((page + 1))
    if [[ "$page" -eq 1 ]]; then
      payload="$(gh_read api graphql \
        -f query="$(project_items_query "")" \
        -f projectId="$project_id")" || exit $?
    else
      payload="$(gh_read api graphql \
        -f query="$(project_items_query after)" \
        -f projectId="$project_id" \
        -f cursor="$cursor")" || exit $?
    fi
    nodes="$(jq -c '.data.node.items.nodes // []' <<<"$payload")" || exit $?
    items="$(jq -cn --argjson acc "$items" --argjson page "$nodes" '$acc + $page')" || exit $?
    has_next="$(jq -r '.data.node.items.pageInfo.hasNextPage // false' <<<"$payload")" || exit $?
    cursor="$(jq -r '.data.node.items.pageInfo.endCursor // ""' <<<"$payload")" || exit $?
    if [[ "$has_next" != "true" ]]; then
      break
    fi
    if [[ -z "$cursor" ]]; then
      echo "warning: board reported another page but no cursor; stopping after page $page" >&2
      break
    fi
    if [[ "$page" -ge "$PROJECT_ITEMS_MAX_PAGES" ]]; then
      echo "warning: board listing truncated at the pagination bound (${PROJECT_ITEMS_MAX_PAGES} pages x ${PROJECT_ITEMS_PAGE_SIZE} items)" >&2
      break
    fi
  done

  jq -c --arg field "$field_id" '[.[]
    | select(.content.number != null)
    | {
        item_id: .id,
        issue_number: .content.number,
        title: (.content.title // ""),
        url: (.content.url // ""),
        assignees: [(.content.assignees.nodes // [])[] | .login],
        state: ([.fieldValues.nodes[] | select(.field.id == $field) | .name][0] // ""),
        state_option_id: ([.fieldValues.nodes[] | select(.field.id == $field) | .optionId][0] // "")
      }]' <<<"$items"
}

# Find ONE issue-linked board item by issue number through the shared
# paginated engine. Prints the internal record
# {item_id, issue_number, title, url, state, state_option_id} as a single
# line, or fails (exit 1, stderr naming the issue) when the issue has no
# board item. state_option_id is the name-agnostic key; public outputs
# reshape this record and never print option ids.
find_board_item() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"

  local out
  out="$(fetch_project_items "$owner" "$project_number")" || exit $?
  out="$(jq -c --argjson n "$issue_number" '.[] | select(.issue_number == $n)' <<<"$out")" || exit $?
  if [[ -z "$out" ]]; then
    echo "No project item found for issue #$issue_number on project $project_number (owner $owner)" >&2
    exit 1
  fi
  printf '%s\n' "$out"
}

# Curated board item query contract (issue #46): list-items prints
# {item_id, issue_number, title, state, assignees, url} per issue-linked
# item from the shared GraphQL items query — assignees are REAL. An
# optional state name filters by canonical state via optionId: the name
# resolves to its option id with the SAME resolver as set-status (env pin
# -> remote exact-name discovery), so filtering stays correct under any
# remote display name (e.g. a legacy rename); the printed state is always
# the remote option name as-is.
list_items() {
  local owner="$1"
  local project_number="$2"
  local state_name="${3:-}"

  local option_id=""
  if [[ -n "$state_name" ]]; then
    option_id="$(resolve_state_option_id "$owner" "$project_number" "$state_name")"
    if [[ -z "$option_id" || "$option_id" == "null" ]]; then
      unresolved_state_error "$state_name"
    fi
  fi

  local items
  items="$(fetch_project_items "$owner" "$project_number")"

  if [[ -n "$option_id" ]]; then
    jq -c --arg option "$option_id" \
      '.[] | select(.state_option_id == $option)
        | {item_id, issue_number, title, state, assignees, url}' <<<"$items"
  else
    jq -c '.[] | {item_id, issue_number, title, state, assignees, url}' <<<"$items"
  fi
}

# Issue-linked items with ZERO assignees, same curated shape as list-items
# (issue #46): the board query for "what work has no assignee".
list_unassigned() {
  local owner="$1"
  local project_number="$2"

  local items
  items="$(fetch_project_items "$owner" "$project_number")"

  jq -c '.[] | select((.assignees | length) == 0)
    | {item_id, issue_number, title, state, assignees, url}' <<<"$items"
}

add_issue() {
  local owner="$1"
  local project_number="$2"
  local issue_url="$3"

  gh project item-add "$project_number" --owner "$owner" --url "$issue_url"
}

gh_item_edit() {
  local item_id="$1"
  local field_id="$2"
  local option_id="$3"
  local project_id
  project_id="$(resolve_project_id_from_env)"
  require_value "PROJECT_ID" "$project_id"

  gh project item-edit \
    --id "$item_id" \
    --project-id "$project_id" \
    --field-id "$field_id" \
    --single-select-option-id "$option_id"
}

project_id_query() {
  local owner_type="$1"
  if [[ "$owner_type" == "user" ]]; then
    cat <<'EOF'
query($owner: String!, $number: Int!) {
  user(login: $owner) {
    projectV2(number: $number) {
      id
    }
  }
}
EOF
  else
    cat <<'EOF'
query($owner: String!, $number: Int!) {
  organization(login: $owner) {
    projectV2(number: $number) {
      id
    }
  }
}
EOF
  fi
}

resolve_project_id() {
  local owner="$1"
  local project_number="$2"
  local owner_type="$3"
  local query
  query="$(project_id_query "$owner_type")"

  gh_read api graphql -f query="$query" -F owner="$owner" -F number="$project_number" \
    | jq -r '.data.organization.projectV2.id // .data.user.projectV2.id'
}

# Shared set-status-style guidance for an unresolvable Workflow State name
# (set-status and the list-items canonical-state filter). Always exits 1.
unresolved_state_error() {
  local state_name="$1"
  echo "Could not resolve Workflow State option ID for '$state_name'." >&2
  echo "The remote board may still use a legacy option name for this state" >&2
  echo "(e.g. 'Inbox' instead of 'Open', 'Shaping' instead of 'Backlog')." >&2
  echo "This helper never renames remote board options. Either pass the exact" >&2
  echo "remote option name, or rename the option in GitHub with explicit" >&2
  echo "founder approval and then record the verified IDs in .github-project.env." >&2
  exit 1
}

print_item_id() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"

  # Pagination-safe lookup through the shared GraphQL engine; not-found is
  # a hard failure (issue #46): exit non-zero with stderr naming the issue
  # instead of silently printing nothing.
  local item
  item="$(find_board_item "$owner" "$project_number" "$issue_number")"
  jq -c '{item_id, issue_number, title, url, state}' <<<"$item"
}

resolve_state_field_id() {
  local owner="$1"
  local project_number="$2"

  local env_field_id
  env_field_id="$(resolve_state_field_id_from_env)"

  if [[ -n "$env_field_id" ]]; then
    printf '%s\n' "$env_field_id"
  else
    gh_read project field-list "$project_number" --owner "$owner" --format json \
      | jq -r --arg field "$CANONICAL_FIELD_NAME" '.fields[]
        | select(.name == $field)
        | .id'
  fi
}

resolve_state_option_id() {
  local owner="$1"
  local project_number="$2"
  local state_name="$3"

  local env_option_id
  env_option_id="$(resolve_state_option_id_from_env "$state_name")"

  if [[ -n "$env_option_id" ]]; then
    printf '%s\n' "$env_option_id"
  else
    gh_read project field-list "$project_number" --owner "$owner" --format json \
      | jq -r --arg field "$CANONICAL_FIELD_NAME" --arg state "$state_name" '.fields[]
        | select(.name == $field)
        | .options[]
        | select(.name == $state)
        | .id'
  fi
}

# The four-field curated board mutation contract shared by set-status,
# set-status-id, and next-status.
emit_item_mutation_result() {
  jq -c '{issue_number, title, state, url}' <<<"$1"
}

set_status_id() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"
  local option_id="$4"
  local owner_type="${5:-org}"

  local project_id field_id item item_id
  project_id="$(resolve_project_id_from_env)"
  if [[ -z "$project_id" ]]; then
    project_id="$(resolve_project_id "$owner" "$project_number" "$owner_type")"
  fi
  field_id="$(resolve_state_field_id "$owner" "$project_number")"

  if [[ -z "$project_id" || "$project_id" == "null" ]]; then
    echo "Could not resolve project ID" >&2
    exit 1
  fi
  if [[ -z "$field_id" || "$field_id" == "null" ]]; then
    echo "Could not resolve Workflow State field ID" >&2
    exit 1
  fi
  if [[ -z "$option_id" || "$option_id" == "null" ]]; then
    echo "Could not resolve Workflow State option ID" >&2
    exit 1
  fi

  # Pagination-safe, name-agnostic item lookup through the shared engine.
  item="$(find_board_item "$owner" "$project_number" "$issue_number")"
  item_id="$(jq -r '.item_id' <<<"$item")"

  # Idempotent by OPTION id: an item already in the requested state is
  # verified as-is with no duplicate mutation.
  if [[ "$(jq -r '.state_option_id' <<<"$item")" == "$option_id" ]]; then
    echo "set-status: issue #$issue_number is already in the requested Workflow State (no mutation)" >&2
    emit_item_mutation_result "$item"
    return 0
  fi

  # Exactly one mutation attempt; mutations are never retried.
  gh project item-edit \
    --id "$item_id" \
    --project-id "$project_id" \
    --field-id "$field_id" \
    --single-select-option-id "$option_id" >/dev/null

  # Verified by OPTION id, independent of the remote display name: a
  # mismatch after the edit is a hard failure, never a stale echo of the
  # request.
  local verify
  verify="$(find_board_item "$owner" "$project_number" "$issue_number")"
  if [[ "$(jq -r '.state_option_id' <<<"$verify")" != "$option_id" ]]; then
    echo "set-status verification failed for issue #$issue_number: the board did not report the requested Workflow State after the edit (found '$(jq -r '.state' <<<"$verify")')" >&2
    exit 1
  fi
  emit_item_mutation_result "$verify"
}

set_status() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"
  local state_name="$4"
  local owner_type="${5:-org}"

  local option_id
  option_id="$(resolve_state_option_id "$owner" "$project_number" "$state_name")"
  if [[ -z "$option_id" || "$option_id" == "null" ]]; then
    unresolved_state_error "$state_name"
  fi

  set_status_id "$owner" "$project_number" "$issue_number" "$option_id" "$owner_type"
}

# next-status enforces a precondition before the transition: the item must
# currently sit in the claimed CURRENT state, matched by OPTION id (never
# by the remote display name). A failed precondition exits non-zero with
# the actual board state on stderr and performs no mutation.
next_status() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"
  local current_state="$4"
  local next_state="$5"
  local owner_type="${6:-org}"

  local current_option_id next_option_id item
  current_option_id="$(resolve_state_option_id "$owner" "$project_number" "$current_state")"
  if [[ -z "$current_option_id" || "$current_option_id" == "null" ]]; then
    unresolved_state_error "$current_state"
  fi
  next_option_id="$(resolve_state_option_id "$owner" "$project_number" "$next_state")"
  if [[ -z "$next_option_id" || "$next_option_id" == "null" ]]; then
    unresolved_state_error "$next_state"
  fi

  item="$(find_board_item "$owner" "$project_number" "$issue_number")"
  if [[ "$(jq -r '.state_option_id' <<<"$item")" != "$current_option_id" ]]; then
    echo "next-status precondition failed for issue #$issue_number: expected current state '$current_state', board reports '$(jq -r '.state' <<<"$item")'" >&2
    echo "Re-read the item state (item-state $issue_number) and re-run with the correct current state; no mutation was made" >&2
    exit 1
  fi

  set_status_id "$owner" "$project_number" "$issue_number" "$next_option_id" "$owner_type"
}

# Canonical Workflow State names, used ONLY to reverse-map a board option
# id back to its canonical name for the read-only item-state recovery
# output (the remote display name is never rewritten or translated
# elsewhere).
readonly CANONICAL_STATE_NAMES=(
  "Open"
  "Backlog"
  "Need attentions"
  "Ready"
  "In Progress"
  "In Review"
  "Ready to Merge"
  "Blocked"
  "Done"
)

canonical_state_for_option_id() {
  local option_id="$1"
  local name pinned
  for name in "${CANONICAL_STATE_NAMES[@]}"; do
    pinned="$(resolve_state_option_id_from_env "$name")"
    if [[ -n "$pinned" && "$pinned" == "$option_id" ]]; then
      printf '%s\n' "$name"
      return 0
    fi
  done
  return 1
}

# Read-only board-state recovery: prints where an issue's board item
# actually sits right now. "state" is the REMOTE option name as-is;
# "canonical_state" is reverse-mapped from the item's option id against
# the env-pinned canonical option IDs (null when the option id is unknown
# locally). Never mutates anything — safe to run after any failed or
# interrupted status mutation.
item_state() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"

  local item canonical=""
  item="$(find_board_item "$owner" "$project_number" "$issue_number")"
  if canonical="$(canonical_state_for_option_id "$(jq -r '.state_option_id' <<<"$item")")"; then
    :
  else
    canonical=""
  fi
  jq -c --arg canonical "$canonical" \
    '{item_id, issue_number, title, state, url,
      canonical_state: (if $canonical == "" then null else $canonical end)}' <<<"$item"
}

# --- issue subcommands (env-resolved repo; curated mutation results) ----------

# Curated mutation-verification contract (founder standard, issue #45):
# every mutator returns a useful structured result, never raw gh output.
# Where gh's mutation response already carries the identity (issue/PR
# create print the object URL) the response is reused and no extra read
# happens; where it does not (edits/closes/merges print at most a URL or
# confirmation text with no post-mutation state) the object is re-read
# AFTER the mutation and the re-read IS the verification — the same
# pattern as set-status. issue-comment and pr-comment are the deliberate
# exceptions: their URL permalink output IS the useful result.

# The four-field mutation contract for issue/PR mutators.
readonly MUTATION_VIEW_FIELDS="number,title,state,url"

verify_issue_mutation() {
  local repo="$1" number="$2"
  gh issue view "$number" --json "$MUTATION_VIEW_FIELDS" --repo "$repo" \
    | jq '{number, title, state, url}'
}

verify_pr_mutation() {
  local repo="$1" number="$2"
  gh pr view "$number" --json "$MUTATION_VIEW_FIELDS" --repo "$repo" \
    | jq '{number, title, state, url}'
}

# Emit the four-field contract from an already-verified create identity
# (mutation URL response + caller title); a freshly created issue/PR is
# deterministically OPEN.
emit_created_mutation_result() {
  local number="$1" title="$2" url="$3"
  jq -n --argjson number "$number" --arg title "$title" --arg state "OPEN" --arg url "$url" \
    '{number: $number, title: $title, state: $state, url: $url}'
}

# True when the caller already chose an output shape for a gh issue read
# command, disabling the curated JSON defaults.
has_format_flag() {
  local a
  for a in "$@"; do
    case "$a" in
      --json|--jq|--template|--comments|--web)
        return 0
        ;;
    esac
  done
  return 1
}

# The env repo always wins: user flags come first, --repo "$repo" last.
issue_create() {
  local repo="$1" title="$2"
  shift 2
  gh issue create --title "$title" "$@" --repo "$repo"
}

issue_view() {
  local repo="$1" number="$2"
  shift 2
  if has_format_flag "$@"; then
    gh issue view "$number" "$@" --repo "$repo"
  else
    # Offline fallback: serve the local record (read-only) when GitHub is
    # unreachable and a local record exists; never write the record.
    local out
    if out="$(gh issue view "$number" --json "$ISSUE_VIEW_FIELDS" "$@" --repo "$repo")"; then
      printf '%s\n' "$out"
    elif issue_view_local_fallback "$number"; then
      :
    else
      exit 1
    fi
  fi
}

issue_list() {
  local repo="$1"
  shift
  if has_format_flag "$@"; then
    gh issue list "$@" --repo "$repo"
  else
    local out
    if out="$(gh issue list --json "$ISSUE_LIST_FIELDS" "$@" --repo "$repo")"; then
      printf '%s\n' "$out"
    elif issue_list_local_fallback; then
      :
    else
      exit 1
    fi
  fi
}

# Mutate, then re-read: gh issue edit/close print only the issue URL, which
# carries no post-mutation state, so the curated output is a verified read.
issue_edit() {
  local repo="$1" number="$2"
  shift 2
  gh issue edit "$number" "$@" --repo "$repo" >/dev/null
  verify_issue_mutation "$repo" "$number"
}

issue_comment() {
  local repo="$1" number="$2"
  shift 2
  gh issue comment "$number" "$@" --repo "$repo"
}

issue_close() {
  local repo="$1" number="$2"
  shift 2
  gh issue close "$number" "$@" --repo "$repo" >/dev/null
  verify_issue_mutation "$repo" "$number"
}

# --- PR/review subcommands (env-resolved repo; curated mutation results) -------

# The env repo always wins: user flags come first, --repo "$repo" last.
# gh pr create prints the new PR URL: reuse it (number + url) plus the
# caller's title and the deterministic OPEN state — no verification
# re-read. If the number cannot be parsed from the response, fall back to
# printing the raw response with a warning instead of failing a mutation
# that succeeded.
pr_create() {
  local repo="$1" title="$2"
  shift 2
  local out number url
  out="$(gh pr create --title "$title" "$@" --repo "$repo")"
  number="$(parse_pr_url_number "$out")"
  if [[ -z "$number" ]]; then
    echo "warning: PR created on GitHub but its number could not be parsed from output" >&2
    printf '%s\n' "$out"
    return 0
  fi
  url="$(printf '%s' "$out" | head -1 | sed 's/[[:space:]]*$//')"
  emit_created_mutation_result "$number" "$title" "$url"
}

pr_view() {
  local repo="$1" number="$2"
  shift 2
  if has_format_flag "$@"; then
    gh pr view "$number" "$@" --repo "$repo"
  else
    gh pr view "$number" --json "$PR_VIEW_FIELDS" "$@" --repo "$repo"
  fi
}

pr_list() {
  local repo="$1"
  shift
  if has_format_flag "$@"; then
    gh pr list "$@" --repo "$repo"
  else
    gh pr list --json "$PR_LIST_FIELDS" "$@" --repo "$repo"
  fi
}

pr_comment() {
  local repo="$1" number="$2"
  shift 2
  gh pr comment "$number" "$@" --repo "$repo"
}

# Policy-controlled: pass caller flags through only; never inject --admin
# or bypass approval gates. gh pr close prints only confirmation text with
# no post-mutation state, so the curated output is a verification re-read.
pr_close() {
  local repo="$1" number="$2"
  shift 2
  gh pr close "$number" "$@" --repo "$repo" >/dev/null
  verify_pr_mutation "$repo" "$number"
}

# Policy-controlled: pass caller flags through only; never inject --admin
# or bypass approval gates. gh pr merge prints only confirmation text with
# no post-mutation state, so the curated output is a verification re-read
# (state MERGED once the merge lands, OPEN while an --auto merge pends).
pr_merge() {
  local repo="$1" number="$2"
  shift 2
  gh pr merge "$number" "$@" --repo "$repo" >/dev/null
  verify_pr_mutation "$repo" "$number"
}

# gh pr checks has no --json flag; curate its stable tabular output
# (name <TAB> status <TAB> elapsed <TAB> url) into JSON by default. gh's
# exit status (any check failing or pending) still propagates.
pr_checks() {
  local repo="$1" number="$2"
  shift 2
  if has_format_flag "$@"; then
    gh pr checks "$number" "$@" --repo "$repo"
  else
    gh pr checks "$number" --repo "$repo" \
      | jq -R -s 'split("\n")
        | map(split("\t") | select(length >= 4)
          | { name: .[0], status: .[1], elapsed: .[2], url: .[3] })'
  fi
}

# Fixed parameterized GraphQL mutation for in-thread review-comment
# replies. The query text is a constant; user input travels only as
# GraphQL variables, never inside the query text.
pr_review_reply_query() {
  cat <<'EOF'
mutation($commentId: ID!, $body: String!) {
  addPullRequestReviewCommentReply(input: {
    pullRequestReviewCommentId: $commentId,
    body: $body
  }) {
    comment {
      url
    }
  }
}
EOF
}

# The mutation addresses the comment by its global node ID, so no repo
# reaches the GraphQL request itself; the dispatcher still enforces the
# env-only repo contract (require_repo) like every other pr-* subcommand.
pr_review_reply() {
  local comment_id="$1" body="$2"
  gh api graphql \
    -f query="$(pr_review_reply_query)" \
    -f commentId="$comment_id" \
    -f body="$body"
}

# --- CI/testing subcommands (gh run / gh workflow wrappers, env-resolved repo) ---

# The env repo always wins: user flags come first, --repo "$repo" last.
run_view() {
  local repo="$1" number="$2"
  shift 2
  if has_format_flag "$@"; then
    gh run view "$number" "$@" --repo "$repo"
  else
    gh run view "$number" --json "$RUN_VIEW_FIELDS" "$@" --repo "$repo"
  fi
}

run_list() {
  local repo="$1"
  shift
  if has_format_flag "$@"; then
    gh run list "$@" --repo "$repo"
  else
    gh run list --json "$RUN_LIST_FIELDS" "$@" --repo "$repo"
  fi
}

workflow_list() {
  local repo="$1"
  shift
  if has_format_flag "$@"; then
    gh workflow list "$@" --repo "$repo"
  else
    gh workflow list --json "$WORKFLOW_LIST_FIELDS" "$@" --repo "$repo"
  fi
}

# Policy-controlled: pass caller flags through only; never inject --admin
# or bypass approval gates. The dispatch response carries no run id, so the
# curated summary reports the accepted dispatch without inventing a run
# read; use run-list / run-view for run-level summaries.
workflow_run() {
  local repo="$1" workflow_ref="$2"
  shift 2
  gh workflow run "$workflow_ref" "$@" --repo "$repo" >/dev/null
  jq -n --arg workflow "$workflow_ref" --arg repo "$repo" \
    '{workflow: $workflow, repo: $repo, status: "dispatched"}'
}

# --- release subcommands (gh release wrappers, env-resolved repo) ---------------

# Canonical release-tag validation (FR-07): a small, local check enforcing
# the Git tag (refname) rules release tags must obey, so invalid tags fail
# before gh is invoked. Deliberately not a generic validators framework
# (KISS): it validates release tags only.
validate_release_tag() {
  local tag="$1" cmd_name="$2"

  if [[ -z "$tag" ]]; then
    echo "Missing required value: release tag for $cmd_name" >&2
    exit 1
  fi

  local reason=""
  case "$tag" in
    -*)           reason="must not begin with '-'" ;;
    .*|*.|*.lock) reason="must not begin or end with '.', or end with '.lock'" ;;
    /*|*/|*//*)   reason="must not begin or end with '/', or contain '//'" ;;
    "@")          reason="must not be the single character '@'" ;;
    *".."*)       reason="must not contain '..'" ;;
    *@{*)         reason="must not contain '@{'" ;;
  esac
  if [[ -z "$reason" ]]; then
    if [[ "$tag" == *[[:space:]]* || "$tag" == *[[:cntrl:]]* ]]; then
      reason="must not contain whitespace or control characters"
    elif [[ "$tag" == *[\~\^\:\?\*\[]* || "$tag" == *'\'* ]]; then
      reason="must not contain '~', '^', ':', '?', '*', '[', or '\'"
    fi
  fi

  if [[ -n "$reason" ]]; then
    echo "Invalid release tag '$tag' for $cmd_name: $reason" >&2
    exit 1
  fi
}

# The env repo always wins: user flags come first, --repo "$repo" last.
# The tag is validated before gh is invoked. The mutation response is only
# the release URL (no name, draft, or prerelease state), so the curated
# summary is a verification re-read in the same shape as release-view.
release_create() {
  local repo="$1" tag="$2"
  shift 2
  validate_release_tag "$tag" "release-create"
  gh release create "$tag" "$@" --repo "$repo" >/dev/null
  gh release view "$tag" --json "$RELEASE_VIEW_FIELDS" --repo "$repo" \
    | jq '{name, tagName, targetCommitish, isDraft, isPrerelease, createdAt, publishedAt, author, body, url}'
}

release_list() {
  local repo="$1"
  shift
  if has_format_flag "$@"; then
    gh release list "$@" --repo "$repo"
  else
    gh release list --json "$RELEASE_LIST_FIELDS" "$@" --repo "$repo"
  fi
}

release_view() {
  local repo="$1" tag="$2"
  shift 2
  if has_format_flag "$@"; then
    gh release view "$tag" "$@" --repo "$repo"
  else
    gh release view "$tag" --json "$RELEASE_VIEW_FIELDS" "$@" --repo "$repo"
  fi
}

release_edit() {
  local repo="$1" tag="$2"
  shift 2
  validate_release_tag "$tag" "release-edit"
  gh release edit "$tag" "$@" --repo "$repo" >/dev/null
  gh release view "$tag" --json "$RELEASE_VIEW_FIELDS" --repo "$repo" \
    | jq '{name, tagName, targetCommitish, isDraft, isPrerelease, createdAt, publishedAt, author, body, url}'
}

# Policy-controlled and destructive: pass caller flags through only; never
# inject --admin, never default the --yes auto-confirm, and never bypass
# approval gates. The tag is validated before gh is invoked. The deleted
# release cannot be re-read; the curated summary reports the verified
# deletion (mutation success) with the release's canonical URL.
release_delete() {
  local repo="$1" tag="$2"
  shift 2
  validate_release_tag "$tag" "release-delete"
  gh release delete "$tag" "$@" --repo "$repo" >/dev/null
  jq -n --arg tagName "$tag" --arg url "https://github.com/$repo/releases/tag/$tag" \
    '{tagName: $tagName, url: $url, deleted: true}'
}

# --- milestone subcommands (thin gh api REST wrappers) -------------------------

# Curated, safe JSON shape for REST milestone payloads; the raw payload
# (node_id, creator, ...) is never echoed.
milestone_summary_jq() {
  jq '{ number, title, state, open_issues, closed_issues, due_on, url: .html_url }'
}

milestone_list() {
  local repo="$1" state="${2:-open}"
  case "$state" in
    open|closed|all) ;;
    *)
      echo "Invalid milestone state '$state' (expected open, closed, or all)" >&2
      exit 1
      ;;
  esac
  # Offline fallback: serve local spec records (read-only) when GitHub is
  # unreachable; never write the records.
  local out
  if out="$(gh api "repos/$repo/milestones?state=$state")"; then
    printf '%s\n' "$out" | jq '[.[] | { number, title, state, open_issues, closed_issues, due_on, url: .html_url }]'
  elif milestone_list_local_fallback; then
    :
  else
    exit 1
  fi
}

# --- dual-record local-first sync (T7) ------------------------------------------
#
# Local-first write model: mutating issue/milestone CRUD commands write or
# update the local Obsidian record under ANT_TEAM_DOCS_PROJECT_PATH first,
# then synchronize it to GitHub when online. Offline (or on GitHub failure)
# the local write is kept, marked pending_sync: true, and the command exits
# 3 naming the recovery command. Writes are atomic, slugified, and confined
# to {issue,spec}/ under the resolved base; the helper never runs Git on
# the vault.

# Exit code for "local write kept, GitHub sync deferred" (the offline
# queue). Distinct from hard failures so callers can retry issue-sync /
# milestone-sync safely.
readonly SYNC_DEFERRED_EXIT=3

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# Resolve and validate the local docs base. Fails clearly (before gh) when
# ANT_TEAM_DOCS_PROJECT_PATH is missing or invalid. A literal ~ is expanded
# against $HOME (git-like semantics; the env value may carry one).
resolve_docs_base() {
  local raw="${ANT_TEAM_DOCS_PROJECT_PATH:-}"
  if [[ -z "$raw" ]]; then
    echo "Missing required value: ANT_TEAM_DOCS_PROJECT_PATH" >&2
    echo "Set it in $CONFIG_ENV_FILE (local-first record writes need the docs project path)" >&2
    exit 1
  fi
  local base="${raw/#\~/$HOME}"
  if [[ "$base" != /* ]]; then
    echo "Invalid ANT_TEAM_DOCS_PROJECT_PATH '$raw': must be an absolute path" >&2
    exit 1
  fi
  if [[ ! -d "$base" ]]; then
    echo "Invalid ANT_TEAM_DOCS_PROJECT_PATH '$base': not a directory" >&2
    exit 1
  fi
  local canon
  canon="$(cd "$base" && pwd -P)" || {
    echo "Invalid ANT_TEAM_DOCS_PROJECT_PATH '$base': cannot resolve" >&2
    exit 1
  }
  printf '%s\n' "$canon"
}

# Deterministic filename slug: lowercase, [a-z0-9-] only, dashes collapsed,
# capped length. Titles cannot inject path separators, '..', or newlines
# into the filesystem write because everything outside [a-z0-9-] collapses
# to a dash before the filename is built.
slugify() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-')"
  s="${s#-}"; s="${s%-}"
  s="$(printf '%s' "$s" | cut -c1-48)"
  s="${s%-}"
  printf '%s' "${s:-untitled}"
}

# Malformed titles are rejected before any write or gh call (FR-07).
validate_record_title() {
  local title="$1" cmd_name="$2"
  if [[ -z "$title" ]]; then
    echo "Invalid title for $cmd_name: must not be empty" >&2
    exit 1
  fi
  if [[ "$title" == *[[:cntrl:]]* ]]; then
    echo "Invalid title for $cmd_name: must not contain control characters or newlines" >&2
    exit 1
  fi
  if [[ "$title" == *".."* || "$title" == -* ]]; then
    echo "Invalid title for $cmd_name: must not contain '..' or begin with '-'" >&2
    exit 1
  fi
}

validate_record_number() {
  local number="$1" what="$2" cmd_name="$3"
  if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "Invalid $what number '$number' for $cmd_name: must be a positive integer" >&2
    exit 1
  fi
}

# Managed (helper-owned) frontmatter keys per record type. Any other
# frontmatter line is local-only and preserved verbatim across writes.
readonly ISSUE_FM_KEYS="github_number github_url title state milestone labels assignees pending_sync last_synced_at"
readonly SPEC_FM_KEYS="github_milestone github_milestone_url title state due_on pending_sync last_synced_at"

fm_keys_for() {
  if [[ "$1" == "issue" ]]; then
    printf '%s\n' "$ISSUE_FM_KEYS"
  else
    printf '%s\n' "$SPEC_FM_KEYS"
  fi
}

record_field() {
  jq -r --arg k "$1" '.[$k] // ""' <<<"$RECORD_JSON"
}

# Read a local record into globals: RECORD_JSON (managed frontmatter),
# RECORD_PRESERVED (local-only frontmatter lines, verbatim), RECORD_BODY,
# RECORD_NOTES (content after the "## Local Notes" heading, heading
# excluded). Managed values are written as JSON scalars/arrays (valid YAML
# flow style); agent-edited plain strings are quoted on parse.
read_record() {
  local path="$1" type="$2"
  RECORD_PATH="$path"
  RECORD_JSON="{}"
  RECORD_PRESERVED=""
  RECORD_BODY=""
  RECORD_NOTES=""
  [[ -f "$path" ]] || return 1

  local keys
  keys="$(fm_keys_for "$type")"
  local in_fm=0 in_notes=0 line k v json_parts=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$in_fm" -eq 0 ]]; then
      if [[ "$line" == "---" ]]; then in_fm=1; fi
      continue
    fi
    if [[ "$in_fm" -eq 1 ]]; then
      if [[ "$line" == "---" ]]; then in_fm=2; continue; fi
      k="${line%%:*}"
      if [[ "$line" == "$k: "* && " $keys " == *" $k "* ]]; then
        v="${line#*: }"
        if ! printf '{"%s":%s}' "$k" "${v:-null}" | jq -e . >/dev/null 2>&1; then
          v="$(jq -rn --arg v "$v" '$v|tojson')"
        fi
        json_parts+="${json_parts:+,}\"$k\":${v:-null}"
      else
        RECORD_PRESERVED+="${RECORD_PRESERVED:+$'\n'}$line"
      fi
      continue
    fi
    if [[ "$in_notes" -eq 0 && "$line" =~ ^##\ Local\ Notes[[:space:]]*$ ]]; then
      in_notes=1
      continue
    fi
    if [[ "$in_notes" -eq 1 ]]; then
      RECORD_NOTES+="${RECORD_NOTES:+$'\n'}$line"
    else
      RECORD_BODY+="${RECORD_BODY:+$'\n'}$line"
    fi
  done < "$path"
  RECORD_JSON="$(printf '{%s}' "$json_parts" | jq -c . 2>/dev/null || echo '{}')"
  RECORD_BODY="$(trim_trailing_blanks "$RECORD_BODY")"
  RECORD_NOTES="$(trim_trailing_blanks "$RECORD_NOTES")"
  return 0
}

trim_trailing_blanks() {
  printf '%s' "$1" | awk '{ lines[NR] = $0 } END { e = NR; while (e > 0 && lines[e] ~ /^[[:space:]]*$/) e--; for (i = 1; i <= e; i++) print lines[i] }'
}

# Render one managed frontmatter line; strings/arrays use JSON encoding,
# which is valid YAML flow style.
fm_render_line() {
  jq -r --arg k "$1" '
    def line($k; $v):
      if $v == null then "\($k): null"
      elif ($v|type) == "string" or ($v|type) == "array" then "\($k): \($v|tojson)"
      else "\($k): \($v|tostring)" end;
    line($k; .[$k])' <<<"$RECORD_JSON"
}

# Render the full record markdown from the RECORD_* globals.
render_record() {
  local type="$1" k out="---"$'\n'
  for k in $(fm_keys_for "$type"); do
    out+="$(fm_render_line "$k")"$'\n'
  done
  if [[ -n "$RECORD_PRESERVED" ]]; then
    out+="$RECORD_PRESERVED"$'\n'
  fi
  out+="---"$'\n'
  if [[ -n "$RECORD_BODY" ]]; then
    out+="$RECORD_BODY"$'\n'$'\n'
  fi
  if [[ -n "$RECORD_NOTES" ]]; then
    out+="## Local Notes"$'\n'"$RECORD_NOTES"$'\n'
  fi
  printf '%s' "$out"
}

# Atomic, confined record write: temp file + rename inside the target
# directory; the resolved directory must be exactly <base>/<sub>.
write_record_atomic() {
  local path="$1" content="$2" base="$3" sub="$4"
  local fname="${path##*/}"
  case "$fname" in
    ISSUE-[0-9]*-*.md|SPEC-[0-9]*-*.md) ;;
    *)
      echo "Refusing local record write with unsafe filename '$fname'" >&2
      exit 1
      ;;
  esac
  case "$fname" in
    *..*|*/*)
      echo "Refusing local record write with unsafe filename '$fname'" >&2
      exit 1
      ;;
  esac
  local dir="${path%/*}"
  mkdir -p "$dir"
  local dir_canon base_canon
  dir_canon="$(cd "$dir" && pwd -P)"
  base_canon="$(cd "$base" && pwd -P)"
  if [[ "$dir_canon" != "$base_canon/$sub" ]]; then
    echo "Local record path escapes the confined base: $path" >&2
    exit 1
  fi
  local tmp="$dir/.${fname}.tmp.$$"
  if ! printf '%s' "$content" > "$tmp"; then
    rm -f "$tmp"
    echo "Local record write failed: $path" >&2
    exit 1
  fi
  mv -f "$tmp" "$path"
}

issue_record_path() {
  local base="$1" number="$2" slug="$3"
  printf '%s/issue/ISSUE-%s-%s.md' "$base" "$(printf '%03d' "$number")" "$slug"
}

spec_record_path() {
  local base="$1" number="$2" slug="$3"
  printf '%s/spec/SPEC-%s-%s.md' "$base" "$(printf '%03d' "$number")" "$slug"
}

find_issue_record() {
  local base="$1" number="$2" skip="${3:-}" f
  for f in "$base"/issue/ISSUE-*.md; do
    [[ -f "$f" ]] || continue
    [[ -n "$skip" && "$f" == "$skip" ]] && continue
    if grep -q "^github_number: $number$" "$f"; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}

find_spec_record() {
  local base="$1" number="$2" skip="${3:-}" f
  for f in "$base"/spec/SPEC-*.md; do
    [[ -f "$f" ]] || continue
    [[ -n "$skip" && "$f" == "$skip" ]] && continue
    if grep -q "^github_milestone: $number$" "$f"; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}

# Provisional local number for offline creates: highest known local number
# + 1. It is a placeholder only; the first online sync backfills the
# confirmed GitHub number (and renames the file to the canonical name).
next_provisional_number() {
  local base="$1" kind="$2" key dir prefix f n max=0
  if [[ "$kind" == "spec" ]]; then
    key="github_milestone"; dir="spec"; prefix="SPEC"
  else
    key="github_number"; dir="issue"; prefix="ISSUE"
  fi
  for f in "$base/$dir/$prefix"-*.md; do
    [[ -f "$f" ]] || continue
    n="$(sed -n "s/^$key: \([0-9][0-9]*\)$/\1/p" "$f" || true)"
    if [[ "$n" =~ ^[0-9]+$ ]]; then
      if (( n > max )); then max="$n"; fi
    fi
  done
  echo $((max + 1))
}

json_array() {
  if [[ $# -eq 0 ]]; then
    printf '[]'
  else
    printf '%s\0' "$@" | jq -Rs 'split("\u0000") | map(select(length > 0))'
  fi
}

new_issue_fm() {
  jq -n \
    --argjson number "$1" --arg url "$2" --arg title "$3" --arg state "$4" \
    --arg milestone "$5" --argjson labels "$6" --argjson assignees "$7" \
    --argjson pending "$8" --arg last "$9" \
    '{github_number: $number,
      github_url: (if $url == "" then null else $url end),
      title: $title,
      state: $state,
      milestone: (if $milestone == "" then null else $milestone end),
      labels: $labels,
      assignees: $assignees,
      pending_sync: $pending,
      last_synced_at: (if $last == "" then null else $last end)}'
}

new_spec_fm() {
  jq -n \
    --argjson number "$1" --arg url "$2" --arg title "$3" --arg state "$4" \
    --arg due "$5" --argjson pending "$6" --arg last "$7" \
    '{github_milestone: $number,
      github_milestone_url: (if $url == "" then null else $url end),
      title: $title,
      state: $state,
      due_on: (if $due == "" then null else $due end),
      pending_sync: $pending,
      last_synced_at: (if $last == "" then null else $last end)}'
}

# Keep the local write, mark it deferred, warn with the recovery command.
# Always exits non-zero (3): the GitHub mutation is still due.
sync_deferred() {
  local path="$1" recovery_cmd="$2" number="$3"
  echo "warning: local record kept at $path; GitHub sync deferred (pending_sync: true)" >&2
  echo "recovery: run 'gh_project_helper.sh $recovery_cmd $number' once online" >&2
  exit "$SYNC_DEFERRED_EXIT"
}

# --- local-writable payload extraction from pass-through gh flags --------------

parse_issue_create_payload() {
  PBODY=""; PLABELS=(); PASSIGNEES=(); PMILESTONE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --body) PBODY="$2"; shift 2 ;;
      --body-file)
        if [[ "$2" != "-" ]]; then
          if [[ ! -r "$2" ]]; then
            echo "Unreadable --body-file: $2" >&2
            exit 1
          fi
          PBODY="$(<"$2")"
        fi
        shift 2
        ;;
      --label) PLABELS+=("$2"); shift 2 ;;
      --assignee) PASSIGNEES+=("$2"); shift 2 ;;
      --milestone) PMILESTONE="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
}

parse_issue_edit_payload() {
  P_TITLE=""; P_BODY=""; P_BODY_SET=0
  PLABELS=(); PREMLABELS=(); PASSIGNEES=(); PMILESTONE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) P_TITLE="$2"; shift 2 ;;
      --body) P_BODY="$2"; P_BODY_SET=1; shift 2 ;;
      --body-file)
        if [[ "$2" != "-" ]]; then
          if [[ ! -r "$2" ]]; then
            echo "Unreadable --body-file: $2" >&2
            exit 1
          fi
          P_BODY="$(<"$2")"
        fi
        P_BODY_SET=1
        shift 2
        ;;
      --add-label) PLABELS+=("$2"); shift 2 ;;
      --remove-label) PREMLABELS+=("$2"); shift 2 ;;
      --assign) PASSIGNEES+=("$2"); shift 2 ;;
      --milestone) PMILESTONE="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
}

parse_milestone_edit_payload() {
  M_TITLE=""; M_TITLE_SET=0; M_DESC=""; M_DESC_SET=0; M_DUE=""; M_DUE_SET=0; M_STATE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f)
        case "$2" in
          title=*) M_TITLE="${2#title=}"; M_TITLE_SET=1 ;;
          description=*) M_DESC="${2#description=}"; M_DESC_SET=1 ;;
          due_on=*) M_DUE="${2#due_on=}"; M_DUE_SET=1 ;;
          state=*) M_STATE="${2#state=}" ;;
        esac
        shift 2
        ;;
      *) shift ;;
    esac
  done
}

# Apply parsed issue-edit payload to the managed frontmatter (merge, never
# clobber Local Notes or local-only frontmatter). Body replacement happens
# in the caller: this function runs inside a command substitution, so only
# its stdout (the merged JSON) escapes the subshell.
apply_issue_edits() {
  local json="$1"
  if [[ -n "$P_TITLE" ]]; then
    json="$(jq -c --arg t "$P_TITLE" '.title=$t' <<<"$json")"
  fi
  json="$(jq -c \
    --argjson add "$(json_array "${PLABELS[@]}")" \
    --argjson rem "$(json_array "${PREMLABELS[@]}")" \
    '.labels = ((((.labels // []) + $add) - $rem) | unique)' <<<"$json")"
  if [[ "${#PASSIGNEES[@]}" -gt 0 ]]; then
    json="$(jq -c --argjson add "$(json_array "${PASSIGNEES[@]}")" \
      '.assignees = (((.assignees // []) + $add) | unique)' <<<"$json")"
  fi
  if [[ -n "$PMILESTONE" ]]; then
    json="$(jq -c --arg m "$PMILESTONE" '.milestone=$m' <<<"$json")"
  fi
  printf '%s' "$json"
}

# --- local-first issue CRUD -----------------------------------------------------

parse_issue_url_number() {
  printf '%s' "$1" | grep -o 'issues/[0-9][0-9]*' | head -1 | grep -o '[0-9][0-9]*' || true
}

parse_pr_url_number() {
  printf '%s' "$1" | grep -o 'pull/[0-9][0-9]*' | head -1 | grep -o '[0-9][0-9]*' || true
}

# Backfill the confirmed GitHub identity into the record, clear the pending
# flag, and rename to the canonical filename when the number changed.
finalize_issue_record() {
  local base="$1" path="$2" confirmed="$3" url="$4" slug="$5" state="$6"
  RECORD_JSON="$(jq -c --argjson n "$confirmed" --arg u "$url" --arg s "$state" --arg t "$(now_iso)" \
    '.github_number=$n | .github_url=$u | .state=$s | .pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record issue)" "$base" issue
  local newpath
  newpath="$(issue_record_path "$base" "$confirmed" "$slug")"
  if [[ "$newpath" != "$path" ]]; then
    local other
    if other="$(find_issue_record "$base" "$confirmed" "$path")"; then
      echo "Refusing backfill: another local record already maps github_number $confirmed ($other)" >&2
      exit 1
    fi
    mv -f "$path" "$newpath"
    echo "local record: $newpath" >&2
  else
    echo "local record: $path" >&2
  fi
}

issue_local_first_create() {
  local repo="$1" title="$2"
  shift 2
  validate_record_title "$title" "issue-create"
  local base
  base="$(resolve_docs_base)"
  parse_issue_create_payload "$@"

  local slug number path reused=0
  slug="$(slugify "$title")"
  number="$(next_provisional_number "$base" issue)"
  path="$(issue_record_path "$base" "$number" "$slug")"

  if [[ -e "$path" ]]; then
    # Idempotent offline retry: a pending, never-confirmed record with the
    # same title is reused instead of duplicated.
    if read_record "$path" issue \
      && [[ "$(record_field github_url)" == "" ]] \
      && [[ "$(record_field title)" == "$title" ]]; then
      reused=1
    else
      echo "Local issue record already exists: $path" >&2
      echo "Use 'issue-edit <number>' or 'issue-sync <number>' instead of re-creating" >&2
      exit 1
    fi
  fi

  if [[ "$reused" -eq 1 ]]; then
    RECORD_JSON="$(jq -c '.pending_sync=true' <<<"$RECORD_JSON")"
    if [[ -n "$PBODY" ]]; then RECORD_BODY="$PBODY"; fi
  else
    RECORD_JSON="$(new_issue_fm "$number" "" "$title" "open" "${PMILESTONE:-}" \
      "$(json_array "${PLABELS[@]}")" "$(json_array "${PASSIGNEES[@]}")" true "")"
    RECORD_BODY="${PBODY:-}"
    RECORD_PRESERVED=""
    RECORD_NOTES=""
  fi
  # Local write FIRST; the record stays pending until GitHub confirms.
  write_record_atomic "$path" "$(render_record issue)" "$base" issue

  local out confirmed url
  if ! out="$(issue_create "$repo" "$title" "$@")"; then
    sync_deferred "$path" issue-sync "$number"
  fi
  confirmed="$(parse_issue_url_number "$out")"
  if [[ -z "$confirmed" ]]; then
    echo "warning: issue created on GitHub but its number could not be parsed from output" >&2
    echo "         local record kept pending at $path — verify on GitHub, then re-run issue-sync" >&2
    exit "$SYNC_DEFERRED_EXIT"
  fi
  url="$(printf '%s' "$out" | head -1 | sed 's/[[:space:]]*$//')"
  finalize_issue_record "$base" "$path" "$confirmed" "$url" "$slug" "open"
  # Curated mutation contract: reuse the mutation's URL response (verified
  # number + url) plus the caller's title and the deterministic OPEN
  # state; no verification re-read.
  emit_created_mutation_result "$confirmed" "$title" "$url"
}

issue_local_first_edit() {
  local repo="$1" number="$2"
  shift 2
  validate_record_number "$number" issue issue-edit
  local base
  base="$(resolve_docs_base)"
  parse_issue_edit_payload "$@"

  local path seeded=0
  if ! path="$(find_issue_record "$base" "$number")"; then
    mkdir -p "$base/issue"
    path="$(issue_record_path "$base" "$number" "$(slugify "${P_TITLE:-ISSUE-$number}")")"
    RECORD_JSON="$(new_issue_fm "$number" "https://github.com/$repo/issues/$number" \
      "${P_TITLE:-ISSUE-$number}" "open" "${PMILESTONE:-}" \
      "$(json_array "${PLABELS[@]}")" "$(json_array "${PASSIGNEES[@]}")" true "")"
    RECORD_BODY="${PBODY:-}"
    RECORD_PRESERVED=""
    RECORD_NOTES=""
    seeded=1
  else
    read_record "$path" issue
  fi
  if [[ "$seeded" -eq 0 ]]; then
    RECORD_JSON="$(apply_issue_edits "$RECORD_JSON")"
    if [[ "$P_BODY_SET" -eq 1 ]]; then
      RECORD_BODY="$P_BODY"
    fi
  fi
  RECORD_JSON="$(jq -c '.pending_sync=true' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record issue)" "$base" issue

  local out
  if ! out="$(issue_edit "$repo" "$number" "$@")"; then
    sync_deferred "$path" issue-sync "$number"
  fi
  RECORD_JSON="$(jq -c --arg t "$(now_iso)" '.pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record issue)" "$base" issue
  printf '%s\n' "$out"
}

issue_local_first_close() {
  local repo="$1" number="$2"
  shift 2
  validate_record_number "$number" issue issue-close
  local base
  base="$(resolve_docs_base)"

  local path
  if path="$(find_issue_record "$base" "$number")"; then
    read_record "$path" issue
    RECORD_JSON="$(jq -c '.state="closed" | .pending_sync=true' <<<"$RECORD_JSON")"
  else
    mkdir -p "$base/issue"
    path="$(issue_record_path "$base" "$number" untitled)"
    RECORD_JSON="$(new_issue_fm "$number" "https://github.com/$repo/issues/$number" \
      "ISSUE-$number" "closed" "" "[]" "[]" true "")"
    RECORD_BODY=""
    RECORD_PRESERVED=""
    RECORD_NOTES=""
  fi
  write_record_atomic "$path" "$(render_record issue)" "$base" issue

  local out
  if ! out="$(issue_close "$repo" "$number" "$@")"; then
    sync_deferred "$path" issue-sync "$number"
  fi
  RECORD_JSON="$(jq -c --arg t "$(now_iso)" '.pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record issue)" "$base" issue
  printf '%s\n' "$out"
}

# --- local-first milestone CRUD ---------------------------------------------------

milestone_create_raw() {
  local repo="$1" title="$2" description="${3:-}"
  if [[ -n "$description" ]]; then
    gh api "repos/$repo/milestones" -f title="$title" -f description="$description"
  else
    gh api "repos/$repo/milestones" -f title="$title"
  fi
}

milestone_local_first_create() {
  local repo="$1" title="$2" description="${3:-}"
  validate_record_title "$title" "milestone-create"
  local base
  base="$(resolve_docs_base)"

  local slug number path
  slug="$(slugify "$title")"
  number="$(next_provisional_number "$base" spec)"
  path="$(spec_record_path "$base" "$number" "$slug")"
  if [[ -e "$path" ]]; then
    echo "Local spec record already exists: $path" >&2
    echo "Use 'milestone-edit <number>' or 'milestone-sync <number>' instead of re-creating" >&2
    exit 1
  fi
  RECORD_JSON="$(new_spec_fm "$number" "" "$title" "open" "" true "")"
  RECORD_BODY="$description"
  RECORD_PRESERVED=""
  RECORD_NOTES=""
  write_record_atomic "$path" "$(render_record spec)" "$base" spec

  local raw confirmed murl
  if ! raw="$(milestone_create_raw "$repo" "$title" "$description")"; then
    sync_deferred "$path" milestone-sync "$number"
  fi
  confirmed="$(jq -r '.number // 0' <<<"$raw")"
  if [[ ! "$confirmed" =~ ^[0-9]+$ || "$confirmed" -eq 0 ]]; then
    echo "warning: milestone created on GitHub but its number could not be read from the response" >&2
    echo "         local record kept pending at $path — verify on GitHub, then re-run milestone-sync" >&2
    exit "$SYNC_DEFERRED_EXIT"
  fi
  murl="$(jq -r '.html_url // ""' <<<"$raw")"
  RECORD_JSON="$(jq -c --argjson n "$confirmed" --arg u "$murl" --arg t "$(now_iso)" \
    '.github_milestone=$n | .github_milestone_url=$u | .pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record spec)" "$base" spec
  local newpath
  newpath="$(spec_record_path "$base" "$confirmed" "$slug")"
  if [[ "$newpath" != "$path" ]]; then
    local other
    if other="$(find_spec_record "$base" "$confirmed" "$path")"; then
      echo "Refusing backfill: another local record already maps github_milestone $confirmed ($other)" >&2
      exit 1
    fi
    mv -f "$path" "$newpath"
    echo "local record: $newpath" >&2
  else
    echo "local record: $path" >&2
  fi
  printf '%s' "$raw" | milestone_summary_jq
}

milestone_local_first_edit() {
  local repo="$1" number="$2"
  shift 2
  validate_record_number "$number" milestone milestone-edit
  local base
  base="$(resolve_docs_base)"
  parse_milestone_edit_payload "$@"

  local path
  if path="$(find_spec_record "$base" "$number")"; then
    read_record "$path" spec
  else
    mkdir -p "$base/spec"
    path="$(spec_record_path "$base" "$number" "$(slugify "${M_TITLE:-SPEC-$number}")")"
    RECORD_JSON="$(new_spec_fm "$number" "https://github.com/$repo/milestone/$number" \
      "${M_TITLE:-SPEC-$number}" "open" "" true "")"
    RECORD_BODY="${M_DESC:-}"
    RECORD_PRESERVED=""
    RECORD_NOTES=""
  fi
  if [[ "$M_TITLE_SET" -eq 1 ]]; then
    RECORD_JSON="$(jq -c --arg t "$M_TITLE" '.title=$t' <<<"$RECORD_JSON")"
  fi
  if [[ "$M_DESC_SET" -eq 1 ]]; then
    RECORD_BODY="$M_DESC"
  fi
  if [[ "$M_DUE_SET" -eq 1 ]]; then
    RECORD_JSON="$(jq -c --arg d "$M_DUE" '.due_on=(if $d == "" then null else $d end)' <<<"$RECORD_JSON")"
  fi
  if [[ -n "$M_STATE" ]]; then
    RECORD_JSON="$(jq -c --arg s "$M_STATE" '.state=$s' <<<"$RECORD_JSON")"
  fi
  RECORD_JSON="$(jq -c '.pending_sync=true' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record spec)" "$base" spec

  local raw
  if ! raw="$(gh api -X PATCH "repos/$repo/milestones/$number" "$@")"; then
    sync_deferred "$path" milestone-sync "$number"
  fi
  RECORD_JSON="$(jq -c --arg t "$(now_iso)" '.pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record spec)" "$base" spec
  printf '%s' "$raw" | milestone_summary_jq
}

milestone_local_first_close() {
  local repo="$1" number="$2"
  validate_record_number "$number" milestone milestone-close
  local base
  base="$(resolve_docs_base)"

  local path
  if path="$(find_spec_record "$base" "$number")"; then
    read_record "$path" spec
    RECORD_JSON="$(jq -c '.state="closed" | .pending_sync=true' <<<"$RECORD_JSON")"
  else
    mkdir -p "$base/spec"
    path="$(spec_record_path "$base" "$number" untitled)"
    RECORD_JSON="$(new_spec_fm "$number" "https://github.com/$repo/milestone/$number" \
      "SPEC-$number" "closed" "" true "")"
    RECORD_BODY=""
    RECORD_PRESERVED=""
    RECORD_NOTES=""
  fi
  write_record_atomic "$path" "$(render_record spec)" "$base" spec

  local raw
  if ! raw="$(gh api -X PATCH "repos/$repo/milestones/$number" -f state=closed)"; then
    sync_deferred "$path" milestone-sync "$number"
  fi
  RECORD_JSON="$(jq -c --arg t "$(now_iso)" '.pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record spec)" "$base" spec
  printf '%s' "$raw" | milestone_summary_jq
}

# --- converge commands: issue-sync / milestone-sync --------------------------------

issue_sync_summary() {
  jq -n --argjson number "$(record_field github_number)" \
    --arg title "$(record_field title)" \
    --arg state "$(record_field state)" \
    --argjson pending "$(jq -r '.pending_sync // false' <<<"$RECORD_JSON")" \
    --arg last "$(jq -r '.last_synced_at // ""' <<<"$RECORD_JSON")" \
    --arg path "$RECORD_PATH" \
    '{number: $number, title: $title, state: $state, pending_sync: $pending,
      last_synced_at: (if $last == "" then null else $last end), record: $path}'
}

# Provisional record (never confirmed on GitHub): create the issue now and
# backfill the confirmed number, URL, and canonical filename.
issue_sync_provisional() {
  local repo="$1" number="$2" path="$3" base="$4"
  local title body args=()
  title="$(record_field title)"
  body="$RECORD_BODY"
  args=(--title "$title" --body "$body")
  local l
  while IFS= read -r l; do
    [[ -n "$l" ]] && args+=(--label "$l")
  done < <(jq -r '.labels // [] | .[]' <<<"$RECORD_JSON")
  local a
  while IFS= read -r a; do
    [[ -n "$a" ]] && args+=(--assignee "$a")
  done < <(jq -r '.assignees // [] | .[]' <<<"$RECORD_JSON")
  local m
  m="$(record_field milestone)"
  if [[ -n "$m" ]]; then args+=(--milestone "$m"); fi

  local out confirmed url
  if ! out="$(gh issue create "${args[@]}" --repo "$repo")"; then
    sync_deferred "$path" issue-sync "$number"
  fi
  confirmed="$(parse_issue_url_number "$out")"
  if [[ -z "$confirmed" ]]; then
    echo "issue-sync: GitHub created the issue but its number could not be parsed; record kept pending at $path" >&2
    exit "$SYNC_DEFERRED_EXIT"
  fi
  url="$(printf '%s' "$out" | head -1 | sed 's/[[:space:]]*$//')"
  local slug="${path##*/}"
  slug="${slug#ISSUE-[0-9]*-}"; slug="${slug%.md}"
  finalize_issue_record "$base" "$path" "$confirmed" "$url" "$slug" "open"
  echo "issue-sync: created GitHub issue #$confirmed and backfilled the local record" >&2
  issue_sync_summary
}

issue_sync() {
  local repo="$1" number="$2"
  validate_record_number "$number" issue issue-sync
  local base
  base="$(resolve_docs_base)"
  local path
  if ! path="$(find_issue_record "$base" "$number")"; then
    echo "No local issue record with github_number: $number under $base/issue/" >&2
    echo "Seed one first (issue-edit $number ... or issue-create while online)" >&2
    exit 1
  fi
  read_record "$path" issue

  if [[ -z "$(record_field github_url)" ]]; then
    issue_sync_provisional "$repo" "$number" "$path" "$base"
    return
  fi

  local view
  if ! view="$(gh issue view "$number" \
      --json number,title,body,state,labels,assignees,milestone,url,updatedAt \
      --repo "$repo")"; then
    echo "issue-sync: cannot reach GitHub for issue #$number" >&2
    exit 1
  fi

  local pending last gh_updated conflict=0 closure_pushed=0
  pending="$(jq -r '.pending_sync // false' <<<"$RECORD_JSON")"
  last="$(jq -r '.last_synced_at // ""' <<<"$RECORD_JSON")"
  gh_updated="$(jq -r '.updatedAt // ""' <<<"$view")"
  if [[ "$pending" == true && -n "$last" && -n "$gh_updated" && "$gh_updated" > "$last" ]]; then
    conflict=1
  fi

  if [[ "$pending" == true ]]; then
    # Push pending durable content (title, body): local record wins.
    local title body out
    title="$(record_field title)"
    body="$RECORD_BODY"
    if ! out="$(gh issue edit "$number" --title "$title" --body "$body" --repo "$repo")"; then
      sync_deferred "$path" issue-sync "$number"
    fi
    # Push closure intent when GitHub is still open.
    local lstate view_state
    lstate="$(record_field state)"
    view_state="$(jq -r '.state // "open"' <<<"$view")"
    if [[ "$lstate" == "closed" && "$view_state" != "closed" ]]; then
      if ! out="$(gh issue close "$number" --repo "$repo")"; then
        sync_deferred "$path" issue-sync "$number"
      fi
      closure_pushed=1
    fi
  fi

  # Pull execution-state fields: GitHub wins. The view predates any push we
  # just made, so a closure we pushed ourselves must not be pulled back open.
  # Label/assignee values tolerate plain strings as well as gh's objects.
  local gstate glabels gassignees gmilestone gurl
  gstate="$(jq -r '.state // "open"' <<<"$view")"
  if [[ "$closure_pushed" -eq 1 ]]; then
    gstate="closed"
  fi
  glabels="$(jq -c '[(.labels // []) | .[] | if type == "string" then . else .name end]' <<<"$view")"
  gassignees="$(jq -c '[(.assignees // []) | .[] | if type == "string" then . else .login end]' <<<"$view")"
  gmilestone="$(jq -r '.milestone.title // ""' <<<"$view")"
  gurl="$(jq -r '.url // ""' <<<"$view")"

  if [[ "$conflict" -eq 1 ]]; then
    echo "conflict on issue #$number: local record and GitHub both changed since the last sync" >&2
    if [[ "$(jq -r '.title // ""' <<<"$view")" != "$(record_field title)" ]]; then
      echo "- title: resolved toward the local record (pushed)" >&2
    fi
    if [[ "$(jq -r '.body // ""' <<<"$view")" != "$RECORD_BODY" ]]; then
      echo "- body: resolved toward the local record (pushed)" >&2
    fi
    if [[ "$glabels" != "$(jq -c '.labels // []' <<<"$RECORD_JSON")" ]]; then
      echo "- labels: resolved toward GitHub (pulled)" >&2
    fi
    if [[ "$gassignees" != "$(jq -c '.assignees // []' <<<"$RECORD_JSON")" ]]; then
      echo "- assignees: resolved toward GitHub (pulled)" >&2
    fi
  fi

  RECORD_JSON="$(jq -c \
    --arg s "$gstate" --argjson labels "$glabels" --argjson assignees "$gassignees" \
    --arg m "$gmilestone" --arg u "$gurl" --arg t "$(now_iso)" \
    '.state=$s | .labels=$labels | .assignees=$assignees
      | .milestone=(if $m == "" then null else $m end)
      | .github_url=(if $u == "" then .github_url else $u end)
      | .pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  if [[ "$pending" != true && -z "$RECORD_BODY" ]]; then
    # Backfill only: durable body is local-authored; pull it just once when
    # the local record has none and nothing is pending.
    RECORD_BODY="$(jq -r '.body // ""' <<<"$view")"
  fi
  write_record_atomic "$path" "$(render_record issue)" "$base" issue
  issue_sync_summary
}

milestone_sync_summary() {
  jq -n --argjson number "$(record_field github_milestone)" \
    --arg title "$(record_field title)" \
    --arg state "$(record_field state)" \
    --argjson pending "$(jq -r '.pending_sync // false' <<<"$RECORD_JSON")" \
    --arg last "$(jq -r '.last_synced_at // ""' <<<"$RECORD_JSON")" \
    --arg path "$RECORD_PATH" \
    '{number: $number, title: $title, state: $state, pending_sync: $pending,
      last_synced_at: (if $last == "" then null else $last end), record: $path}'
}

milestone_sync_provisional() {
  local repo="$1" number="$2" path="$3" base="$4"
  local title body raw confirmed murl
  title="$(record_field title)"
  body="$RECORD_BODY"
  if ! raw="$(gh api "repos/$repo/milestones" -f title="$title" -f description="$body")"; then
    sync_deferred "$path" milestone-sync "$number"
  fi
  confirmed="$(jq -r '.number // 0' <<<"$raw")"
  if [[ ! "$confirmed" =~ ^[0-9]+$ || "$confirmed" -eq 0 ]]; then
    echo "milestone-sync: GitHub created the milestone but its number could not be read; record kept pending at $path" >&2
    exit "$SYNC_DEFERRED_EXIT"
  fi
  murl="$(jq -r '.html_url // ""' <<<"$raw")"
  RECORD_JSON="$(jq -c --argjson n "$confirmed" --arg u "$murl" --arg t "$(now_iso)" \
    '.github_milestone=$n | .github_milestone_url=$u | .pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  write_record_atomic "$path" "$(render_record spec)" "$base" spec
  local slug="${path##*/}"
  slug="${slug#SPEC-[0-9]*-}"; slug="${slug%.md}"
  local newpath
  newpath="$(spec_record_path "$base" "$confirmed" "$slug")"
  if [[ "$newpath" != "$path" ]]; then
    local other
    if other="$(find_spec_record "$base" "$confirmed" "$path")"; then
      echo "Refusing backfill: another local record already maps github_milestone $confirmed ($other)" >&2
      exit 1
    fi
    mv -f "$path" "$newpath"
  fi
  echo "milestone-sync: created GitHub milestone #$confirmed and backfilled the local record" >&2
  milestone_sync_summary
}

milestone_sync() {
  local repo="$1" number="$2"
  validate_record_number "$number" milestone milestone-sync
  local base
  base="$(resolve_docs_base)"
  local path
  if ! path="$(find_spec_record "$base" "$number")"; then
    echo "No local spec record with github_milestone: $number under $base/spec/" >&2
    echo "Seed one first (milestone-edit $number ... or milestone-create while online)" >&2
    exit 1
  fi
  read_record "$path" spec

  if [[ -z "$(record_field github_milestone_url)" ]]; then
    milestone_sync_provisional "$repo" "$number" "$path" "$base"
    return
  fi

  local view
  if ! view="$(gh api "repos/$repo/milestones/$number")"; then
    echo "milestone-sync: cannot reach GitHub for milestone #$number" >&2
    exit 1
  fi

  local pending last gh_updated conflict=0 closure_pushed=0
  pending="$(jq -r '.pending_sync // false' <<<"$RECORD_JSON")"
  last="$(jq -r '.last_synced_at // ""' <<<"$RECORD_JSON")"
  gh_updated="$(jq -r '.updated_at // ""' <<<"$view")"
  if [[ "$pending" == true && -n "$last" && -n "$gh_updated" && "$gh_updated" > "$last" ]]; then
    conflict=1
  fi

  if [[ "$pending" == true ]]; then
    # Push pending durable content (title, description): local wins.
    local title body raw
    title="$(record_field title)"
    body="$RECORD_BODY"
    if ! raw="$(gh api -X PATCH "repos/$repo/milestones/$number" -f title="$title" -f description="$body")"; then
      sync_deferred "$path" milestone-sync "$number"
    fi
    # Push closure intent when GitHub is still open.
    local lstate view_state
    lstate="$(record_field state)"
    view_state="$(jq -r '.state // "open"' <<<"$view")"
    if [[ "$lstate" == "closed" && "$view_state" != "closed" ]]; then
      if ! raw="$(gh api -X PATCH "repos/$repo/milestones/$number" -f state=closed)"; then
        sync_deferred "$path" milestone-sync "$number"
      fi
      closure_pushed=1
    fi
  fi

  local gtitle gstate gdue gurl
  gtitle="$(jq -r '.title // ""' <<<"$view")"
  gstate="$(jq -r '.state // "open"' <<<"$view")"
  if [[ "$closure_pushed" -eq 1 ]]; then
    gstate="closed"
  fi
  gdue="$(jq -r '.due_on // ""' <<<"$view")"
  gurl="$(jq -r '.html_url // ""' <<<"$view")"

  if [[ "$conflict" -eq 1 ]]; then
    echo "conflict on milestone #$number: local record and GitHub both changed since the last sync" >&2
    if [[ "$gtitle" != "$(record_field title)" ]]; then
      echo "- title: resolved toward the local record (pushed)" >&2
    fi
    if [[ "$(jq -r '.description // ""' <<<"$view")" != "$RECORD_BODY" ]]; then
      echo "- description: resolved toward the local record (pushed)" >&2
    fi
    if [[ "$gstate" != "$(record_field state)" ]]; then
      echo "- state: resolved toward GitHub (pulled)" >&2
    fi
  fi

  RECORD_JSON="$(jq -c \
    --arg s "$gstate" --arg d "$gdue" --arg u "$gurl" --arg t "$(now_iso)" \
    '.state=$s | .due_on=(if $d == "" then null else $d end)
      | .github_milestone_url=(if $u == "" then .github_milestone_url else $u end)
      | .pending_sync=false | .last_synced_at=$t' <<<"$RECORD_JSON")"
  if [[ "$pending" != true && -z "$RECORD_BODY" ]]; then
    RECORD_BODY="$(jq -r '.description // ""' <<<"$view")"
  fi
  write_record_atomic "$path" "$(render_record spec)" "$base" spec
  milestone_sync_summary
}

# --- offline read fallbacks (serve the local record, never write it) ---------------

issue_local_view_json() {
  jq -n \
    --argjson number "$(jq -r '.github_number // 0' <<<"$RECORD_JSON")" \
    --arg title "$(jq -r '.title // ""' <<<"$RECORD_JSON")" \
    --arg body "$RECORD_BODY" \
    --arg state "$(jq -r '.state // ""' <<<"$RECORD_JSON")" \
    --argjson labels "$(jq -c '.labels // []' <<<"$RECORD_JSON")" \
    --argjson assignees "$(jq -c '.assignees // []' <<<"$RECORD_JSON")" \
    --arg milestone "$(jq -r '.milestone // ""' <<<"$RECORD_JSON")" \
    --arg url "$(jq -r '.github_url // ""' <<<"$RECORD_JSON")" \
    '{number: $number, title: $title, body: $body, state: $state,
      labels: $labels, assignees: $assignees,
      milestone: (if $milestone == "" then null else $milestone end),
      url: $url}'
}

issue_view_local_fallback() {
  local number="$1" base path
  base="$(resolve_docs_base)" || exit 1
  if ! path="$(find_issue_record "$base" "$number")"; then
    return 1
  fi
  read_record "$path" issue
  issue_local_view_json
  echo "issue-view: GitHub unreachable; served the local record (read-only, record not updated)" >&2
}

issue_list_local_fallback() {
  local base f found=0
  base="$(resolve_docs_base)" || exit 1
  local items=()
  for f in "$base"/issue/ISSUE-*.md; do
    [[ -f "$f" ]] || continue
    if read_record "$f" issue; then
      items+=("$(issue_local_view_json)")
      found=1
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    return 1
  fi
  printf '%s\n' "${items[@]}" | jq -s .
  echo "issue-list: GitHub unreachable; served local records (read-only, records not updated)" >&2
}

milestone_list_local_fallback() {
  local base f found=0
  base="$(resolve_docs_base)" || exit 1
  local items=()
  for f in "$base"/spec/SPEC-*.md; do
    [[ -f "$f" ]] || continue
    if read_record "$f" spec; then
      items+=("$(jq -n \
        --argjson number "$(jq -r '.github_milestone // 0' <<<"$RECORD_JSON")" \
        --arg title "$(jq -r '.title // ""' <<<"$RECORD_JSON")" \
        --arg state "$(jq -r '.state // ""' <<<"$RECORD_JSON")" \
        --arg due "$(jq -r '.due_on // ""' <<<"$RECORD_JSON")" \
        --arg url "$(jq -r '.github_milestone_url // ""' <<<"$RECORD_JSON")" \
        '{number: $number, title: $title, state: $state,
          due_on: (if $due == "" then null else $due end),
          url: (if $url == "" then null else $url end)}')")
      found=1
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    return 1
  fi
  printf '%s\n' "${items[@]}" | jq -s .
  echo "milestone-list: GitHub unreachable; served local records (read-only, records not updated)" >&2
}

# --- project metadata subcommands (thin gh project wrappers, issue #46) ---------
#
# project-list / project-view / project-field-list wrap gh project list /
# view / field-list plus curated jq shaping. They deliberately do NOT use
# the GraphQL items engine — field-list already returns single-select
# options, so no GraphQL is needed for metadata (guardrail). The owner is
# REQUIRED and never positional: it resolves --owner flag ->
# ANT_TEAM_GITHUB_OWNER env -> legacy OWNER, and an empty resolution fails
# BEFORE gh runs (the underlying list command without an owner silently
# targets the authenticated user's projects — a cross-owner footgun).
# PROJECT_NUMBER is a required positional validated numeric before gh, and
# --format accepts only json.

validate_project_query_format() {
  local format="$1" cmd_name="$2"
  if [[ -n "$format" && "$format" != "json" ]]; then
    echo "Invalid --format '$format' for $cmd_name: only json is accepted" >&2
    exit 1
  fi
}

validate_project_query_number() {
  local number="$1" cmd_name="$2"
  if [[ -z "$number" ]]; then
    echo "Missing required value: PROJECT_NUMBER for $cmd_name" >&2
    exit 1
  fi
  if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "Invalid project number '$number' for $cmd_name: must be a positive integer (the owner is a --owner flag, never a positional)" >&2
    exit 1
  fi
}

require_project_query_owner() {
  local owner="$1" cmd_name="$2"
  if [[ -z "$owner" ]]; then
    echo "Missing required value: owner for $cmd_name" >&2
    echo "Pass --owner OWNER explicitly or set ANT_TEAM_GITHUB_OWNER in $CONFIG_ENV_FILE" >&2
    exit 1
  fi
}

# Minimal flag parsing for the project metadata query family (guardrail:
# small local loop, no generic arg framework, no new deps). Recognizes
# --owner VALUE and --format VALUE only; any other flag is a usage error,
# and at most one positional (PROJECT_NUMBER) is captured — a positional
# owner can never reach gh.
parse_project_query_args() {
  PQ_OWNER=""
  PQ_FORMAT=""
  PQ_POSITIONAL=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --owner)
        [[ $# -ge 2 ]] || { usage; exit 1; }
        PQ_OWNER="$2"; shift 2 ;;
      --format)
        [[ $# -ge 2 ]] || { usage; exit 1; }
        PQ_FORMAT="$2"; shift 2 ;;
      -*)
        usage; exit 1 ;;
      *)
        [[ -z "$PQ_POSITIONAL" ]] || { usage; exit 1; }
        PQ_POSITIONAL="$1"; shift ;;
    esac
  done
}

project_list() {
  local owner="$1"
  gh project list --owner "$owner" --format json \
    | jq '[.projects[]
      | {
          number,
          title,
          url,
          public,
          closed,
          items_count: .items.totalCount,
          fields_count: .fields.totalCount
        }] | sort_by(.number)'
}

project_view() {
  local owner="$1"
  local project_number="$2"
  gh project view "$project_number" --owner "$owner" --format json \
    | jq '{
        number,
        title,
        url,
        public,
        closed,
        items_count: .items.totalCount,
        fields_count: .fields.totalCount,
        owner: .owner.login
      }'
}

project_field_list() {
  local owner="$1"
  local project_number="$2"
  gh project field-list "$project_number" --owner "$owner" --format json \
    | jq '{
        total_count: .totalCount,
        fields: [.fields[]
          | {id, name, type}
            + (if has("options")
               then {options: [.options[] | {name, id}]}
               else {} end)]
      }'
}

case "$cmd" in
  gh-item-edit)
    [[ $# -eq 3 ]] || { usage; exit 1; }
    gh_item_edit "$1" "$2" "$3"
    ;;
  item-id)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    validate_board_status_args "$1" "" item-id
    print_item_id "$owner" "$project_number" "$1"
    ;;
  list-statuses)
    [[ $# -eq 0 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    list_statuses "$owner" "$project_number"
    ;;
  list-items)
    [[ $# -le 1 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    list_items "$owner" "$project_number" "${1:-}"
    ;;
  list-unassigned)
    [[ $# -eq 0 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    list_unassigned "$owner" "$project_number"
    ;;
  project-list)
    parse_project_query_args "$@"
    [[ -z "$PQ_POSITIONAL" ]] || { usage; exit 1; }
    validate_project_query_format "$PQ_FORMAT" project-list
    owner="$(resolve_owner "$PQ_OWNER")"
    require_project_query_owner "$owner" project-list
    project_list "$owner"
    ;;
  project-view)
    parse_project_query_args "$@"
    validate_project_query_format "$PQ_FORMAT" project-view
    validate_project_query_number "$PQ_POSITIONAL" project-view
    owner="$(resolve_owner "$PQ_OWNER")"
    require_project_query_owner "$owner" project-view
    project_view "$owner" "$PQ_POSITIONAL"
    ;;
  project-field-list)
    parse_project_query_args "$@"
    validate_project_query_format "$PQ_FORMAT" project-field-list
    validate_project_query_number "$PQ_POSITIONAL" project-field-list
    owner="$(resolve_owner "$PQ_OWNER")"
    require_project_query_owner "$owner" project-field-list
    project_field_list "$owner" "$PQ_POSITIONAL"
    ;;
  item-state)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    validate_board_status_args "$1" "" item-state
    item_state "$owner" "$project_number" "$1"
    ;;
  add-issue)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    add_issue "$owner" "$project_number" "$1"
    ;;
  set-status)
    [[ $# -eq 2 || $# -eq 3 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    owner_type="$(resolve_owner_type "${3:-}")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    validate_board_status_args "$1" "${3:-}" set-status
    set_status "$owner" "$project_number" "$1" "$2" "$owner_type"
    ;;
  set-status-id)
    [[ $# -eq 2 || $# -eq 3 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    owner_type="$(resolve_owner_type "${3:-}")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    validate_board_status_args "$1" "${3:-}" set-status-id
    set_status_id "$owner" "$project_number" "$1" "$2" "$owner_type"
    ;;
  next-status)
    [[ $# -eq 3 || $# -eq 4 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    owner_type="$(resolve_owner_type "${4:-}")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    validate_board_status_args "$1" "${4:-}" next-status
    next_status "$owner" "$project_number" "$1" "$2" "$3" "$owner_type"
    ;;
  issue-create)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    title="$1"; shift
    issue_local_first_create "$repo" "$title" "$@"
    ;;
  issue-view)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    issue_view "$repo" "$1" "${@:2}"
    ;;
  issue-list)
    repo="$(resolve_repo)"
    require_repo "$repo"
    issue_list "$repo" "$@"
    ;;
  issue-edit)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    issue_local_first_edit "$repo" "$1" "${@:2}"
    ;;
  issue-comment)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    issue_comment "$repo" "$1" "${@:2}"
    ;;
  issue-close)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    issue_local_first_close "$repo" "$1" "${@:2}"
    ;;
  pr-create)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_create "$repo" "$1" "${@:2}"
    ;;
  pr-view)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_view "$repo" "$1" "${@:2}"
    ;;
  pr-list)
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_list "$repo" "$@"
    ;;
  pr-comment)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_comment "$repo" "$1" "${@:2}"
    ;;
  pr-close)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_close "$repo" "$1" "${@:2}"
    ;;
  pr-merge)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_merge "$repo" "$1" "${@:2}"
    ;;
  pr-checks)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_checks "$repo" "$1" "${@:2}"
    ;;
  pr-review-reply)
    [[ $# -eq 2 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    pr_review_reply "$1" "$2"
    ;;
  run-list)
    repo="$(resolve_repo)"
    require_repo "$repo"
    run_list "$repo" "$@"
    ;;
  run-view)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    run_view "$repo" "$1" "${@:2}"
    ;;
  workflow-list)
    repo="$(resolve_repo)"
    require_repo "$repo"
    workflow_list "$repo" "$@"
    ;;
  workflow-run)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    workflow_run "$repo" "$1" "${@:2}"
    ;;
  milestone-create)
    [[ $# -ge 1 && $# -le 2 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    milestone_local_first_create "$repo" "$1" "${2:-}"
    ;;
  milestone-list)
    [[ $# -le 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    milestone_list "$repo" "${1:-}"
    ;;
  milestone-edit)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    milestone_local_first_edit "$repo" "$1" "${@:2}"
    ;;
  milestone-close)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    milestone_local_first_close "$repo" "$1"
    ;;
  issue-sync)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    issue_sync "$repo" "$1"
    ;;
  milestone-sync)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    milestone_sync "$repo" "$1"
    ;;
  release-create)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    release_create "$repo" "$1" "${@:2}"
    ;;
  release-list)
    repo="$(resolve_repo)"
    require_repo "$repo"
    release_list "$repo" "$@"
    ;;
  release-view)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    release_view "$repo" "$1" "${@:2}"
    ;;
  release-edit)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    release_edit "$repo" "$1" "${@:2}"
    ;;
  release-delete)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    release_delete "$repo" "$1" "${@:2}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
