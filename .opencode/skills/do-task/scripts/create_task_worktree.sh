#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../../../../scripts/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  ./.opencode/skills/do-task/scripts/create_task_worktree.sh SPEC_ID TASK_ID [BASE_BRANCH] [BRANCH_NAME] [WORKTREE_PATH]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 2 || $# -gt 5 ]]; then usage >&2; exit 1; fi

spec_id="$1"; task_id="$2"; base="${3:-main}"; branch="${4:-task/${task_id}}"; today="$(pm_today)"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a git worktree" >&2; exit 1; }
git diff --quiet || { echo "Working tree has unstaged changes; refusing to create worktree" >&2; exit 1; }
git diff --cached --quiet || { echo "Working tree has staged changes; refusing to create worktree" >&2; exit 1; }

repo_root="$(git rev-parse --show-toplevel)"
repo_parent="$(dirname "$repo_root")"
repo_name="$(basename "$repo_root")"
project_config="$repo_root/.github-project.json"
default_worktree_root=""

if [[ -f "$project_config" ]]; then
  default_worktree_root="$(node -e 'const fs=require("fs"); const p=process.argv[1]; try { const v=JSON.parse(fs.readFileSync(p,"utf8")).worktreeRoot || ""; process.stdout.write(v); } catch (err) { process.exit(1); }' "$project_config" 2>/dev/null || true)"
fi

if [[ -n "$default_worktree_root" ]]; then
  worktree_path_default="${default_worktree_root%/}/${task_id}"
else
  worktree_path_default="${repo_parent}/${repo_name}-${task_id}"
fi

worktree_path="${5:-$worktree_path_default}"

git fetch origin "$base" >/dev/null 2>&1 || true
if git show-ref --verify --quiet "refs/remotes/origin/${base}"; then
  start_point="origin/${base}"
else
  start_point="$base"
fi

if git show-ref --verify --quiet "refs/heads/${branch}"; then
  git worktree add "$worktree_path" "$branch"
else
  git worktree add -b "$branch" "$worktree_path" "$start_point"
fi

pm_update_task_status "$spec_id" "$task_id" "In Development"
pm_update_all "$spec_id" "$task_id" "In Development" "$branch" "" "" "none"
pm_append_log "$spec_id" "Branch Lifecycle" "### $today - $task_id - worktree created

- Base Branch: $base
- Task Branch: $branch
- Worktree Path: $worktree_path"
printf 'branch=%s\nworktree=%s\n' "$branch" "$worktree_path"
