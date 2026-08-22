#!/usr/bin/env bash
set -euo pipefail

"${ANT_TEAM_SCRIPTS:?ANT_TEAM_SCRIPTS is not set}/../skills/do-task/scripts/create_task_worktree.sh" "$@"
