#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/read-task-replies.sh SPEC_ID COMMENT_OR_REPLY_ID

Environment:
  DOC_ROOT  Documentation root folder. Defaults to docs.

Prints all nested replies below a comment or reply from the spec communication log.

Examples:
  scripts/read-task-replies.sh SPEC-001 CMT-20260519113610
  scripts/read-task-replies.sh SPEC-001 RPL-20260519113611
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
communication_log="$(pm_communication_log "$spec_id")"

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
    if (/^##\s+/ || /^###\s+/) {
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
