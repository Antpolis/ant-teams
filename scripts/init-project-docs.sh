#!/usr/bin/env bash
set -euo pipefail

# Thin pass-through wrapper (CLI-1). Canonical invocation after sync-company:
#   "$ANT_TEAM_SCRIPTS/init-project-docs.sh" [options]
# The engine lives with the project-initialization skill; ANT_TEAM_SCRIPTS is
# installed and configured by scripts/sync-company.sh.
exec "${ANT_TEAM_SCRIPTS:?ANT_TEAM_SCRIPTS is not set; run scripts/sync-company.sh first}/../skills/project-initialization/scripts/init_project_docs.sh" "$@"
