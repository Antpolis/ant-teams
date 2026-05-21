#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() { cat <<'USAGE'
Usage:
  scripts/read-role-memory.sh developer|qa|architect
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 1 ]]; then usage >&2; exit 1; fi

role="$1"
case "$role" in developer|qa|architect) ;; *) echo "Invalid role: $role" >&2; exit 1 ;; esac
file="$(pm_doc_root)/memory/${role}-memory.md"
[[ -f "$file" ]] || { echo "Role memory not found: $file" >&2; exit 1; }
sed -n '1,$p' "$file"
