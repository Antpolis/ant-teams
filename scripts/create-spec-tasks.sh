#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-spec-tasks.sh SPEC_ID "SPEC_TITLE" "SPEC_DESCRIPTION" [OWNER]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Creates a spec Markdown file and a spec task Markdown file from standard templates.

Examples:
  scripts/create-spec-tasks.sh SPEC-001 "Add pgvector search" "Add semantic search backed by pgvector."
  scripts/create-spec-tasks.sh SPEC-001 "Add pgvector search" "Add semantic search backed by pgvector." platform-team

Output:
  $DOC_ROOT/spec/<SPEC_ID>.md
  $DOC_ROOT/proj-management/tasks/<SPEC_ID>-tasks.md
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
spec_template="$doc_root/proj-management/templates/spec-template.md"
tasks_template="$doc_root/proj-management/templates/spec-tasks-template.md"
spec_dir="$doc_root/spec"
tasks_dir="$doc_root/proj-management/tasks"
communication_dir="$doc_root/proj-management/communication"
spec_output="${spec_dir}/${spec_id}.md"
tasks_output="${tasks_dir}/${spec_id}-tasks.md"
communication_log="${communication_dir}/${spec_id}-communication.md"
today="$(date +%F)"

if [[ ! -f "$spec_template" ]]; then
  echo "Spec template not found: $spec_template" >&2
  exit 1
fi

if [[ ! -f "$tasks_template" ]]; then
  echo "Task template not found: $tasks_template" >&2
  exit 1
fi

if [[ -e "$spec_output" ]]; then
  echo "Spec file already exists: $spec_output" >&2
  exit 1
fi

if [[ -e "$tasks_output" ]]; then
  echo "Task file already exists: $tasks_output" >&2
  exit 1
fi

mkdir -p "$spec_dir" "$tasks_dir" "$communication_dir"
cp "$spec_template" "$spec_output"
cp "$tasks_template" "$tasks_output"

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

SPEC_ID="$spec_id" \
SPEC_TITLE="$spec_title" \
SOURCE_SPEC="$spec_output" \
OWNER="$owner" \
COMMUNICATION_LOG="$communication_log" \
DATE="$today" \
perl -0pi -e '
  s/__SPEC_ID__/$ENV{SPEC_ID}/g;
  s/__SPEC_TITLE__/$ENV{SPEC_TITLE}/g;
  s/__SOURCE_SPEC__/$ENV{SOURCE_SPEC}/g;
  s/__OWNER__/$ENV{OWNER}/g;
  s/__COMMUNICATION_LOG__/$ENV{COMMUNICATION_LOG}/g;
  s/__DATE__/$ENV{DATE}/g;
' "$tasks_output"

echo "Created $spec_output"
echo "Created $tasks_output"
