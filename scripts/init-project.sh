#!/usr/bin/env bash
set -euo pipefail

# Source-checkout delegator: runs the initialization engine installed by
# scripts/init-company.sh at "$ANT_TEAM_SCRIPTS/init-project.sh" (canonical
# source: templates/scripts/init-project.sh, support assets in
# templates/scripts/init-project/). Invoked with `bash` so the installed
# engine's execute bits are never required.
exec bash "${ANT_TEAM_SCRIPTS:?ANT_TEAM_SCRIPTS is not set; run scripts/init-company.sh first}/init-project.sh" "$@"
