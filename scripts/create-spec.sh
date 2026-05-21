#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-spec.sh SPEC_ID "SPEC_TITLE" "SPEC_DESCRIPTION" [OWNER]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Creates:
  $DOC_ROOT/spec/<SPEC_ID>.md

Examples:
  scripts/create-spec.sh SPEC-001 "Add pgvector search" "Add semantic search backed by pgvector."
  DOC_ROOT=.docs scripts/create-spec.sh SPEC-001 "Add pgvector search" "Add semantic search backed by pgvector." platform-team
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 3 || $# -gt 4 ]]; then
  usage >&2
  exit 1
fi

spec_id="$1"
spec_title="$2"
spec_description="$3"
owner="${4:-unassigned}"

doc_root="${DOC_ROOT:-$(pm_doc_root)}"
doc_root="${doc_root%/}"
template="$doc_root/proj-management/templates/spec-template.md"
spec_dir="$doc_root/spec"
tasks_output="$doc_root/proj-management/tasks/${spec_id}-tasks.md"
communication_log="$doc_root/proj-management/communication/${spec_id}-communication.md"
spec_output="$spec_dir/${spec_id}.md"
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
TASK_FILE="$tasks_output" \
COMMUNICATION_LOG="$communication_log" \
DATE="$today" \
perl -0pi -e '
  s/__SPEC_ID__/$ENV{SPEC_ID}/g;
  s/__SPEC_TITLE__/$ENV{SPEC_TITLE}/g;
  s/__SPEC_DESCRIPTION__/$ENV{SPEC_DESCRIPTION}/g;
  s/__OWNER__/$ENV{OWNER}/g;
  s/__TASK_FILE__/$ENV{TASK_FILE}/g;
  s/__COMMUNICATION_LOG__/$ENV{COMMUNICATION_LOG}/g;
  s/__DATE__/$ENV{DATE}/g;
' "$spec_output"

echo "Created $spec_output"
