#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/record-review-result.sh SPEC_ID TASK_ID RESULT LOOP "SUMMARY"
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 5 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
result="$3"
loop="$4"
summary="$5"
today="$(pm_today)"

case "$result" in
  approved) status="QA Smoke" ;;
  changes-requested) status="Rework" ;;
  blocked) status="Blocked" ;;
  loop-breaker) status="Loop Breaker" ;;
  *) echo "Unknown result: $result" >&2; exit 1 ;;
esac

blocker="none"
[[ "$status" == "Blocked" ]] && blocker="review-blocker"
[[ "$status" == "Loop Breaker" ]] && blocker="loop-breaker"

pm_update_task_status "$spec_id" "$task_id" "$status"
pm_update_all "$spec_id" "$task_id" "$status" "" "" "$loop" "$blocker"
pm_append_log "$task_id" "Review Loop Tracker" "### $today - $task_id - Review Result: $result

- Loop: $loop
- Next Status: $status
- Summary: $summary"

echo "Recorded review result for $task_id: $result"
