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
  scripts/next-id.sh FP
  scripts/next-id.sh BLOCK
  scripts/next-id.sh DEFER
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -ne 1 ]]; then usage >&2; exit 1; fi

prefix="$1"
pm_next_id "$prefix"
