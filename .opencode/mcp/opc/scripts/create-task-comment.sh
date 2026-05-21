#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-task-comment.sh SPEC_ID TASK_ID AUTHOR "COMMENT" [TYPE]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Types:
  note, question, review-finding, blocker, qa-result, architect-decision
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 4 || $# -gt 5 ]]; then
  usage >&2
  exit 1
fi

spec_id="$1"
task_id="$2"
author="$3"
comment="$4"
type="${5:-note}"
task_file="$(pm_task_file "$task_id")"
communication_log="$(pm_communication_log "$task_id")"
today="$(date +%F)"
timestamp="$(date +%Y%m%d%H%M%S)"
comment_id="CMT-${timestamp}"

pm_task_exists "$spec_id" "$task_id" || {
  echo "Task not found for spec/task: $spec_id / $task_id" >&2
  exit 1
}

if [[ ! -f "$communication_log" ]]; then
  pm_init_task_conversation "$spec_id" "$task_id" "$(pm_task_title "$task_id")" "$(pm_metadata_get "$task_file" "Status")"
fi

pm_append_log "$task_id" "Task Discussion" "- **$comment_id** [$type] $author on $today (status: open)
  $comment"

pm_update_all "$spec_id" "$task_id" "" "" "" "" ""

echo "$comment_id"
