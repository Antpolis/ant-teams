#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-task.sh SPEC_ID [--task-id TASK_ID] "TASK_TITLE" "TASK_DESCRIPTION" [OWNER] [PHASE]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Creates or updates:
  $DOC_ROOT/proj-management/tasks/<TASK_ID>-<slug>.md
  $DOC_ROOT/proj-management/communication/TASK-CONV-<TASK_NUM>-<slug>.md
  $DOC_ROOT/proj-management/board.md

Examples:
  scripts/create-task.sh SPEC-001 "Add database migration" "Create migration for vector columns."
  scripts/create-task.sh SPEC-001 --task-id TASK-001 "Add database migration" "Create migration for vector columns."
  DOC_ROOT=.docs scripts/create-task.sh SPEC-001 "Add database migration" "Create migration for vector columns." platform-team "Phase 1"
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 3 || $# -gt 6 ]]; then
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

if [[ $# -lt 2 || $# -gt 4 ]]; then
  usage >&2
  exit 1
fi

task_title="$1"
task_description="$2"
owner="${3:-unassigned}"
phase="${4:-Phase 1}"
task_id="${task_id:-$(pm_next_id TASK)}"

doc_root="${DOC_ROOT:-$(pm_doc_root)}"
doc_root="${doc_root%/}"
spec_file="$(pm_spec_file "$spec_id")"
task_file="$(pm_task_path "$task_id" "$task_title")"
communication_log="$(pm_task_conversation_path "$task_id" "$task_title")"
board_file="$doc_root/proj-management/board.md"
today="$(date +%F)"

if [[ ! -f "$spec_file" ]]; then
  echo "Spec file not found: $spec_file" >&2
  echo "Create it first with: scripts/create-spec.sh $spec_id \"Title\" \"Description\"" >&2
  exit 1
fi

if [[ -e "$task_file" ]]; then
  echo "Task file already exists: $task_file" >&2
  exit 1
fi

mkdir -p "$(dirname "$task_file")" "$(dirname "$communication_log")" "$(dirname "$board_file")"

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
| Status | draft |
| Phase | $phase |
| Owner | $owner |
| Dependencies | none |
| Parallel With |  |
| Last Updated | $today |

## Context

$task_description

## Scope

- Specific work included in this task.

## Out Of Scope

- Specific work excluded from this task.

## Files Or Modules Expected

- \`<path or module>\`

## Implementation Details

- Concrete implementation instruction.

## Definition Of Done

- Implementation satisfies the task scope.
- Relevant docs or configuration are updated if needed.
- Relevant verification passes.
- Communication log is updated.
- Role memory is reviewed and updated, or marked as no new durable memory.

## Acceptance Tests

- Given <state>, when <action>, then <expected result>.
- Command/test: \`<command>\` should pass.

## Verification Commands

\`\`\`bash
<command>
\`\`\`

## Risks And Notes

- Risk, assumption, or note.
EOF

pm_init_task_conversation "$spec_id" "$task_id" "$task_title" "draft"

if [[ ! -f "$board_file" ]]; then
  cat > "$board_file" <<'EOF'
# Project Board

| Spec | Task | Title | Status | Owner | Branch | PR | Loop | Blocker | Updated |
|---|---|---|---|---|---|---|---|---|---|
EOF
fi

pm_update_board_row "$spec_id" "$task_id" "$task_title" "Ready" "$owner" "" "" "0/8" "none" "$today"
pm_touch_spec "$spec_file"
pm_touch_task_file "$task_file"
pm_touch_communication_log "$communication_log"

echo "Linked $task_id to $spec_file"
echo "Created $task_file"
echo "Created $communication_log"
echo "Updated $board_file"
echo "Task ID: $task_id"
