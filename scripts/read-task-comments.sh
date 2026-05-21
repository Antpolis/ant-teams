#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/read-task-comments.sh SPEC_ID TASK_ID

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Prints all threaded comments and replies for a task from the spec communication log.

Example:
  scripts/read-task-comments.sh SPEC-001 TASK-001
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
communication_log="$(pm_communication_log "$spec_id")"

if [[ ! -f "$communication_log" ]]; then
  echo "Communication log not found: $communication_log" >&2
  exit 1
fi

TASK_ID="$task_id" perl -ne '
  if (/^###\s+\Q$ENV{TASK_ID}\E\s*$/) {
    $in_task = 1;
    print;
    next;
  }
  if ($in_task && /^###\s+/) {
    exit;
  }
  if ($in_task && /^##\s+/) {
    exit;
  }
  print if $in_task;
' "$communication_log"
