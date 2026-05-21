#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/record-merge.sh SPEC_ID TASK_ID MERGE_COMMIT "EVIDENCE"
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 4 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
merge_commit="$3"
evidence="$4"
today="$(pm_today)"

pm_update_task_status "$spec_id" "$task_id" "Done"
pm_update_all "$spec_id" "$task_id" "Done" "" "" "" "none"
pm_append_log "$task_id" "Final Approvals" "### $today - $task_id - merged

- Merge Commit: $merge_commit
- Evidence: $evidence"

echo "Recorded merge for $task_id"
