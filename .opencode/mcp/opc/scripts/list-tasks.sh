#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/list-tasks.sh [--status STATUS] [--spec SPEC_ID] [--name TEXT]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Filters:
  --status  Exact status match, case-insensitive.
  --spec    Exact spec ID match, case-insensitive.
  --name    Partial match against task ID or task title, case-insensitive.

Examples:
  scripts/list-tasks.sh
  scripts/list-tasks.sh --status "In Development"
  scripts/list-tasks.sh --spec SPEC-001
  scripts/list-tasks.sh --name pgvector
  scripts/list-tasks.sh --spec SPEC-001 --status Rework --name migration
USAGE
}

status_filter=""
spec_filter=""
name_filter=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --status)
      [[ $# -ge 2 ]] || { echo "Missing value for --status" >&2; exit 1; }
      status_filter="$2"
      shift 2
      ;;
    --spec)
      [[ $# -ge 2 ]] || { echo "Missing value for --spec" >&2; exit 1; }
      spec_filter="$2"
      shift 2
      ;;
    --name)
      [[ $# -ge 2 ]] || { echo "Missing value for --name" >&2; exit 1; }
      name_filter="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

board_file="$(pm_board_file)"

if [[ ! -f "$board_file" ]]; then
  echo "Board file not found: $board_file" >&2
  exit 1
fi

STATUS_FILTER="$status_filter" \
SPEC_FILTER="$spec_filter" \
NAME_FILTER="$name_filter" \
awk -F'|' '
  function trim(value) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    return value
  }
  function lower(value) {
    return tolower(value)
  }
  BEGIN {
    status_filter = lower(ENVIRON["STATUS_FILTER"])
    spec_filter = lower(ENVIRON["SPEC_FILTER"])
    name_filter = lower(ENVIRON["NAME_FILTER"])
    printed = 0
  }
  /^\|/ {
    spec = trim($2)
    task = trim($3)
    title = trim($4)
    status = trim($5)

    if (spec == "Spec" || spec == "---" || spec == "") {
      next
    }

    if (status_filter != "" && lower(status) != status_filter) {
      next
    }
    if (spec_filter != "" && lower(spec) != spec_filter) {
      next
    }
    if (name_filter != "" && index(lower(task " " title), name_filter) == 0) {
      next
    }

    print $0
    printed = 1
  }
  END {
    if (!printed) {
      print "No matching tasks found." > "/dev/stderr"
      exit 2
    }
  }
' "$board_file"
