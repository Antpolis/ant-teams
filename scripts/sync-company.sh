#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/sync-company.sh [--target-dir PATH]

Copy the repository .opencode folder into target config directory.

Defaults:
  target-dir: ~/.config/opencode

Example:
  scripts/sync-company.sh
  scripts/sync-company.sh --target-dir ~/.config/opencode
USAGE
}

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$script_root/.opencode"
target_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)
      target_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$source_dir" ]]; then
  echo "Missing source directory: $source_dir" >&2
  exit 1
fi

mkdir -p "$target_dir"
rm -rf "$target_dir"
mkdir -p "$target_dir"
cp -R "$source_dir"/. "$target_dir"/

mcp_dir="$target_dir/mcp/opc"
if [[ -f "$mcp_dir/package.json" ]]; then
  npm --prefix "$mcp_dir" install --omit=dev --silent
fi

echo "Synced $source_dir -> $target_dir"
