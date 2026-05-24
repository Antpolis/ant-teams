#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/record-merge.sh SPEC_ID TASK_ID MERGE_COMMIT "EVIDENCE" [WORKTREE_PATH]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 4 || $# -gt 5 ]]; then usage >&2; exit 1; fi
spec_id="$1"; task_id="$2"; merge_commit="$3"; evidence="$4"; worktree_path="${5:-}"; today="$(pm_today)"
pm_update_task_status "$spec_id" "$task_id" "Done"
pm_update_all "$spec_id" "$task_id" "Done" "" "" "" "none"
pm_append_log "$spec_id" "PR Lifecycle" "### $today - $task_id - merged

- Merge Commit: $merge_commit
- Evidence: $evidence
${worktree_path:+- Cleanup Candidate: $worktree_path}"
echo "Recorded merge for $task_id"
