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

merge_provider_config() {
  local source_config="$1"
  local installed_config="$2"

  [[ -f "$source_config" && -f "$installed_config" ]] || return 0

  node - "$source_config" "$installed_config" <<'NODE'
const fs = require("fs");

const [sourcePath, installedPath] = process.argv.slice(2);
const source = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
const installed = JSON.parse(fs.readFileSync(installedPath, "utf8"));

const sourceProvider = source.provider;
const installedProvider = installed.provider;

if (!sourceProvider && !installedProvider) {
  process.exit(0);
}

if (!sourceProvider) {
  source.provider = installedProvider;
} else if (installedProvider) {
  source.provider = mergeObjects(sourceProvider, installedProvider);
}

fs.writeFileSync(sourcePath, JSON.stringify(source, null, 2) + "\n");

function mergeObjects(sourceValue, installedValue) {
  if (Array.isArray(sourceValue) || Array.isArray(installedValue)) {
    return installedValue;
  }

  if (!isPlainObject(sourceValue) || !isPlainObject(installedValue)) {
    return installedValue;
  }

  const merged = { ...sourceValue };
  for (const [key, installedChild] of Object.entries(installedValue)) {
    if (!(key in sourceValue)) {
      merged[key] = installedChild;
      continue;
    }
    merged[key] = mergeObjects(sourceValue[key], installedChild);
  }
  return merged;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
NODE
}

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

existing_config="$target_dir/opencode.json"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

cp -R "$source_dir"/. "$temp_dir"/
merge_provider_config "$temp_dir/opencode.json" "$existing_config"

mkdir -p "$(dirname "$target_dir")"
rm -rf "$target_dir"
mkdir -p "$target_dir"
cp -R "$temp_dir"/. "$target_dir"/

echo "Synced $source_dir -> $target_dir"
