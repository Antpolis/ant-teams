#!/usr/bin/env bash
set -euo pipefail

# Thin pass-through wrapper (centralized entry) for the bundled GitHub
# Projects helper:
#   "$ANT_TEAM_SCRIPTS/gh_project_helper.sh" [command] [args]
# The engine lives with the github-issues-projects-cli skill in the managed
# mirror; ANT_TEAM_SCRIPTS is installed and configured by
# scripts/init-company.sh. The engine is invoked with `bash` so the managed
# skill mirror's execute bits are never required (managed sync may tighten
# updated files to mode 0644).
exec bash "${ANT_TEAM_SCRIPTS:?ANT_TEAM_SCRIPTS is not set; run scripts/init-company.sh first}/../skills/github-issues-projects-cli/scripts/gh_project_helper.sh" "$@"
