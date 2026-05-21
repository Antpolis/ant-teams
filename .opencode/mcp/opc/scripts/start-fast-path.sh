#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/start-fast-path.sh [--spec-id FP_ID] [--task-id TASK_ID] "TASK_TITLE" "TASK_DESCRIPTION" [OWNER]

Creates a lightweight fast-path spec, task file, board row, and communication log
for a small fix or experiment that does not need the full planning ceremony.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

spec_id=""
task_id=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec-id)
      spec_id="${2:-}"
      shift 2
      ;;
    --task-id)
      task_id="${2:-}"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 1
fi

task_title="$1"
task_description="$2"
owner="${3:-unassigned}"
spec_id="${spec_id:-$(pm_next_id FP)}"
task_id="${task_id:-$(pm_next_id TASK)}"
doc_root="${DOC_ROOT:-$(pm_doc_root)}"
doc_root="${doc_root%/}"
spec_file="$(pm_spec_path "$spec_id" "$task_title")"
task_file="$(pm_task_path "$task_id" "$task_title")"
communication_log="$(pm_task_conversation_path "$task_id" "$task_title")"
board_file="$doc_root/proj-management/board.md"
today="$(pm_today)"

if [[ -e "$spec_file" || -e "$task_file" ]]; then
  echo "Fast-path spec or task file already exists for $spec_id / $task_id" >&2
  exit 1
fi

mkdir -p \
  "$(dirname "$spec_file")" \
  "$(dirname "$task_file")" \
  "$(dirname "$communication_log")" \
  "$(dirname "$board_file")"

cat > "$spec_file" <<EOF
# Fast Path: $task_title

Metadata:

| Field | Value |
|---|---|
| Spec ID | $spec_id |
| Type | fast-path |
| Title | Fast Path: $task_title |
| Owner | $owner |
| Task Directory | $doc_root/proj-management/tasks |
| Task File Pattern | $doc_root/proj-management/tasks/TASK-xxx-<slug>.md |
| Conversation Pattern | $doc_root/proj-management/communication/TASK-CONV-xxx-<slug>.md |
| Last Updated | $today |
| Status | in-development |

## Goal

$task_description

## Why Fast Path

- Small enough to avoid full spec ceremony.
- Intended for a small fix, tiny refactor, or quick experiment.
- Must be promoted to the normal flow if scope, risk, or dependencies expand.

## Exit Criteria

- Change or experiment is implemented and validated, or
- A blocker is recorded, or
- The work is promoted to the normal planning flow.
EOF

cat > "$task_file" <<EOF
# $task_id: $task_title

Metadata:

| Field | Value |
|---|---|
| Task ID | $task_id |
| Task Title | $task_title |
| Spec ID | $spec_id |
| Source Spec | $spec_file |
| Communication Log | $communication_log |
| Status | in-development |
| Phase | Fast Path |
| Owner | $owner |
| Dependencies | none |
| Parallel With |  |
| Last Updated | $today |

## Context

$task_description

## Fast Path Rules

- Keep the scope small and focused.
- Do not add broad new product scope here.
- Promote to the normal flow if multiple dependencies, risky changes, or major unknowns appear.

## Definition Of Done

- The small change or experiment is completed.
- Verification evidence is recorded.
- Validation result is recorded as approved, rework, blocked, or promoted.

## Verification Commands

\`\`\`bash
<command>
\`\`\`

## Notes

- Replace this with concrete notes as work progresses.
EOF

pm_init_task_conversation "$spec_id" "$task_id" "$task_title" "In Development"

pm_ensure_board
pm_update_board_row "$spec_id" "$task_id" "$task_title" "In Development" "$owner" "" "" "0/8" "none" "$today"

pm_append_log "$task_id" "Agent Handoffs" "### $today - $task_id - fast path started

- Owner: $owner
- Scope: $task_title
- Reason: lightweight fix or experiment
- Next Step: implement and validate"

echo "Started fast path $spec_id / $task_id"
echo "Spec ID: $spec_id"
echo "Task ID: $task_id"
