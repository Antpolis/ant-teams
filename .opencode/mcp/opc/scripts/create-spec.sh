#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-spec.sh [--spec-id SPEC_ID] "SPEC_TITLE" "SPEC_DESCRIPTION" [OWNER]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Creates:
  $DOC_ROOT/spec/<SPEC_ID>-<slug>.md

Examples:
  scripts/create-spec.sh "Add pgvector search" "Add semantic search backed by pgvector."
  scripts/create-spec.sh --spec-id SPEC-001 "Add pgvector search" "Add semantic search backed by pgvector."
  DOC_ROOT=.docs scripts/create-spec.sh "Add pgvector search" "Add semantic search backed by pgvector." platform-team
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

spec_id=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec-id)
      spec_id="${2:-}"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 1
fi

spec_title="$1"
spec_description="$2"
owner="${3:-unassigned}"
spec_id="${spec_id:-$(pm_next_id SPEC)}"

doc_root="${DOC_ROOT:-$(pm_doc_root)}"
doc_root="${doc_root%/}"
template="$doc_root/proj-management/templates/spec-template.md"
spec_dir="$doc_root/spec"
task_directory="$doc_root/proj-management/tasks"
task_file_pattern="$doc_root/proj-management/tasks/TASK-xxx-<slug>.md"
communication_pattern="$doc_root/proj-management/communication/TASK-CONV-xxx-<slug>.md"
spec_output="$(pm_spec_path "$spec_id" "$spec_title")"
today="$(date +%F)"

if [[ ! -f "$template" ]]; then
  echo "Spec template not found: $template" >&2
  echo "Run: scripts/setup-doc-structure.sh $doc_root" >&2
  exit 1
fi

if [[ -e "$spec_output" ]]; then
  echo "Spec file already exists: $spec_output" >&2
  exit 1
fi

mkdir -p "$spec_dir"
cp "$template" "$spec_output"

SPEC_ID="$spec_id" \
SPEC_TITLE="$spec_title" \
SPEC_DESCRIPTION="$spec_description" \
OWNER="$owner" \
TASK_DIRECTORY="$task_directory" \
TASK_FILE_PATTERN="$task_file_pattern" \
COMMUNICATION_PATTERN="$communication_pattern" \
DATE="$today" \
perl -0pi -e '
  s/__SPEC_ID__/$ENV{SPEC_ID}/g;
  s/__SPEC_TITLE__/$ENV{SPEC_TITLE}/g;
  s/__SPEC_DESCRIPTION__/$ENV{SPEC_DESCRIPTION}/g;
  s/__OWNER__/$ENV{OWNER}/g;
  s/__TASK_DIRECTORY__/$ENV{TASK_DIRECTORY}/g;
  s/__TASK_FILE_PATTERN__/$ENV{TASK_FILE_PATTERN}/g;
  s/__COMMUNICATION_PATTERN__/$ENV{COMMUNICATION_PATTERN}/g;
  s/__DATE__/$ENV{DATE}/g;
' "$spec_output"

echo "Created $spec_output"
echo "Spec ID: $spec_id"
