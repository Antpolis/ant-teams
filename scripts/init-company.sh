#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/init-company.sh [--target-dir PATH] [--reset] [--force]

Copy the repository .opencode configuration into the target config directory,
then sync repository-owned skills, scripts, and agent definitions. The managed
skill sync always runs with --force: a company install is an operator-initiated
refresh of repository-owned content, so locally modified managed entries are
replaced from source.

Defaults:
  target-dir: ~/.config/opencode
  Copilot agents: ~/.copilot/agents
  Team scripts: ~/.agents/scripts

Flags:
  --target-dir PATH   Override the canonical OpenCode install target.
  --reset             Before reinstalling, move the installed trees
                      (<target-dir>, ~/.agents/skills, ~/.agents/scripts)
                      aside to <path>.bak.<UTC timestamp> directories and
                      reinstall from scratch.
  --force             Deprecated no-op: the managed sync always runs with
                      --force now. (Standalone scripts/sync-managed-skills.sh
                      keeps its non-destructive default.)
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

# --reset support (2026-08-25 founder-direct tech-lead plan): move the three
# installed runtime trees aside to timestamped .bak.<UTC> directories before a
# from-scratch reinstall. Exactly the installed trees move — the canonical
# OpenCode target, ~/.agents/skills, ~/.agents/scripts — never ~/.agents
# itself, ~/.copilot, or anything else. One timestamp per run keeps the three
# backups correlated; absent trees are skipped.
reset_installed_trees() {
  local ts dir dest
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  for dir in "$target_dir" "$agents_dir/skills" "$team_scripts_dir"; do
    if [[ -e "$dir" ]]; then
      dest="$dir.bak.$ts"
      if [[ -e "$dest" ]]; then
        echo "[ERROR] reset backup destination already exists: $dest" >&2
        exit 1
      fi
      mv "$dir" "$dest"
      echo "Reset: moved $dir -> $dest"
    fi
  done
}

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

# --reset moves the installed trees aside (see reset_installed_trees); the
# managed sync below always runs with --force (2026-08-25 plan).
RESET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-dir)
      target_dir="${2:-}"
      shift 2
      ;;
    --force)
      # Deprecated no-op (2026-08-25 founder-direct tech-lead plan): the
      # managed sync at the end of this script always passes --force now, so
      # the flag no longer changes anything. Accepted for compatibility.
      echo "[WARNING] --force is deprecated and has no effect: init-company.sh always syncs managed skills with --force. (Standalone scripts/sync-managed-skills.sh keeps its non-destructive default.)" >&2
      shift
      ;;
    --reset)
      RESET=1
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

# --reset: back up the installed trees BEFORE any reinstall step touches them.
# Afterwards the canonical install and the managed sync below behave exactly as
# on a fresh machine (no provider-merge source, no prior managed manifest).
if [[ "$RESET" == "1" ]]; then
  reset_installed_trees
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

# SPEC-002 FR-12.2 / INT-3.2 (amended by the 2026-08-25 founder-direct
# tech-lead plan): managed sync runs only after the canonical install
# completes, and ALWAYS with --force — a company install is an operator-
# initiated refresh of repository-owned content, so locally modified managed
# entries are replaced from source. Under `set -e`, a canonical-install
# failure exits before reaching here; a managed-sync failure exits
# init-company.sh with that code (CLI-2.4). Standalone
# scripts/sync-managed-skills.sh keeps its non-destructive default; there is
# still no --dry-run passthrough (CLI-2.3).
"$script_dir/sync-managed-skills.sh" --force
