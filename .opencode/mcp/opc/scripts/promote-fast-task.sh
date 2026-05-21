#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/promote-fast-task.sh FAST_SPEC_ID FAST_TASK_ID TARGET_SPEC_ID "TARGET_SPEC_TITLE" "TARGET_SPEC_DESCRIPTION" [OWNER]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 5 || $# -gt 6 ]]; then usage >&2; exit 1; fi

fast_spec_id="$1"
fast_task_id="$2"
target_spec_id="$3"
target_spec_title="$4"
target_spec_description="$5"
owner="${6:-unassigned}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
today="$(pm_today)"

pm_task_exists "$fast_spec_id" "$fast_task_id" || { echo "Fast-path task not found: $fast_spec_id / $fast_task_id" >&2; exit 1; }
[[ ! -f "$(pm_spec_file "$target_spec_id")" ]] || { echo "Target spec already exists: $target_spec_id" >&2; exit 1; }

bash "$script_dir/create-spec.sh" --spec-id "$target_spec_id" "$target_spec_title" "$target_spec_description" "$owner"

pm_update_task_status "$fast_spec_id" "$fast_task_id" "Deferred"
pm_update_all "$fast_spec_id" "$fast_task_id" "Deferred" "" "" "" "promoted"
pm_append_log "$fast_task_id" "Defer Tasks" "### $today - $fast_task_id - promoted to normal flow

- Target Spec: $target_spec_id
- Target Title: $target_spec_title
- Reason: fast-path scope grew beyond lightweight handling"

echo "Promoted $fast_spec_id / $fast_task_id to $target_spec_id"
