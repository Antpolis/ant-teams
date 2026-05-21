#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/record-qa-smoke.sh SPEC_ID TASK_ID RESULT "EVIDENCE"

Results:
  passed, failed, blocked
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 4 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
result="$3"
evidence="$4"
today="$(pm_today)"

case "$result" in
  passed) status="Approved"; blocker="none" ;;
  failed) status="Rework"; blocker="qa-failed" ;;
  blocked) status="Blocked"; blocker="qa-blocker" ;;
  *) echo "Unknown QA result: $result" >&2; exit 1 ;;
esac

pm_update_task_status "$spec_id" "$task_id" "$status"
pm_update_all "$spec_id" "$task_id" "$status" "" "" "" "$blocker"
pm_append_log "$spec_id" "QA Smoke Results" "### $today - $task_id - QA Smoke: $result

- Next Status: $status
- Evidence: $evidence"

echo "Recorded QA smoke for $task_id: $result"
