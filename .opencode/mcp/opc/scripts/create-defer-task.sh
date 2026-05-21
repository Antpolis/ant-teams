#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/create-defer-task.sh SPEC_ID TASK_ID DEFER_ID "REASON" "DEFERRED_WORK" "TARGET" [RISK]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 6 || $# -gt 7 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
defer_id="$3"
reason="$4"
deferred_work="$5"
target="$6"
risk="${7:-medium}"
today="$(pm_today)"

pm_update_task_status "$spec_id" "$task_id" "Deferred"
pm_update_all "$spec_id" "$task_id" "Deferred" "" "" "" "$defer_id"
pm_append_log "$task_id" "Defer Tasks" "### $today - $defer_id - $task_id

- Created By: architect
- Reason: $reason
- Deferred Work: $deferred_work
- Target: $target
- Risk: $risk
- Status: open"

echo "Created defer task $defer_id"
