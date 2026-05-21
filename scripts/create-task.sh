#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-task.sh SPEC_ID TASK_ID "TASK_TITLE" "TASK_DESCRIPTION" [OWNER] [PHASE]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Creates or updates:
  $DOC_ROOT/proj-management/tasks/<SPEC_ID>-tasks.md
  $DOC_ROOT/proj-management/board.md

Examples:
  scripts/create-task.sh SPEC-001 TASK-001 "Add database migration" "Create migration for vector columns."
  DOC_ROOT=.docs scripts/create-task.sh SPEC-001 TASK-001 "Add database migration" "Create migration for vector columns." platform-team "Phase 1"
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 4 || $# -gt 6 ]]; then
  usage >&2
  exit 1
fi

spec_id="$1"
task_id="$2"
task_title="$3"
task_description="$4"
owner="${5:-unassigned}"
phase="${6:-Phase 1}"

doc_root="${DOC_ROOT:-$(pm_doc_root)}"
doc_root="${doc_root%/}"
spec_file="$doc_root/spec/${spec_id}.md"
tasks_file="$doc_root/proj-management/tasks/${spec_id}-tasks.md"
communication_log="$doc_root/proj-management/communication/${spec_id}-communication.md"
board_file="$doc_root/proj-management/board.md"
today="$(date +%F)"

if [[ ! -f "$spec_file" ]]; then
  echo "Spec file not found: $spec_file" >&2
  echo "Create it first with: scripts/create-spec.sh $spec_id \"Title\" \"Description\"" >&2
  exit 1
fi

if [[ -f "$tasks_file" ]] && grep -q "^### ${task_id}:" "$tasks_file"; then
  echo "Task already exists in $tasks_file: $task_id" >&2
  exit 1
fi

mkdir -p "$(dirname "$tasks_file")" "$(dirname "$communication_log")" "$(dirname "$board_file")"

if [[ ! -f "$tasks_file" ]]; then
  spec_title="$(sed -n '1s/^# //p' "$spec_file")"
  cat > "$tasks_file" <<EOF
# Tasks: $spec_title

Metadata:

| Field | Value |
|---|---|
| Spec ID | $spec_id |
| Spec Title | $spec_title |
| Source Spec | $spec_file |
| Communication Log | $communication_log |
| Status | draft |
| Owner | $owner |
| Related Docs |  |
| Architecture Guardrails |  |
| Last Updated | $today |

## Summary

Tasks for $spec_title.

## Dependencies

List cross-task, technical, environment, data, or external dependencies.

## Parallelization Plan

Describe which tasks can run at the same time and which must wait.

## Communication Log

All agent handoffs, review loops, blockers, defer tasks, and approvals must be recorded in:

\`$communication_log\`

## Task Index

| Task ID | Title | Phase | Status | Owner | Dependencies | Can Run In Parallel With |
|---|---|---|---|---|---|---|

## Tasks

## Task Comments

## Task Comment Replies
EOF
fi

task_row="| $task_id | $task_title | $phase | draft | $owner | none |  |"
task_block="
### $task_id: $task_title

Status: draft

Phase: $phase
Owner: $owner
Dependencies: none
Parallel With:

#### Context

$task_description

#### Scope

- Specific work included in this task.

#### Out Of Scope

- Specific work excluded from this task.

#### Files Or Modules Expected

- \`<path or module>\`

#### Implementation Details

- Concrete implementation instruction.

#### Definition Of Done

- Implementation satisfies the task scope.
- Relevant docs or configuration are updated if needed.
- Relevant verification passes.
- Communication log is updated.
- Role memory is reviewed and updated, or marked as no new durable memory.

#### Acceptance Tests

- Given <state>, when <action>, then <expected result>.
- Command/test: \`<command>\` should pass.

#### Verification Commands

\`\`\`bash
<command>
\`\`\`

#### Risks And Notes

- Risk, assumption, or note.
"

TASK_ROW="$task_row" perl -0pi -e 's/\n## Tasks\n/\n$ENV{TASK_ROW}\n\n## Tasks\n/' "$tasks_file"
TASK_BLOCK="$task_block" perl -0pi -e 's/\n## Task Comments\n/\n$ENV{TASK_BLOCK}\n## Task Comments\n/' "$tasks_file"

if [[ ! -f "$board_file" ]]; then
  cat > "$board_file" <<'EOF'
# Project Board

| Spec | Task | Title | Status | Owner | Branch | PR | Loop | Blocker | Updated |
|---|---|---|---|---|---|---|---|---|---|
EOF
fi

if ! grep -q "| $spec_id | $task_id |" "$board_file"; then
  printf '| %s | %s | %s | Ready | %s |  |  | 0/8 | none | %s |\n' "$spec_id" "$task_id" "$task_title" "$owner" "$today" >> "$board_file"
fi

pm_touch_spec "$spec_file"
pm_touch_task_file "$tasks_file"

echo "Linked $task_id to $spec_file"
echo "Updated $tasks_file"
echo "Updated $board_file"
