#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/sync-company.sh [--target-dir PATH] [--force]

Copy the repository .opencode folder into target config directory,
then perform a managed sync of repository-owned skills into ~/.agents/skills.

Defaults:
  target-dir: ~/.config/opencode

Flags:
  --target-dir PATH   Override the canonical OpenCode install target.
  --force             Overwrite locally modified managed entries in ~/.agents/skills.
USAGE
}

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_root/.opencode"
target_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"

# SPEC-002 FR-12.2 / CLI-2.1: --force is passed through to sync-managed-skills.sh
# only when supplied. It does not affect the canonical OpenCode install.
FORCE=0

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
    --force)
      FORCE=1
      shift
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

# SPEC-002 FR-12.2 / INT-3.2: managed sync runs only after the canonical install
# completes. Under `set -e`, a canonical-install failure exits before reaching
# here; a managed-sync failure exits sync-company.sh with that code (CLI-2.4).
# --force is forwarded only when supplied (no --dry-run passthrough; CLI-2.3).
managed_args=()
if [[ "$FORCE" == "1" ]]; then
  managed_args+=(--force)
fi
"$script_dir/sync-managed-skills.sh" "${managed_args[@]}"
