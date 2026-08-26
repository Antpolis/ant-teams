#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/init-company.sh [--target-dir PATH] [--force]

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
source_dir="$script_root/templates/opencode"
target_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
agents_dir="${HOME%/}/.agents"
team_scripts_dir="$agents_dir/scripts"

sync_team_scripts() {
  rm -rf "$team_scripts_dir"
  mkdir -p "$agents_dir"
  cp -R "$script_root/templates/scripts" "$team_scripts_dir"
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

  # Deep-merge provider objects using jq. Arrays are preserved from installed;
  # nested objects are merged recursively. null * obj is handled by // fallback.
  local merged
  merged=$(jq -n --slurpfile src "$source_config" --slurpfile inst "$installed_config" '
    ($src[0].provider // {}) as $sp |
    ($inst[0].provider // {}) as $ip |
    if ($sp | length) == 0 and ($ip | length) == 0 then
      $src[0]
    elif ($sp | length) == 0 then
      $src[0] + {provider: $ip}
    elif ($ip | length) == 0 then
      $src[0]
    else
      $src[0] + {provider: ($sp * $ip |
        to_entries | map(
          if (.value | type) == "array" then .value = $ip[.key] // .value
          elif (.value | type) == "object" and ($ip[.key] | type) == "object" then
            .value = (.value * $ip[.key])
          else .
          end
        ) | from_entries
      )}
    end
  ' 2>/dev/null) || return 0

  printf '%s\n' "$merged" > "$source_config"
}

sync_copilot_agents() {
  local source_config="$1"
  local agents_dir="${HOME%/}/.copilot/agents"

  mkdir -p "$agents_dir"

  # Extract agent definitions from opencode.json and write .agent.md files.
  # Behavioral parity with the prior Node implementation:
  #   - Only agents whose prompt is a JSON string are emitted (objects, numbers,
  #     booleans, arrays, and null are silently skipped).
  #   - Prompts are trimmed of leading/trailing whitespace (matches .trim()).
  #   - name and description are JSON-quoted (@json) so YAML-significant
  #     characters (colons, quotes, newlines) cannot corrupt the frontmatter.
  jq -r '
    .agent // {} | to_entries[] |
    select(.value.prompt | type == "string") |
    {
      key: .key,
      description: (.value.description // "Use when acting as the \(.key) role."),
      prompt: (.value.prompt | gsub("^\\s+|\\s+$"; ""))
    } | @json
  ' "$source_config" 2>/dev/null | while IFS= read -r agent_json; do
    local id desc prompt tools
    id=$(printf '%s' "$agent_json" | jq -r '.key')
    desc=$(printf '%s' "$agent_json" | jq -r '.description | @json')
    prompt=$(printf '%s' "$agent_json" | jq -r '.prompt')

    if [[ "$id" == "reviewer" ]]; then
      tools="read, search, execute, agent, web"
    else
      tools="read, search, edit, execute, agent, web, todo"
    fi

    local target="$agents_dir/${id}.agent.md"
    local temporary="${target}.tmp-$$"
    local name_json
    name_json=$(printf '%s' "$agent_json" | jq -r '.key | @json')
    {
      printf '%s\n' "---"
      printf 'name: %s\n' "$name_json"
      printf 'description: %s\n' "$desc"
      printf 'tools: [%s]\n' "$tools"
      printf '%s\n' "---"
      printf '%s\n' "$prompt"
    } > "$temporary"
    mv "$temporary" "$target"
  done

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
# here; a managed-sync failure exits init-company.sh with that code (CLI-2.4).
# --force is forwarded only when supplied (no --dry-run passthrough; CLI-2.3).
if [[ "$FORCE" == "1" ]]; then
  "$script_dir/sync-managed-skills.sh" --force
else
  "$script_dir/sync-managed-skills.sh"
fi
