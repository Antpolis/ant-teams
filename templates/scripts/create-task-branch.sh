#!/usr/bin/env bash
set -euo pipefail

# Thin pass-through wrapper for the do-tasks issue-worktree helper. The engine
# lives with the do-tasks skill in the managed mirror; ANT_TEAM_SCRIPTS is
# installed and configured by scripts/init-company.sh. The engine is invoked
# with `bash` so the managed skill mirror's execute bits are never required.
exec bash "${ANT_TEAM_SCRIPTS:?ANT_TEAM_SCRIPTS is not set; run scripts/init-company.sh first}/../skills/do-tasks/scripts/create_task_worktree.sh" "$@"
