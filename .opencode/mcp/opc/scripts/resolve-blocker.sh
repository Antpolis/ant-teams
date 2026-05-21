#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/resolve-blocker.sh SPEC_ID TASK_ID BLOCKER_ID "RESOLUTION" [NEXT_STATUS]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 4 || $# -gt 5 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
blocker_id="$3"
resolution="$4"
next_status="${5:-Ready}"
today="$(pm_today)"

pm_require_valid_status "$next_status"
pm_update_task_status "$spec_id" "$task_id" "$next_status"
pm_update_all "$spec_id" "$task_id" "$next_status" "" "" "" "none"
pm_append_log "$task_id" "Blockers" "### $today - $blocker_id - resolved

- Task: $task_id
- Resolution: $resolution
- Next Status: $next_status"

echo "Resolved blocker $blocker_id"
