#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/create-task-comment.sh SPEC_ID TASK_ID AUTHOR "COMMENT" [TYPE]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Types:
  note, question, review-finding, blocker, qa-result, architect-decision

Examples:
  scripts/create-task-comment.sh SPEC-001 TASK-001 developer "Implementation is ready for review."
  scripts/create-task-comment.sh SPEC-001 TASK-001 architect-reviewer "Use existing repository pattern." review-finding
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 4 || $# -gt 5 ]]; then
  usage >&2
  exit 1
fi

spec_id="$1"
task_id="$2"
author="$3"
comment="$4"
type="${5:-note}"

doc_root="${DOC_ROOT:-$(pm_doc_root)}"
doc_root="${doc_root%/}"
tasks_file="$doc_root/proj-management/tasks/${spec_id}-tasks.md"
communication_log="$doc_root/proj-management/communication/${spec_id}-communication.md"
today="$(date +%F)"
timestamp="$(date +%Y%m%d%H%M%S)"
comment_id="CMT-${timestamp}"

if [[ ! -f "$tasks_file" ]]; then
  echo "Task file not found: $tasks_file" >&2
  exit 1
fi

if ! grep -q "^### ${task_id}:" "$tasks_file"; then
  echo "Task not found in $tasks_file: $task_id" >&2
  exit 1
fi

if ! grep -q '^## Task Comments$' "$tasks_file"; then
  printf '\n## Task Comments\n' >> "$tasks_file"
fi

comment_block="
### $comment_id - $task_id - $type

- Date: $today
- Author: $author
- Status: open

$comment
"

if grep -q '^## Task Comment Replies$' "$tasks_file"; then
  COMMENT_BLOCK="$comment_block" perl -0pi -e 's/\n## Task Comment Replies\n/\n$ENV{COMMENT_BLOCK}\n## Task Comment Replies\n/' "$tasks_file"
else
  printf '%s\n' "$comment_block" >> "$tasks_file"
fi

mkdir -p "$(dirname "$communication_log")"
if [[ ! -f "$communication_log" ]]; then
  cat > "$communication_log" <<EOF
# Communication Log: $spec_id

## Agent Handoffs
EOF
fi

if ! grep -q '^## Task Discussions$' "$communication_log"; then
  printf '\n## Task Discussions\n' >> "$communication_log"
fi

if ! grep -q "^### ${task_id}$" "$communication_log"; then
  printf '\n### %s\n' "$task_id" >> "$communication_log"
fi

thread_block="- **$comment_id** [$type] $author on $today (status: open)
  $comment
"

TASK_ID="$task_id" THREAD_BLOCK="$thread_block" perl -0pi -e '
  my $task = $ENV{TASK_ID};
  my $block = $ENV{THREAD_BLOCK};
  my @lines = split /\n/, $_, -1;
  my $insert = -1;
  for (my $i = 0; $i < @lines; $i++) {
    if ($lines[$i] =~ /^### \Q$task\E\s*$/) {
      $insert = $i + 1;
      for (my $j = $i + 1; $j < @lines; $j++) {
        last if $lines[$j] =~ /^###\s+/ || $lines[$j] =~ /^##\s+/;
        $insert = $j + 1;
      }
      last;
    }
  }
  splice @lines, $insert, 0, split(/\n/, $block) if $insert >= 0;
  $_ = join "\n", @lines;
' "$communication_log"

pm_update_all "$spec_id" "$task_id" "" "" "" "" ""

echo "$comment_id"
