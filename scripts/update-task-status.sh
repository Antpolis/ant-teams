#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/update-task-status.sh SPEC_ID TASK_ID STATUS [BRANCH] [PR] [LOOP] [BLOCKER]

Examples:
  scripts/update-task-status.sh SPEC-001 TASK-001 "In Development" task/TASK-001-search
  scripts/update-task-status.sh SPEC-001 TASK-001 "Architecture Review" task/TASK-001-search https://github.com/org/repo/pull/1 1/8 none
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 3 || $# -gt 7 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
status="$3"
branch="${4:-}"
pr="${5:-}"
loop="${6:-}"
blocker="${7:-}"
today="$(pm_today)"

pm_require_valid_status "$status"

pm_update_task_status "$spec_id" "$task_id" "$status"
pm_update_all "$spec_id" "$task_id" "$status" "$branch" "$pr" "$loop" "$blocker"
pm_append_log "$spec_id" "Status Updates" "### $today - $task_id - $status

- Branch: ${branch:-}
- PR: ${pr:-}
- Loop: ${loop:-}
- Blocker: ${blocker:-none}"

echo "Updated $task_id to $status"
