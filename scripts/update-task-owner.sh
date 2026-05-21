#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/update-task-owner.sh SPEC_ID TASK_ID OWNER
USAGE
}
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 3 ]]; then usage >&2; exit 1; fi
spec_id="$1"; task_id="$2"; owner="$3"; tasks_file="$(pm_tasks_file "$spec_id")"; today="$(pm_today)"
[[ -f "$tasks_file" ]] || { echo "Task file not found: $tasks_file" >&2; exit 1; }
TASK_ID="$task_id" OWNER="$owner" perl -0pi -e '
  s/(^### \Q$ENV{TASK_ID}\E:.*?\n\nStatus: [^\n]+\n\nPhase: [^\n]+\nOwner: )[^\n]+/${1}$ENV{OWNER}/ms;
  my @out; for my $line (split /\n/, $_, -1) { if ($line =~ /^\|\s*\Q$ENV{TASK_ID}\E\s*\|/) { my @c = split /\|/, $line, -1; $c[5] = " $ENV{OWNER} "; $line = join "|", @c } push @out, $line } $_ = join "\n", @out;
' "$tasks_file"
pm_append_log "$spec_id" "Ownership Updates" "### $today - $task_id - owner updated

- Owner: $owner"
pm_update_all "$spec_id" "$task_id" "" "" "" "" ""
echo "Updated owner for $task_id"
