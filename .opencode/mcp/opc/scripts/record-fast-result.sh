#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/record-fast-result.sh SPEC_ID TASK_ID RESULT "EVIDENCE" [NEXT_STEP]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 4 || $# -gt 5 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
result="$3"
evidence="$4"
next_step="${5:-}"
today="$(pm_today)"

case "$result" in
  approved) status="Approved"; blocker="none" ;;
  rework) status="Rework"; blocker="fast-rework" ;;
  blocked) status="Blocked"; blocker="fast-blocker" ;;
  promote) status="Deferred"; blocker="promote-to-normal-flow" ;;
  *) echo "Unknown fast-path result: $result" >&2; exit 1 ;;
esac

pm_update_task_status "$spec_id" "$task_id" "$status"
pm_update_all "$spec_id" "$task_id" "$status" "" "" "" "$blocker"
pm_append_log "$task_id" "Final Approvals" "### $today - $task_id - fast path result: $result

- Next Status: $status
- Evidence: $evidence
- Next Step: ${next_step:-none}"

echo "Recorded fast-path result for $task_id: $result"
