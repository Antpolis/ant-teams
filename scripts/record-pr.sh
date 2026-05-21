#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/record-pr.sh SPEC_ID TASK_ID BRANCH PR_URL [LOOP]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 4 || $# -gt 5 ]]; then usage >&2; exit 1; fi
spec_id="$1"; task_id="$2"; branch="$3"; pr="$4"; loop="${5:-1/8}"; today="$(pm_today)"
pm_update_task_status "$spec_id" "$task_id" "PR Open"
pm_update_all "$spec_id" "$task_id" "PR Open" "$branch" "$pr" "$loop" "none"
pm_append_log "$spec_id" "PR Lifecycle" "### $today - $task_id - PR opened

- Branch: $branch
- PR: $pr
- Loop: $loop"
echo "Recorded PR $pr"
