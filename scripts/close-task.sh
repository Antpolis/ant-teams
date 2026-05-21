#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/close-task.sh SPEC_ID TASK_ID "EVIDENCE"

Marks a task Done after approvals/checks are complete.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 3 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
evidence="$3"
today="$(pm_today)"

pm_update_task_status "$spec_id" "$task_id" "Done"
pm_update_all "$spec_id" "$task_id" "Done" "" "" "" "none"
pm_append_log "$spec_id" "Task Closures" "### $today - $task_id - Done

- Evidence: $evidence"

echo "Closed $task_id"
