#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_ENV_FILE="$REPO_ROOT/.github-project.env"

# Canonical board field. The legacy "Status" field (Todo/In Progress/Done) is
# no longer targeted by this helper.
readonly CANONICAL_FIELD_NAME="Workflow State"

# `gh project item-list --format json` flattens single-select field values to
# top-level item keys named after the field (e.g. "workflow State").
readonly CANONICAL_ITEM_KEY="workflow State"

# Default JSON field sets for issue read commands: collaboration-shaped,
# safe output. Callers take over the output shape by passing --json, --jq,
# --template, --comments, or --web themselves.
readonly ISSUE_VIEW_FIELDS="number,title,body,state,assignees,labels,milestone,projectItems,url"
readonly ISSUE_LIST_FIELDS="number,title,state,assignees,labels,milestone,url"

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
  gh_project_helper.sh list-statuses
  gh_project_helper.sh list-items [state_name]
  gh_project_helper.sh add-issue <issue_url>
  gh_project_helper.sh set-status <issue_number> <state_name> [owner_type]
  gh_project_helper.sh set-status-id <issue_number> <single_select_option_id> [owner_type]
  gh_project_helper.sh next-status <issue_number> <current_state> <next_state> [owner_type]

  gh_project_helper.sh issue-create <title> [gh issue flags...]
  gh_project_helper.sh issue-view <issue_number> [gh issue flags...]
  gh_project_helper.sh issue-list [gh issue flags...]
  gh_project_helper.sh issue-edit <issue_number> [gh issue flags...]
  gh_project_helper.sh issue-comment <issue_number> [gh issue flags...]
  gh_project_helper.sh issue-close <issue_number> [gh issue flags...]

  gh_project_helper.sh milestone-create <title> [description]
  gh_project_helper.sh milestone-list [state]
  gh_project_helper.sh milestone-edit <milestone_number> [gh api -f flags...]
  gh_project_helper.sh milestone-close <milestone_number>

Notes:
  - all board operations target the canonical "Workflow State" project field
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
  - issue-* and milestone-* are thin wrappers around gh issue / gh api
    (REST milestones). The target repository always resolves from
    .github-project.env (ANT_TEAM_GITHUB_REPO, legacy REPO fallback) and
    is never a positional argument; a pass-through --repo flag cannot
    override it
  - extra flags after the required positional argument pass straight
    through to gh issue / gh api; issue-view and issue-list print curated
    JSON by default (pass --json, --jq, --template, --comments, or --web
    to control the output shape yourself)
  - issue-comment exists for final decisions, status, closure, and
    code-review outcomes only; durable handoffs live in the central
    Obsidian project folder
  - the helper writes no local files and never edits .github-project.env
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

list_statuses() {
  local owner="$1"
  local project_number="$2"

  gh project field-list "$project_number" --owner "$owner" --format json \
    | jq -r --arg field "$CANONICAL_FIELD_NAME" '.fields[]
      | select(.name == $field)
      | .options[]
      | .name'
}

list_items() {
  local owner="$1"
  local project_number="$2"
  local state_name="${3:-}"

  if [[ -n "$state_name" ]]; then
    gh project item-list "$project_number" --owner "$owner" --format json \
      | jq --arg key "$CANONICAL_ITEM_KEY" --arg state "$state_name" '.items[]
        | select((.[$key] // "") == $state)
        | {
            issue_number: (.content.number // null),
            title: (.content.title // ""),
            assignees: ((.content.assignees // []) | map(.login)),
            url: (.content.url // ""),
            state: (.[$key] // "")
          }'
  else
    gh project item-list "$project_number" --owner "$owner" --format json \
      | jq --arg key "$CANONICAL_ITEM_KEY" '.items[]
        | {
            issue_number: (.content.number // null),
            title: (.content.title // ""),
            assignees: ((.content.assignees // []) | map(.login)),
            url: (.content.url // ""),
            state: (.[$key] // "")
          }'
  fi
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

  gh api graphql -f query="$query" -F owner="$owner" -F number="$project_number" \
    | jq -r '.data.organization.projectV2.id // .data.user.projectV2.id'
}

resolve_item_id() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"

  gh project item-list "$project_number" --owner "$owner" --format json \
    | jq -r --argjson n "$issue_number" '.items[]
      | select(.content.number == $n)
      | .id'
}

print_item_id() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"

  gh project item-list "$project_number" --owner "$owner" --format json \
    | jq --argjson n "$issue_number" '.items[]
      | select(.content.number == $n)
      | {
          item_id: .id,
          issue_number: .content.number,
          title: (.content.title // ""),
          url: (.content.url // "")
        }'
}

resolve_state_field_id() {
  local owner="$1"
  local project_number="$2"

  local env_field_id
  env_field_id="$(resolve_state_field_id_from_env)"

  if [[ -n "$env_field_id" ]]; then
    printf '%s\n' "$env_field_id"
  else
    gh project field-list "$project_number" --owner "$owner" --format json \
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
    gh project field-list "$project_number" --owner "$owner" --format json \
      | jq -r --arg field "$CANONICAL_FIELD_NAME" --arg state "$state_name" '.fields[]
        | select(.name == $field)
        | .options[]
        | select(.name == $state)
        | .id'
  fi
}

set_status_id() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"
  local option_id="$4"
  local owner_type="${5:-org}"

  local project_id item_id field_id
  project_id="$(resolve_project_id_from_env)"
  if [[ -z "$project_id" ]]; then
    project_id="$(resolve_project_id "$owner" "$project_number" "$owner_type")"
  fi
  item_id="$(resolve_item_id "$owner" "$project_number" "$issue_number")"
  field_id="$(resolve_state_field_id "$owner" "$project_number")"

  if [[ -z "$project_id" || "$project_id" == "null" ]]; then
    echo "Could not resolve project ID" >&2
    exit 1
  fi
  if [[ -z "$item_id" || "$item_id" == "null" ]]; then
    echo "Could not resolve project item ID for issue #$issue_number" >&2
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

  gh project item-edit \
    --id "$item_id" \
    --project-id "$project_id" \
    --field-id "$field_id" \
    --single-select-option-id "$option_id" >/dev/null

  gh project item-list "$project_number" --owner "$owner" --format json \
    | jq --arg key "$CANONICAL_ITEM_KEY" --argjson n "$issue_number" '.items[]
      | select(.content.number == $n)
      | {
          issue_number: (.content.number // null),
          title: (.content.title // ""),
          state: (.[$key] // ""),
          url: (.content.url // "")
        }'
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
    echo "Could not resolve Workflow State option ID for '$state_name'." >&2
    echo "The remote board may still use a legacy option name for this state" >&2
    echo "(e.g. 'Inbox' instead of 'Open', 'Shaping' instead of 'Backlog')." >&2
    echo "This helper never renames remote board options. Either pass the exact" >&2
    echo "remote option name, or rename the option in GitHub with explicit" >&2
    echo "founder approval and then record the verified IDs in .github-project.env." >&2
    exit 1
  fi

  set_status_id "$owner" "$project_number" "$issue_number" "$option_id" "$owner_type"
}

# --- issue subcommands (thin gh issue wrappers, env-resolved repo) ------------

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
    gh issue view "$number" --json "$ISSUE_VIEW_FIELDS" "$@" --repo "$repo"
  fi
}

issue_list() {
  local repo="$1"
  shift
  if has_format_flag "$@"; then
    gh issue list "$@" --repo "$repo"
  else
    gh issue list --json "$ISSUE_LIST_FIELDS" "$@" --repo "$repo"
  fi
}

issue_edit() {
  local repo="$1" number="$2"
  shift 2
  gh issue edit "$number" "$@" --repo "$repo"
}

issue_comment() {
  local repo="$1" number="$2"
  shift 2
  gh issue comment "$number" "$@" --repo "$repo"
}

issue_close() {
  local repo="$1" number="$2"
  shift 2
  gh issue close "$number" "$@" --repo "$repo"
}

# --- milestone subcommands (thin gh api REST wrappers) -------------------------

# Curated, safe JSON shape for REST milestone payloads; the raw payload
# (node_id, creator, ...) is never echoed.
milestone_summary_jq() {
  jq '{ number, title, state, open_issues, closed_issues, due_on, url: .html_url }'
}

milestone_create() {
  local repo="$1" title="$2" description="${3:-}"
  if [[ -n "$description" ]]; then
    gh api "repos/$repo/milestones" -f title="$title" -f description="$description" | milestone_summary_jq
  else
    gh api "repos/$repo/milestones" -f title="$title" | milestone_summary_jq
  fi
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
  gh api "repos/$repo/milestones?state=$state" \
    | jq '[.[] | { number, title, state, open_issues, closed_issues, due_on, url: .html_url }]'
}

milestone_edit() {
  local repo="$1" number="$2"
  shift 2
  gh api -X PATCH "repos/$repo/milestones/$number" "$@" | milestone_summary_jq
}

milestone_close() {
  local repo="$1" number="$2"
  gh api -X PATCH "repos/$repo/milestones/$number" -f state=closed | milestone_summary_jq
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
    set_status "$owner" "$project_number" "$1" "$2" "$owner_type"
    ;;
  set-status-id)
    [[ $# -eq 2 || $# -eq 3 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    owner_type="$(resolve_owner_type "${3:-}")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    set_status_id "$owner" "$project_number" "$1" "$2" "$owner_type"
    ;;
  next-status)
    [[ $# -eq 3 || $# -eq 4 ]] || { usage; exit 1; }
    owner="$(resolve_owner "")"; project_number="$(resolve_project_number "")"
    owner_type="$(resolve_owner_type "${4:-}")"
    require_value "OWNER" "$owner"; require_value "PROJECT_NUMBER" "$project_number"
    set_status "$owner" "$project_number" "$1" "$3" "$owner_type"
    ;;
  issue-create)
    [[ $# -ge 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    title="$1"; shift
    issue_create "$repo" "$title" "$@"
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
    issue_edit "$repo" "$1" "${@:2}"
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
    issue_close "$repo" "$1" "${@:2}"
    ;;
  milestone-create)
    [[ $# -ge 1 && $# -le 2 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    milestone_create "$repo" "$1" "${2:-}"
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
    milestone_edit "$repo" "$1" "${@:2}"
    ;;
  milestone-close)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    repo="$(resolve_repo)"
    require_repo "$repo"
    milestone_close "$repo" "$1"
    ;;
  *)
    usage
    exit 1
    ;;
esac
