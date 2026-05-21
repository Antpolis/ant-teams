#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/reply-task-comment.sh SPEC_ID COMMENT_ID AUTHOR "REPLY" [STATUS]
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
today="$(date +%F)"
timestamp="$(date +%Y%m%d%H%M%S)"
reply_id="RPL-${timestamp}"

task_id="$(find "$(pm_doc_root)/proj-management/communication" -type f -name 'TASK-CONV-*.md' -exec rg -l --fixed-strings "$comment_id" {} + 2>/dev/null | head -n 1 | sed -E 's|.*/TASK-CONV-([0-9]{3}).*$|TASK-\1|')"
if [[ -z "$task_id" ]]; then
  echo "Unable to determine task for target: $comment_id" >&2
  exit 1
fi

[[ "$(pm_task_spec_id "$task_id")" == "$spec_id" ]] || {
  echo "Comment $comment_id does not belong to $spec_id" >&2
  exit 1
}

communication_log="$(pm_communication_log "$task_id")"
[[ -f "$communication_log" ]] || {
  echo "Communication log not found: $communication_log" >&2
  exit 1
}

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
        last if $lines[$j] =~ /^##\s+/;
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
