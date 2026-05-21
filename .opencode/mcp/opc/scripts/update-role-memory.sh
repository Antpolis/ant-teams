#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/update-role-memory.sh developer|qa|architect SPEC_ID TASK_ID "ENTRY"
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 4 ]]; then usage >&2; exit 1; fi

role="$1"; spec_id="$2"; task_id="$3"; entry="$4"; today="$(pm_today)"
case "$role" in developer|qa|architect) ;; *) echo "Invalid role: $role" >&2; exit 1 ;; esac
file="$(pm_doc_root)/memory/${role}-memory.md"
mkdir -p "$(dirname "$file")"
[[ -f "$file" ]] || printf '# %s Memory\n\n## Active Lessons\n' "$role" > "$file"
cat >> "$file" <<EOF

### $today - $spec_id / $task_id

- $entry
EOF
pm_append_log "$spec_id" "Role Memory Updates" "### $today - $role memory - $task_id

- Memory File: $file
- Summary: $entry
- Status: updated"
pm_update_all "$spec_id" "$task_id" "" "" "" "" ""
echo "Updated $file"
