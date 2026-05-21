#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/open-review-loop.sh SPEC_ID TASK_ID BRANCH PR_URL [LOOP]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 4 || $# -gt 5 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
branch="$3"
pr_url="$4"
loop="${5:-1/8}"
today="$(pm_today)"

pm_update_task_status "$spec_id" "$task_id" "Architecture Review"
pm_update_all "$spec_id" "$task_id" "Architecture Review" "$branch" "$pr_url" "$loop" "none"
pm_append_log "$task_id" "Review Loop Tracker" "### $today - $task_id - Review Loop Opened

- Branch: $branch
- PR: $pr_url
- Loop: $loop
- Status: Architecture Review"

echo "Opened review loop for $task_id"
