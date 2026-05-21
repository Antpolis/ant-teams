#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/read-task-comments.sh SPEC_ID TASK_ID
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

spec_id="$1"
task_id="$2"
pm_task_exists "$spec_id" "$task_id" || { echo "Task not found: $spec_id / $task_id" >&2; exit 1; }
communication_log="$(pm_communication_log "$task_id")"

if [[ ! -f "$communication_log" ]]; then
  echo "Communication log not found: $communication_log" >&2
  exit 1
fi

awk '
  $0 == "## Task Discussion" { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$communication_log"
