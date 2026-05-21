#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/record-pr-comment.sh SPEC_ID TASK_ID AUTHOR "PR_COMMENT_URL" "SUMMARY" [TYPE]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 5 || $# -gt 6 ]]; then usage >&2; exit 1; fi
spec_id="$1"; task_id="$2"; author="$3"; url="$4"; summary="$5"; type="${6:-pr-comment}"; today="$(pm_today)"
pm_append_log "$spec_id" "PR Comments" "### $today - $task_id - $type

- Author: $author
- URL: $url
- Summary: $summary"
pm_update_all "$spec_id" "$task_id" "" "" "" "" ""
echo "Recorded PR comment"
