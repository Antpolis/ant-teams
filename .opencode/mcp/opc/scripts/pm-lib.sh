#!/usr/bin/env bash
set -euo pipefail

pm_doc_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "${DOC_ROOT:-$(cd "$script_dir/../../../../docs" && pwd)}"
}

pm_today() {
  date +%F
}

pm_slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

pm_task_conv_id() {
  local task_id="$1"
  printf 'TASK-CONV-%s\n' "${task_id#TASK-}"
}

pm_spec_path() {
  local spec_id="$1"
  local title="$2"
  local root
  root="$(pm_doc_root)"
  printf '%s/spec/%s-%s.md\n' "$root" "$spec_id" "$(pm_slugify "$title")"
}

pm_task_path() {
  local task_id="$1"
  local title="$2"
  local root
  root="$(pm_doc_root)"
  printf '%s/proj-management/tasks/%s-%s.md\n' "$root" "$task_id" "$(pm_slugify "$title")"
}

pm_task_conversation_path() {
  local task_id="$1"
  local title="$2"
  local root conv_id
  root="$(pm_doc_root)"
  conv_id="$(pm_task_conv_id "$task_id")"
  printf '%s/proj-management/communication/%s-%s.md\n' "$root" "$conv_id" "$(pm_slugify "$title")"
}

pm_find_by_prefix() {
  local dir="$1"
  local prefix="$2"
  local exact="$dir/${prefix}.md"
  local matches=()

  if [[ -f "$exact" ]]; then
    printf '%s\n' "$exact"
    return 0
  fi

  shopt -s nullglob
  matches=("$dir/${prefix}-"*.md)
  shopt -u nullglob

  if (( ${#matches[@]} > 0 )); then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  printf '%s\n' "$exact"
}

pm_spec_file() {
  local spec_id="$1"
  pm_find_by_prefix "$(pm_doc_root)/spec" "$spec_id"
}

pm_task_file() {
  local task_id="$1"
  pm_find_by_prefix "$(pm_doc_root)/proj-management/tasks" "$task_id"
}

pm_communication_log() {
  local task_id="$1"
  local root prefix existing title
  root="$(pm_doc_root)/proj-management/communication"
  prefix="$(pm_task_conv_id "$task_id")"
  existing="$(pm_find_by_prefix "$root" "$prefix")"
  if [[ -f "$existing" ]]; then
    printf '%s\n' "$existing"
    return 0
  fi

  title="$(pm_task_title "$task_id" || true)"
  if [[ -n "$title" ]]; then
    printf '%s\n' "$(pm_task_conversation_path "$task_id" "$title")"
  else
    printf '%s/%s.md\n' "$root" "$prefix"
  fi
}

pm_board_file() {
  printf '%s/proj-management/board.md\n' "$(pm_doc_root)"
}

pm_metadata_get() {
  local file="$1"
  local field="$2"

  [[ -f "$file" ]] || return 1

  awk -F'|' -v field="$field" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    /^\|/ {
      key = trim($2)
      value = trim($3)
      if (key == field) {
        print value
        exit
      }
    }
  ' "$file"
}

pm_update_metadata_row() {
  local file="$1"
  local field="$2"
  local value="$3"
  local tmp

  tmp="$(mktemp "${TMPDIR:-/tmp}/pm-metadata.XXXXXX")"
  awk -F'|' -v field="$field" -v value="$value" '
    function trim(text) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", text)
      return text
    }
    {
      if ($0 ~ /^\|/) {
        key = trim($2)
        if (key == field) {
          print "| " key " | " value " |"
          next
        }
      }
      print
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

pm_touch_file_date() {
  local file="$1"
  local today
  today="$(pm_today)"
  [[ -f "$file" ]] || return 0
  pm_update_metadata_row "$file" "Last Updated" "$today"
}

pm_touch_spec() {
  pm_touch_file_date "$1"
}

pm_touch_task_file() {
  pm_touch_file_date "$1"
}

pm_touch_communication_log() {
  pm_touch_file_date "$1"
}

pm_spec_title() {
  local spec_file
  spec_file="$(pm_spec_file "$1")"
  pm_metadata_get "$spec_file" "Title"
}

pm_task_title() {
  local task_file
  task_file="$(pm_task_file "$1")"
  pm_metadata_get "$task_file" "Task Title"
}

pm_task_spec_id() {
  local task_file
  task_file="$(pm_task_file "$1")"
  pm_metadata_get "$task_file" "Spec ID"
}

pm_task_exists() {
  local spec_id="$1"
  local task_id="$2"
  local task_file actual_spec

  task_file="$(pm_task_file "$task_id")"
  [[ -f "$task_file" ]] || return 1

  if [[ -n "$spec_id" ]]; then
    actual_spec="$(pm_metadata_get "$task_file" "Spec ID" || true)"
    [[ "$actual_spec" == "$spec_id" ]] || return 1
  fi
}

pm_ensure_board() {
  local board
  board="$(pm_board_file)"
  mkdir -p "$(dirname "$board")"
  if [[ ! -f "$board" ]]; then
    cat > "$board" <<'EOF'
# Project Board

| Spec | Task | Title | Status | Owner | Branch | PR | Loop | Blocker | Updated |
|---|---|---|---|---|---|---|---|---|---|
EOF
  fi
}

pm_board_get_col() {
  local spec_id="$1"
  local task_id="$2"
  local col="$3"
  local board
  board="$(pm_board_file)"
  [[ -f "$board" ]] || return 0
  awk -F'|' -v spec="$spec_id" -v task="$task_id" -v col="$col" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    /^\|/ {
      if (trim($2) == spec && trim($3) == task) {
        print trim($(col + 1))
        exit
      }
    }
  ' "$board"
}

pm_update_board_row() {
  local spec_id="$1"
  local task_id="$2"
  local title="$3"
  local status="$4"
  local owner="$5"
  local branch="$6"
  local pr="$7"
  local loop="$8"
  local blocker="$9"
  local updated="${10}"
  local board tmp found

  board="$(pm_board_file)"
  pm_ensure_board

  tmp="$(mktemp "${TMPDIR:-/tmp}/pm-board.XXXXXX")"
  found=0
  awk -F'|' \
    -v spec="$spec_id" \
    -v task="$task_id" \
    -v title="$title" \
    -v status="$status" \
    -v owner="$owner" \
    -v branch="$branch" \
    -v pr="$pr" \
    -v loop="$loop" \
    -v blocker="$blocker" \
    -v updated="$updated" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    BEGIN {
      found = 0
    }
    {
      if ($0 ~ /^\|/ && trim($2) == spec && trim($3) == task) {
        print "| " spec " | " task " | " title " | " status " | " owner " | " branch " | " pr " | " loop " | " blocker " | " updated " |"
        found = 1
        next
      }
      print
    }
    END {
      if (!found) {
        print "| " spec " | " task " | " title " | " status " | " owner " | " branch " | " pr " | " loop " | " blocker " | " updated " |"
      }
    }
  ' "$board" > "$tmp"
  mv "$tmp" "$board"
}

pm_valid_status() {
  case "$1" in
    draft|Draft|Ready|In\ Development|Architecture\ Review|PR\ Open|QA\ Smoke|Approved|Rework|Blocked|Loop\ Breaker|Deferred|Done)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

pm_require_valid_status() {
  pm_valid_status "$1" || {
    echo "Invalid status: $1" >&2
    exit 1
  }
}

pm_update_task_status() {
  local spec_id="$1"
  local task_id="$2"
  local status="$3"
  local task_file comm_log

  pm_require_valid_status "$status"
  pm_task_exists "$spec_id" "$task_id" || {
    echo "Task not found: $spec_id / $task_id" >&2
    exit 1
  }

  task_file="$(pm_task_file "$task_id")"
  comm_log="$(pm_communication_log "$task_id")"

  pm_update_metadata_row "$task_file" "Status" "$status"
  pm_touch_task_file "$task_file"

  if [[ -f "$comm_log" ]]; then
    pm_update_metadata_row "$comm_log" "Status" "$status"
    pm_touch_communication_log "$comm_log"
  fi
}

pm_init_task_conversation() {
  local spec_id="$1"
  local task_id="$2"
  local task_title="$3"
  local status="${4:-draft}"
  local task_file spec_file conversation_file today

  task_file="$(pm_task_file "$task_id")"
  spec_file="$(pm_spec_file "$spec_id")"
  conversation_file="$(pm_task_conversation_path "$task_id" "$task_title")"
  today="$(pm_today)"

  mkdir -p "$(dirname "$conversation_file")"

  cat > "$conversation_file" <<EOF
# Task Conversation: $task_id - $task_title

Metadata:

| Field | Value |
|---|---|
| Conversation ID | $(pm_task_conv_id "$task_id") |
| Task ID | $task_id |
| Spec ID | $spec_id |
| Source Task | $task_file |
| Source Spec | $spec_file |
| Status | $status |
| Last Updated | $today |

## Agent Handoffs

## Review Loop Tracker

## Blockers

## Defer Tasks

## Final Approvals

## Role Memory Updates

## Task Discussion
EOF
}

pm_append_log() {
  local task_id="$1"
  local section="$2"
  local body="$3"
  local comm_log

  comm_log="$(pm_communication_log "$task_id")"
  [[ -f "$comm_log" ]] || {
    echo "Communication log not found for $task_id: $comm_log" >&2
    exit 1
  }

  if ! grep -q "^## ${section}\$" "$comm_log"; then
    printf '\n## %s\n' "$section" >> "$comm_log"
  fi

  SECTION="$section" BODY="$body" python3 - "$comm_log" <<'PY'
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
section = f"## {os.environ['SECTION']}"
body = os.environ["BODY"].rstrip() + "\n"
text = path.read_text()
marker = section + "\n"
idx = text.find(marker)
if idx == -1:
    text = text.rstrip() + "\n\n" + marker + body
else:
    start = idx + len(marker)
    end = len(text)
    for token in ("\n## ", "\n# "):
      pos = text.find(token, start)
      if pos != -1 and pos < end:
        end = pos
    chunk = text[start:end].rstrip("\n")
    insert = ("\n" if chunk else "") + body
    text = text[:start] + chunk + insert + text[end:]
path.write_text(text)
PY

  pm_touch_communication_log "$comm_log"
}

pm_next_id() {
  local prefix="$1"
  local root max
  root="$(pm_doc_root)"
  max="$(find "$root" \
    -path "*/proj-management/templates/*" -prune -o \
    -type f -name "*.md" -print \
    | xargs rg -o "${prefix}-[0-9]{3}" 2>/dev/null \
    | sed -E "s/^.*(${prefix}-[0-9]{3}).*$/\\1/" \
    | sed -E "s/^${prefix}-0*//" \
    | sort -n \
    | tail -n 1)"
  if [[ -z "$max" ]]; then
    printf '%s-%03d\n' "$prefix" 1
  else
    printf '%s-%03d\n' "$prefix" "$((10#$max + 1))"
  fi
}

pm_update_all() {
  local spec_id="$1"
  local task_id="$2"
  local status="${3:-}"
  local branch="${4:-}"
  local pr="${5:-}"
  local loop="${6:-}"
  local blocker="${7:-}"
  local task_file spec_file comm_log title owner updated

  task_file="$(pm_task_file "$task_id")"
  spec_file="$(pm_spec_file "$spec_id")"
  comm_log="$(pm_communication_log "$task_id")"
  title="$(pm_metadata_get "$task_file" "Task Title" || true)"
  owner="$(pm_metadata_get "$task_file" "Owner" || true)"
  updated="$(pm_today)"

  [[ -n "$status" ]] || status="$(pm_metadata_get "$task_file" "Status" || true)"
  [[ -n "$owner" ]] || owner="unassigned"
  [[ -n "$branch" ]] || branch="$(pm_board_get_col "$spec_id" "$task_id" 6)"
  [[ -n "$pr" ]] || pr="$(pm_board_get_col "$spec_id" "$task_id" 7)"
  [[ -n "$loop" ]] || loop="$(pm_board_get_col "$spec_id" "$task_id" 8)"
  [[ -n "$blocker" ]] || blocker="$(pm_board_get_col "$spec_id" "$task_id" 9)"
  [[ -n "$loop" ]] || loop="0/8"
  [[ -n "$blocker" ]] || blocker="none"

  pm_touch_spec "$spec_file"
  pm_touch_task_file "$task_file"
  [[ -f "$comm_log" ]] && pm_touch_communication_log "$comm_log"
  pm_update_board_row "$spec_id" "$task_id" "$title" "$status" "$owner" "$branch" "$pr" "$loop" "$blocker" "$updated"
}
