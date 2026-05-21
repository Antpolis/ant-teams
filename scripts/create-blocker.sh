#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/create-blocker.sh SPEC_ID TASK_ID BLOCKER_ID TYPE "DESCRIPTION" "NEEDS"
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 6 ]]; then usage >&2; exit 1; fi

spec_id="$1"; task_id="$2"; blocker_id="$3"; type="$4"; description="$5"; needs="$6"; today="$(pm_today)"

pm_update_task_status "$spec_id" "$task_id" "Blocked"
pm_update_all "$spec_id" "$task_id" "Blocked" "" "" "" "$blocker_id"
pm_append_log "$spec_id" "Blockers" "### $today - $blocker_id - $task_id

- Type: $type
- Description: $description
- Needs: $needs
- Status: open"

echo "Created blocker $blocker_id"
