#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/reply-task-comment.sh SPEC_ID COMMENT_ID AUTHOR "REPLY" [STATUS]

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Statuses:
  open, addressed, resolved, blocked, deferred

Examples:
  scripts/reply-task-comment.sh SPEC-001 CMT-20260519120000 developer "Fixed in latest commit." addressed
  scripts/reply-task-comment.sh SPEC-001 CMT-20260519120000 architect-reviewer "Resolved." resolved
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
comment_id="$2"
author="$3"
reply="$4"
status="${5:-open}"

doc_root="${DOC_ROOT:-$(pm_doc_root)}"
doc_root="${doc_root%/}"
tasks_file="$doc_root/proj-management/tasks/${spec_id}-tasks.md"
communication_log="$doc_root/proj-management/communication/${spec_id}-communication.md"
today="$(date +%F)"
timestamp="$(date +%Y%m%d%H%M%S)"
reply_id="RPL-${timestamp}"

if [[ ! -f "$tasks_file" ]]; then
  echo "Task file not found: $tasks_file" >&2
  exit 1
fi

if [[ ! -f "$communication_log" ]] || ! grep -q "$comment_id" "$communication_log"; then
  echo "Comment or reply not found in $communication_log: $comment_id" >&2
  exit 1
fi

task_id="$(TARGET_ID="$comment_id" perl -ne '
  if (/^###\s+(TASK-[^\s]+)\s*$/) { $task = $1 }
  if (/\Q$ENV{TARGET_ID}\E/ && defined $task) { print $task; exit }
' "$communication_log")"
if [[ -z "$task_id" ]]; then
  echo "Unable to determine task for target: $comment_id" >&2
  exit 1
fi

if ! grep -q '^## Task Comment Replies$' "$tasks_file"; then
  printf '\n## Task Comment Replies\n' >> "$tasks_file"
fi

cat >> "$tasks_file" <<EOF

### $reply_id - Reply To $comment_id

- Task: $task_id
- Date: $today
- Author: $author
- Status: $status

$reply
EOF

TARGET_ID="$comment_id" REPLY_ID="$reply_id" AUTHOR="$author" STATUS="$status" DATE="$today" REPLY="$reply" perl -0pi -e '
  my @lines = split /\n/, $_, -1;
  my $target = $ENV{TARGET_ID};
  my $insert = -1;
  my $target_indent = "";

  for (my $i = 0; $i < @lines; $i++) {
    if ($lines[$i] =~ /^(\s*)- \*\*\Q$target\E\*\*/) {
      $target_indent = $1;
      my $depth = length($target_indent);
      $insert = $i + 1;
      for (my $j = $i + 1; $j < @lines; $j++) {
        last if $lines[$j] =~ /^##\s+/ || $lines[$j] =~ /^###\s+/;
        if ($lines[$j] =~ /^(\s*)- \*\*/ && length($1) <= $depth) {
          last;
        }
        $insert = $j + 1;
      }
      last;
    }
  }

  die "Target not found in threaded communication log: $target\n" if $insert < 0;

  my $indent = $target_indent . "    ";
  my @reply_lines = (
    $indent . "- **$ENV{REPLY_ID}** reply to $target by $ENV{AUTHOR} on $ENV{DATE} (status: $ENV{STATUS})",
    $indent . "  $ENV{REPLY}"
  );
  splice @lines, $insert, 0, @reply_lines;
  $_ = join "\n", @lines;
' "$communication_log"

pm_update_all "$spec_id" "$task_id" "" "" "" "" ""

echo "$reply_id"
