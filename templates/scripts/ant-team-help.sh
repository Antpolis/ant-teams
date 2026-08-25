#!/usr/bin/env bash
#
# ant-team-help.sh — list the installed ant-team helper scripts with a stable
# one-line description for each.
#
# Lists every script under $ANT_TEAM_SCRIPTS (populated by scripts/init-company.sh,
# which installs the canonical templates/scripts/ tree to ~/.agents/scripts and
# exports ANT_TEAM_SCRIPTS in the shell rc files). Scripts without a recorded
# stable description are still listed with a generic note so new helpers stay
# visible until this table is updated.
#
# This helper deliberately does NOT source .github-project.env: it must work
# (or fail with a clear message) from any directory using only the installed
# team tooling, before any project env is loaded.
#
# Usage:
#   ant-team-help.sh [-h|--help]
#
# Exit codes:
#   0  listing succeeded
#   1  ANT_TEAM_SCRIPTS is unset or does not point to a directory
#      (scripts/init-company.sh has not run in this environment)
#
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ant-team-help.sh [-h|--help]

List the ant-team helper scripts installed by scripts/init-company.sh into
$ANT_TEAM_SCRIPTS (~/.agents/scripts) with a one-line description each.

If ANT_TEAM_SCRIPTS is unset or missing, run scripts/init-company.sh first.
USAGE
}

# Stable descriptions for the current helper scripts. Keys are the script
# basenames as installed by init-company.sh from templates/scripts/. Keep one
# line per script and keep descriptions stable — agents and docs reference
# them.
describe_script() {
  case "$1" in
    ant-team-help.sh)
      printf 'List installed team helper scripts with one-line descriptions (this script).'
      ;;
    cleanup-task-worktree.sh)
      printf 'Remove an issue worktree and its local task branch after merge or abandonment (delegates to the do-task skill helper).'
      ;;
    create-task-branch.sh)
      printf 'Create a dedicated issue worktree with its own task branch (delegates to the do-task skill helper).'
      ;;
    gh_project_helper.sh)
      printf 'Centralized entry for the GitHub Projects helper engine: issue, milestone, and project-board operations via gh.'
      ;;
    init-project.sh)
      printf 'Project initialization engine: seeds/updates .github-project.env, minimal runtime config, required skills copy, and AGENTS.md generation.'
      ;;
    record-communication.sh)
      printf 'Record or list agent communication event files in the central Obsidian project folder (no GitHub writes).'
      ;;
    validate-agents-md.sh)
      printf 'Structural validator for AGENTS.md (ARCH-003 DM-2 contract: headings, sections, Local Configuration Files, path existence).'
      ;;
    *)
      printf 'No stable description recorded yet; see the script header in the ant-teams repository.'
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

scripts_dir="${ANT_TEAM_SCRIPTS:-}"

if [[ -z "$scripts_dir" ]]; then
  echo "ANT_TEAM_SCRIPTS is not set." >&2
  echo "Team helper scripts are not installed in this environment." >&2
  echo "Run scripts/init-company.sh first (installs ~/.agents/scripts and exports ANT_TEAM_SCRIPTS)." >&2
  exit 1
fi

if [[ ! -d "$scripts_dir" ]]; then
  echo "ANT_TEAM_SCRIPTS does not point to a directory: $scripts_dir" >&2
  echo "Run scripts/init-company.sh again to reinstall the team helper scripts." >&2
  exit 1
fi

printf 'Installed team helper scripts (%s):\n\n' "$scripts_dir"

shopt -s nullglob
found=0
for script in "$scripts_dir"/*.sh; do
  found=$((found + 1))
  printf '  %-24s %s\n' "$(basename "$script")" "$(describe_script "$(basename "$script")")"
done
shopt -u nullglob

if [[ "$found" -eq 0 ]]; then
  echo "No helper scripts found under $scripts_dir." >&2
  echo "Run scripts/init-company.sh again to reinstall the team helper scripts." >&2
  exit 1
fi

exit 0
