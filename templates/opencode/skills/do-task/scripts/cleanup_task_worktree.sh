#!/usr/bin/env bash
set -euo pipefail

# Remove a merged issue worktree and its local task branch (git-only helper).
#
# Workflow state is owned by the GitHub Project board and communication
# records by the central Obsidian project folder — this script intentionally
# performs no board-status or communication-log writes.

usage() { cat <<'USAGE'
Usage:
  cleanup_task_worktree.sh ISSUE_ID [BASE_BRANCH] [BRANCH_NAME] [WORKTREE_PATH]

Removes the issue worktree and local task branch after the branch is merged
into the base branch. Refuses to delete anything that is not fully merged.

  ISSUE_ID       GitHub issue identifier used to resolve defaults, e.g. issue-123
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
  merge_base="origin/${base}"
else
  merge_base="$base"
fi

git show-ref --verify --quiet "refs/heads/${branch}" || {
  echo "Branch ${branch} does not exist locally; nothing to clean up" >&2
  exit 1
}

git merge-base --is-ancestor "$branch" "$merge_base" || {
  echo "Branch ${branch} is not merged into ${merge_base}; refusing cleanup" >&2
  exit 1
}

if git worktree list --porcelain | grep -Fqx "worktree ${worktree_path}"; then
  git worktree remove "$worktree_path"
fi

git branch -d "$branch"

printf 'cleaned branch=%s\ncleaned worktree=%s\n' "$branch" "$worktree_path"
