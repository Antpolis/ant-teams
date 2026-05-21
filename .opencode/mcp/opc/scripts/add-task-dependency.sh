#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/add-task-dependency.sh SPEC_ID TASK_ID DEPENDS_ON_TASK_ID
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 3 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
dep="$3"
task_file="$(pm_task_file "$task_id")"
today="$(pm_today)"

pm_task_exists "$spec_id" "$task_id" || { echo "Task not found: $task_id" >&2; exit 1; }
pm_task_exists "$spec_id" "$dep" || { echo "Dependency task not found: $dep" >&2; exit 1; }

pm_update_metadata_row "$task_file" "Dependencies" "$dep"
pm_touch_task_file "$task_file"
pm_append_log "$task_id" "Task Discussion" "### $today - $task_id - dependency added

- Depends On: $dep"
pm_update_all "$spec_id" "$task_id" "" "" "" "" ""
echo "Added dependency $dep to $task_id"
