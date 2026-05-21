#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-quick-task.sh SPEC_ID [--task-id TASK_ID] "TASK_TITLE" "TASK_DESCRIPTION" [OWNER]

Adds a lightweight fast-path task under an existing fast-path spec.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 3 || $# -gt 5 ]]; then
  usage >&2
  exit 1
fi

spec_id="$1"
shift

task_id=""
if [[ "${1:-}" == "--task-id" ]]; then
  task_id="${2:-}"
  shift 2
fi

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 1
fi

task_title="$1"
task_description="$2"
owner="${3:-unassigned}"
task_id="${task_id:-$(pm_next_id TASK)}"
spec_file="$(pm_spec_file "$spec_id")"
task_file="$(pm_task_path "$task_id" "$task_title")"
communication_log="$(pm_task_conversation_path "$task_id" "$task_title")"
board_file="$(pm_board_file)"
today="$(pm_today)"

[[ -f "$spec_file" ]] || { echo "Fast-path spec not found: $spec_file" >&2; exit 1; }
if [[ -e "$task_file" ]]; then
  echo "Task already exists: $task_file" >&2
  exit 1
fi

mkdir -p "$(dirname "$task_file")" "$(dirname "$communication_log")"

cat > "$task_file" <<EOF
# $task_id: $task_title

Metadata:

| Field | Value |
|---|---|
| Task ID | $task_id |
| Task Title | $task_title |
| Spec ID | $spec_id |
| Source Spec | $spec_file |
| Conversation Log | $communication_log |
| Status | Ready |
| Phase | Fast Path |
| Owner | $owner |
| Dependencies | none |
| Parallel With |  |
| Last Updated | $today |

## Context

$task_description

## Fast Path Rules

- Keep this task lightweight and focused.
- Promote to normal flow if scope or risk expands.

## Definition Of Done

- Small scoped work completed.
- Verification evidence recorded.
- Validation result recorded.

## Verification Commands

\`\`\`bash
<command>
\`\`\`

## Notes

- Add concrete implementation or experiment notes here.
EOF

pm_init_task_conversation "$spec_id" "$task_id" "$task_title" "Ready"

pm_ensure_board
pm_update_board_row "$spec_id" "$task_id" "$task_title" "Ready" "$owner" "" "" "0/8" "none" "$today"

pm_touch_spec "$spec_file"
pm_touch_task_file "$task_file"
pm_touch_communication_log "$communication_log"
pm_append_log "$task_id" "Agent Handoffs" "### $today - $task_id - quick task created

- Owner: $owner
- Scope: $task_title
- Status: Ready"

echo "Created quick task $task_id under $spec_id"
echo "Task ID: $task_id"
