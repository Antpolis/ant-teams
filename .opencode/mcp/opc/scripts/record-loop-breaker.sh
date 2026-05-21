#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/record-loop-breaker.sh SPEC_ID TASK_ID LOOP "ISSUE" "ARCHITECT_DECISION" [NEXT_STATUS]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 5 || $# -gt 6 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
loop="$3"
issue="$4"
decision="$5"
next_status="${6:-Loop Breaker}"
today="$(pm_today)"

pm_require_valid_status "$next_status"
pm_update_task_status "$spec_id" "$task_id" "$next_status"
pm_update_all "$spec_id" "$task_id" "$next_status" "" "" "$loop" "loop-breaker"
pm_append_log "$task_id" "Review Loop Tracker" "### $today - $task_id - loop breaker

- Loop: $loop
- Issue: $issue
- Architect Decision: $decision
- Next Status: $next_status"
echo "Recorded loop breaker for $task_id"
