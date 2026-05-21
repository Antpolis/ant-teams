#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/read-task-replies.sh SPEC_ID COMMENT_OR_REPLY_ID
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
target_id="$2"
task_id="$(find "$(pm_doc_root)/proj-management/communication" -type f -name 'TASK-CONV-*.md' -exec rg -l --fixed-strings "$target_id" {} + 2>/dev/null | head -n 1 | sed -E 's|.*/TASK-CONV-([0-9]{3}).*$|TASK-\1|')"
[[ -n "$task_id" ]] || { echo "Comment or reply not found: $target_id" >&2; exit 1; }
[[ "$(pm_task_spec_id "$task_id")" == "$spec_id" ]] || { echo "Thread does not belong to $spec_id" >&2; exit 1; }
communication_log="$(pm_communication_log "$task_id")"

if [[ ! -f "$communication_log" ]]; then
  echo "Communication log not found: $communication_log" >&2
  exit 1
fi

TARGET_ID="$target_id" perl -ne '
  if (!$found && /^(\s*)- \*\*\Q$ENV{TARGET_ID}\E\*\*/) {
    $found = 1;
    $base = length($1);
    next;
  }

  if ($found) {
    if (/^##\s+/) {
      exit;
    }
    if (/^(\s*)- \*\*/ && length($1) <= $base) {
      exit;
    }
    if (/^(\s*)- \*\*/ && length($1) > $base) {
      $in_replies = 1;
    }
    print if $in_replies;
  }

  END {
    if (!$found) {
      print STDERR "Comment or reply not found: $ENV{TARGET_ID}\n";
      exit 1;
    }
  }
' "$communication_log"
