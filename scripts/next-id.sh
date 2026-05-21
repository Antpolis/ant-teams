#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/next-id.sh PREFIX

Examples:
  scripts/next-id.sh SPEC
  scripts/next-id.sh TASK
  scripts/next-id.sh BLOCK
  scripts/next-id.sh DEFER
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 1 ]]; then usage >&2; exit 1; fi

prefix="$1"
doc_root="$(pm_doc_root)"
max="0"

while IFS= read -r match; do
  number="${match##*-}"
  if [[ "$number" =~ ^[0-9]+$ ]] && (( 10#$number > max )); then
    max=$((10#$number))
  fi
done < <(grep -RhoE "${prefix}-[0-9]{3,}" "$doc_root" 2>/dev/null || true)

printf '%s-%03d\n' "$prefix" $((max + 1))
