#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_JSON_FILE="$REPO_ROOT/.github-project.json"
CONFIG_ENV_FILE="$REPO_ROOT/.github-project.env"

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
  gh_project_helper.sh item-id [owner] [project_number] <issue_number>
  gh_project_helper.sh list-statuses [owner] [project_number]
  gh_project_helper.sh list-items [owner] [project_number] [status_name]
  gh_project_helper.sh list-todo [owner] [project_number]
  gh_project_helper.sh add-issue [owner] [project_number] <issue_url>
  gh_project_helper.sh set-status [owner] [project_number] <issue_number> <status_name> [owner_type]
  gh_project_helper.sh set-status-id [owner] [project_number] <issue_number> <single_select_option_id> [owner_type]
  gh_project_helper.sh next-status [owner] [project_number] <issue_number> <current_status> <next_status> [owner_type]

Notes:
  - prefer .github-project.json at the repo root for structured config
  - .github-project.env is still supported as a fallback
  - owner_type defaults to "org". Use "user" for personal projects.
  - Requires gh and jq.
EOF
}

load_config() {
  if [[ -f "$CONFIG_ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_ENV_FILE"
  fi
}

json_get() {
  local query="$1"
  if [[ -f "$CONFIG_JSON_FILE" ]]; then
    jq -r "$query // empty" "$CONFIG_JSON_FILE"
  fi
}

require_value() {
  local name="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    echo "Missing required value: $name" >&2
    echo "Pass it explicitly or set it in $CONFIG_JSON_FILE or $CONFIG_ENV_FILE" >&2
    exit 1
  fi
}

resolve_owner() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
  else
    local value
    value="$(json_get '.owner')"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
    else
      printf '%s\n' "${OWNER:-}"
    fi
  fi
}

resolve_project_number() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
  else
    local value
    value="$(json_get '.project.number')"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
    else
      printf '%s\n' "${PROJECT_NUMBER:-}"
    fi
  fi
}

resolve_owner_type() {
  local explicit="${1:-}"
  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
  else
    local value
    value="$(json_get '.owner_type')"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
    else
      printf '%s\n' "${OWNER_TYPE:-org}"
    fi
  fi
}

resolve_project_id_from_env() {
  local value
  value="$(json_get '.project.id')"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "${PROJECT_ID:-}"
  fi
}

resolve_status_field_id_from_env() {
  local value
  value="$(json_get '.fields.status')"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "${STATUS_FIELD_ID:-}"
  fi
}

resolve_status_option_id_from_env() {
  local status_name="$1"
  local normalized
  normalized="$(printf '%s' "$status_name" | tr '[:lower:]' '[:upper:]' | tr ' -' '__')"
  local var_name="STATUS_OPTION_${normalized}_ID"
  local json_key
  json_key="$(printf '%s' "$status_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' )"
  local value
  value="$(json_get ".status_options[\"$json_key\"]")"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "${!var_name:-}"
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
    | jq -r '.fields[]
      | select(.name == "Status")
      | .options[]
      | .name'
}

list_items() {
  local owner="$1"
  local project_number="$2"
  local status_name="${3:-}"

  if [[ -n "$status_name" ]]; then
    gh project item-list "$project_number" --owner "$owner" --format json \
      | jq --arg status "$status_name" '.items[]
        | select(
            ([.fieldValues[]?
              | select(.field.name == "Status")
              | .name] | first // "") == $status
          )
        | {
            issue_number: (.content.number // null),
            title: (.content.title // ""),
            assignees: ((.content.assignees // []) | map(.login)),
            url: (.content.url // ""),
            status: (
              [.fieldValues[]?
                | select(.field.name == "Status")
                | .name] | first // ""
            )
          }'
  else
    gh project item-list "$project_number" --owner "$owner" --format json \
      | jq '.items[]
        | {
            issue_number: (.content.number // null),
            title: (.content.title // ""),
            assignees: ((.content.assignees // []) | map(.login)),
            url: (.content.url // ""),
            status: (
              [.fieldValues[]?
                | select(.field.name == "Status")
                | .name] | first // ""
            )
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

resolve_status_field_id() {
  local owner="$1"
  local project_number="$2"

  if [[ -n "${STATUS_FIELD_ID:-}" ]]; then
    printf '%s\n' "$STATUS_FIELD_ID"
  else
    gh project field-list "$project_number" --owner "$owner" --format json \
      | jq -r '.fields[]
        | select(.name == "Status")
        | .id'
  fi
}

resolve_status_option_id() {
  local owner="$1"
  local project_number="$2"
  local status_name="$3"

  local env_option_id
  env_option_id="$(resolve_status_option_id_from_env "$status_name")"

  if [[ -n "$env_option_id" ]]; then
    printf '%s\n' "$env_option_id"
  else
    gh project field-list "$project_number" --owner "$owner" --format json \
      | jq -r --arg status "$status_name" '.fields[]
        | select(.name == "Status")
        | .options[]
        | select(.name == $status)
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
  project_id="$(resolve_project_id "$owner" "$project_number" "$owner_type")"
  item_id="$(resolve_item_id "$owner" "$project_number" "$issue_number")"
  field_id="$(resolve_status_field_id "$owner" "$project_number")"

  if [[ -n "${PROJECT_ID:-}" ]]; then
    project_id="$PROJECT_ID"
  fi

  if [[ -z "$project_id" || "$project_id" == "null" ]]; then
    echo "Could not resolve project ID" >&2
    exit 1
  fi
  if [[ -z "$item_id" || "$item_id" == "null" ]]; then
    echo "Could not resolve project item ID for issue #$issue_number" >&2
    exit 1
  fi
  if [[ -z "$field_id" || "$field_id" == "null" ]]; then
    echo "Could not resolve Status field ID" >&2
    exit 1
  fi
  if [[ -z "$option_id" || "$option_id" == "null" ]]; then
    echo "Could not resolve status option ID" >&2
    exit 1
  fi

  gh project item-edit \
    --id "$item_id" \
    --project-id "$project_id" \
    --field-id "$field_id" \
    --single-select-option-id "$option_id" >/dev/null

  gh project item-list "$project_number" --owner "$owner" --format json \
    | jq --argjson n "$issue_number" '.items[]
      | select(.content.number == $n)
      | {
          issue_number: (.content.number // null),
          title: (.content.title // ""),
          status: (
            [.fieldValues[]?
              | select(.field.name == "Status")
              | .name] | first // ""
          ),
          url: (.content.url // "")
        }'
}

set_status() {
  local owner="$1"
  local project_number="$2"
  local issue_number="$3"
  local status_name="$4"
  local owner_type="${5:-org}"

  local option_id
  option_id="$(resolve_status_option_id "$owner" "$project_number" "$status_name")"
  if [[ -z "$option_id" || "$option_id" == "null" ]]; then
    echo "Could not resolve status option ID for '$status_name'" >&2
    exit 1
  fi

  set_status_id "$owner" "$project_number" "$issue_number" "$option_id" "$owner_type"
}

case "$cmd" in
  gh-item-edit)
    [[ $# -eq 3 ]] || { usage; exit 1; }
    gh_item_edit "$1" "$2" "$3"
    ;;
  item-id)
    if [[ $# -eq 1 ]]; then
      owner="$(resolve_owner "")"
      project_number="$(resolve_project_number "")"
      issue_number="$1"
    elif [[ $# -eq 3 ]]; then
      owner="$(resolve_owner "$1")"
      project_number="$(resolve_project_number "$2")"
      issue_number="$3"
    else
      usage
      exit 1
    fi
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    print_item_id "$owner" "$project_number" "$issue_number"
    ;;
  list-statuses)
    [[ $# -le 2 ]] || { usage; exit 1; }
    owner="$(resolve_owner "${1:-}")"
    project_number="$(resolve_project_number "${2:-}")"
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    list_statuses "$owner" "$project_number"
    ;;
  list-items)
    [[ $# -le 3 ]] || { usage; exit 1; }
    if [[ $# -eq 1 ]]; then
      owner="$(resolve_owner "")"
      project_number="$(resolve_project_number "")"
      status_name="$1"
    else
      owner="$(resolve_owner "${1:-}")"
      project_number="$(resolve_project_number "${2:-}")"
      status_name="${3:-}"
    fi
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    list_items "$owner" "$project_number" "$status_name"
    ;;
  list-todo)
    [[ $# -le 2 ]] || { usage; exit 1; }
    owner="$(resolve_owner "${1:-}")"
    project_number="$(resolve_project_number "${2:-}")"
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    list_items "$owner" "$project_number" "Todo"
    ;;
  add-issue)
    [[ $# -ge 1 && $# -le 3 ]] || { usage; exit 1; }
    if [[ $# -eq 1 ]]; then
      owner="$(resolve_owner "")"
      project_number="$(resolve_project_number "")"
      issue_url="$1"
    else
      owner="$(resolve_owner "$1")"
      project_number="$(resolve_project_number "$2")"
      issue_url="$3"
    fi
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    add_issue "$owner" "$project_number" "$issue_url"
    ;;
  set-status)
    if [[ $# -eq 2 || $# -eq 3 ]]; then
      owner="$(resolve_owner "")"
      project_number="$(resolve_project_number "")"
      issue_number="$1"
      status_name="$2"
      owner_type="$(resolve_owner_type "${3:-}")"
    elif [[ $# -eq 4 || $# -eq 5 ]]; then
      owner="$(resolve_owner "$1")"
      project_number="$(resolve_project_number "$2")"
      issue_number="$3"
      status_name="$4"
      owner_type="$(resolve_owner_type "${5:-}")"
    else
      usage
      exit 1
    fi
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    set_status "$owner" "$project_number" "$issue_number" "$status_name" "$owner_type"
    ;;
  set-status-id)
    if [[ $# -eq 2 || $# -eq 3 ]]; then
      owner="$(resolve_owner "")"
      project_number="$(resolve_project_number "")"
      issue_number="$1"
      option_id="$2"
      owner_type="$(resolve_owner_type "${3:-}")"
    elif [[ $# -eq 4 || $# -eq 5 ]]; then
      owner="$(resolve_owner "$1")"
      project_number="$(resolve_project_number "$2")"
      issue_number="$3"
      option_id="$4"
      owner_type="$(resolve_owner_type "${5:-}")"
    else
      usage
      exit 1
    fi
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    set_status_id "$owner" "$project_number" "$issue_number" "$option_id" "$owner_type"
    ;;
  next-status)
    if [[ $# -eq 3 || $# -eq 4 ]]; then
      owner="$(resolve_owner "")"
      project_number="$(resolve_project_number "")"
      issue_number="$1"
      current_status="$2"
      next_status="$3"
      owner_type="$(resolve_owner_type "${4:-}")"
    elif [[ $# -eq 5 || $# -eq 6 ]]; then
      owner="$(resolve_owner "$1")"
      project_number="$(resolve_project_number "$2")"
      issue_number="$3"
      current_status="$4"
      next_status="$5"
      owner_type="$(resolve_owner_type "${6:-}")"
    else
      usage
      exit 1
    fi
    require_value "OWNER" "$owner"
    require_value "PROJECT_NUMBER" "$project_number"
    set_status "$owner" "$project_number" "$issue_number" "$next_status" "$owner_type"
    ;;
  *)
    usage
    exit 1
    ;;
esac
