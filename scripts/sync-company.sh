#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/sync-company.sh [--target-dir PATH] [--force]

Copy the repository .opencode configuration into the target config directory,
then sync repository-owned skills, scripts, and agent definitions.

Defaults:
  target-dir: ~/.config/opencode
  Copilot agents: ~/.copilot/agents
  Team scripts: ~/.agents/scripts

Flags:
  --target-dir PATH   Override the canonical OpenCode install target.
  --force             Overwrite locally modified managed entries in ~/.agents/skills.
USAGE
}

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_root/.opencode"
target_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
agents_dir="${HOME%/}/.agents"
team_scripts_dir="$agents_dir/scripts"

sync_team_scripts() {
  rm -rf "$team_scripts_dir"
  mkdir -p "$agents_dir"
  cp -R "$script_root/scripts" "$team_scripts_dir"
  chmod 0755 "$team_scripts_dir"/*.sh 2>/dev/null || true

  local env_line='export ANT_TEAM_SCRIPTS="$HOME/.agents/scripts"'
  local rc_file
  for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    touch "$rc_file"
    if ! grep -Fqx "$env_line" "$rc_file"; then
      printf '\n%s\n' "$env_line" >> "$rc_file"
    fi
  done

  echo "Synced team scripts -> $team_scripts_dir"
}

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

sync_copilot_agents() {
  local source_config="$1"
  local agents_dir="${HOME%/}/.copilot/agents"

  mkdir -p "$agents_dir"

  SOURCE_CONFIG="$source_config" COPILOT_AGENTS_DIR="$agents_dir" node <<'NODE'
const fs = require("fs");
const path = require("path");

const sourceConfig = JSON.parse(fs.readFileSync(process.env.SOURCE_CONFIG, "utf8"));
const agents = sourceConfig.agent || {};
const agentsDir = process.env.COPILOT_AGENTS_DIR;

for (const [id, agent] of Object.entries(agents)) {
  if (!agent || typeof agent !== "object" || typeof agent.prompt !== "string") continue;

  const tools = id === "reviewer"
    ? ["read", "search", "execute", "agent", "web"]
    : ["read", "search", "edit", "execute", "agent", "web", "todo"];
  const content = [
    "---",
    `name: ${JSON.stringify(id)}`,
    `description: ${JSON.stringify(agent.description || `Use when acting as the ${id} role.`)}`,
    `tools: [${tools.join(", ")}]`,
    "---",
    "",
    agent.prompt.trim(),
    "",
  ].join("\n");
  const target = path.join(agentsDir, `${id}.agent.md`);
  const temporary = `${target}.tmp-${process.pid}`;
  fs.writeFileSync(temporary, content, "utf8");
  fs.renameSync(temporary, target);
}
NODE

  echo "Synced OpenCode agents -> $agents_dir"
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
rm -rf "$temp_dir/skills"
merge_provider_config "$temp_dir/opencode.json" "$existing_config"

mkdir -p "$(dirname "$target_dir")"
rm -rf "$target_dir"
mkdir -p "$target_dir"
cp -R "$temp_dir"/. "$target_dir"/

echo "Synced $source_dir -> $target_dir"
sync_team_scripts
sync_copilot_agents "$source_dir/opencode.json"

# SPEC-002 FR-12.2 / INT-3.2: managed sync runs only after the canonical install
# completes. Under `set -e`, a canonical-install failure exits before reaching
# here; a managed-sync failure exits sync-company.sh with that code (CLI-2.4).
# --force is forwarded only when supplied (no --dry-run passthrough; CLI-2.3).
if [[ "$FORCE" == "1" ]]; then
  "$script_dir/sync-managed-skills.sh" --force
else
  "$script_dir/sync-managed-skills.sh"
fi
