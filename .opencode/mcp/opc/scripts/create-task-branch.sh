#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/create-task-branch.sh SPEC_ID TASK_ID [BASE_BRANCH] [BRANCH_NAME]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 2 || $# -gt 4 ]]; then usage >&2; exit 1; fi

spec_id="$1"
task_id="$2"
base="${3:-main}"
branch="${4:-task/${task_id}}"
today="$(pm_today)"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a git worktree" >&2; exit 1; }
git diff --quiet || { echo "Working tree has unstaged changes; refusing to create branch" >&2; exit 1; }
git diff --cached --quiet || { echo "Working tree has staged changes; refusing to create branch" >&2; exit 1; }
git checkout "$base"
git pull --ff-only || true
git checkout -b "$branch"
pm_update_task_status "$spec_id" "$task_id" "In Development"
pm_update_all "$spec_id" "$task_id" "In Development" "$branch" "" "" "none"
pm_append_log "$task_id" "Agent Handoffs" "### $today - $task_id - branch created

- Base Branch: $base
- Task Branch: $branch"
echo "$branch"
