#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/record-release.sh RELEASE_ID SPEC_ID TASK_ID "VERSION" "EVIDENCE"
USAGE
}
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 5 ]]; then usage >&2; exit 1; fi
release_id="$1"; spec_id="$2"; task_id="$3"; version="$4"; evidence="$5"; today="$(pm_today)"
release_file="$(pm_doc_root)/proj-management/releases.md"
mkdir -p "$(dirname "$release_file")"
if [[ ! -f "$release_file" ]]; then
  cat > "$release_file" <<'EOF'
# Releases

| Release | Spec | Task | Version | Evidence | Date |
|---|---|---|---|---|---|
EOF
fi
printf '| %s | %s | %s | %s | %s | %s |\n' "$release_id" "$spec_id" "$task_id" "$version" "$evidence" "$today" >> "$release_file"
pm_append_log "$spec_id" "Release Records" "### $today - $release_id - $task_id

- Version: $version
- Evidence: $evidence"
pm_update_all "$spec_id" "$task_id" "Done" "" "" "" "none"
echo "Recorded release $release_id"
