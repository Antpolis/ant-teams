#!/usr/bin/env bash
set -euo pipefail

# Create a dedicated issue worktree and task branch (git-only helper).
#
# Workflow state is owned by the GitHub Project board and communication
# records by the central Obsidian project folder — this script intentionally
# performs no board-status or communication-log writes.

usage() { cat <<'USAGE'
Usage:
  create_task_worktree.sh ISSUE_ID [BASE_BRANCH] [BRANCH_NAME] [WORKTREE_PATH]

Creates a dedicated git worktree and task branch for one issue.

  ISSUE_ID       GitHub issue identifier, e.g. issue-123
  BASE_BRANCH    production base branch (default: main)
  BRANCH_NAME    task branch (default: feat/<ISSUE_ID>)
  WORKTREE_PATH  worktree location (default: $ANT_TEAM_WORKTREE_ROOT/<ISSUE_ID>
                 from .github-project.env, else <repo-parent>/<repo-name>-<ISSUE_ID>)

Source ./.github-project.env first so ANT_TEAM_WORKTREE_ROOT is honored.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 1 || $# -gt 4 ]]; then usage >&2; exit 1; fi

issue_id="$1"; base="${2:-main}"; branch="${3:-feat/${issue_id}}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a git worktree" >&2; exit 1; }
git diff --quiet || { echo "Working tree has unstaged changes; refusing to create worktree" >&2; exit 1; }
git diff --cached --quiet || { echo "Working tree has staged changes; refusing to create worktree" >&2; exit 1; }

repo_root="$(git rev-parse --show-toplevel)"
repo_parent="$(dirname "$repo_root")"
repo_name="$(basename "$repo_root")"
default_worktree_root=""

# Source .github-project.env (sole project config source) in an isolated
# subshell for ANT_TEAM_WORKTREE_ROOT. A literal ~ must be expanded against
# $HOME — git does not expand tildes inside variables.
if [[ -f "$repo_root/.github-project.env" ]]; then
  default_worktree_root="$(
    # shellcheck disable=SC1090
    . "$repo_root/.github-project.env"
    printf '%s' "${ANT_TEAM_WORKTREE_ROOT:-}"
  )"
fi
default_worktree_root="${default_worktree_root/#\~/$HOME}"

if [[ -n "$default_worktree_root" ]]; then
  worktree_path_default="${default_worktree_root%/}/${issue_id}"
else
  worktree_path_default="${repo_parent}/${repo_name}-${issue_id}"
fi

worktree_path="${4:-$worktree_path_default}"

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

printf 'branch=%s\nworktree=%s\n' "$branch" "$worktree_path"
