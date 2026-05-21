#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-spec-tasks.sh [--spec-id SPEC_ID] "SPEC_TITLE" "SPEC_DESCRIPTION" [OWNER]

Compatibility wrapper for older flows. Specs are now created as spec-only documents,
and tasks are created one file per task via create-task.sh.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$script_dir/create-spec.sh" "$@"
echo "Note: task files are now created per task with create-task.sh"
