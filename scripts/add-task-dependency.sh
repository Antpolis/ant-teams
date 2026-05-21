#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/add-task-dependency.sh SPEC_ID TASK_ID DEPENDS_ON_TASK_ID
USAGE
}
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 3 ]]; then usage >&2; exit 1; fi
spec_id="$1"; task_id="$2"; dep="$3"; tasks_file="$(pm_tasks_file "$spec_id")"; today="$(pm_today)"
[[ -f "$tasks_file" ]] || { echo "Task file not found: $tasks_file" >&2; exit 1; }
pm_task_exists "$spec_id" "$task_id" || { echo "Task not found: $task_id" >&2; exit 1; }
pm_task_exists "$spec_id" "$dep" || { echo "Dependency task not found: $dep" >&2; exit 1; }
TASK_ID="$task_id" DEP="$dep" perl -0pi -e '
  s/(^### \Q$ENV{TASK_ID}\E:.*?\n\nStatus: [^\n]+\n\nPhase: [^\n]+\nOwner: [^\n]+\nDependencies: )[^\n]+/${1}$ENV{DEP}/ms;
  my @out; for my $line (split /\n/, $_, -1) { if ($line =~ /^\|\s*\Q$ENV{TASK_ID}\E\s*\|/) { my @c = split /\|/, $line, -1; $c[6] = " $ENV{DEP} "; $line = join "|", @c } push @out, $line } $_ = join "\n", @out;
' "$tasks_file"
pm_append_log "$spec_id" "Dependency Updates" "### $today - $task_id - dependency added

- Depends On: $dep"
pm_update_all "$spec_id" "$task_id" "" "" "" "" ""
echo "Added dependency $dep to $task_id"
