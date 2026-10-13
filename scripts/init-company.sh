#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/init-company.sh [--target-dir PATH] [--reset] [--force]

Copy the repository .opencode configuration into the target config directory,
then sync repository-owned skills, scripts, and agent definitions. Copilot
  agents under ~/.copilot/agents are regenerated from opencode.json; stale
  .agent.md files whose agent was removed from the source are deleted. The
  managed skill sync always runs with --force: a company install is an
  operator-initiated refresh of repository-owned content, so locally modified
  managed entries are replaced from source.

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
  # Agent definitions live as OpenCode markdown files under
  # templates/opencode/agents/<id>.md (YAML frontmatter + body). They are
  # converted to Copilot .agent.md files. Existing targets are updated in
  # place — only name, description, and the body are refreshed; user-managed
  # frontmatter fields (model, mode, tools, ...) are preserved. New targets
  # get full generated frontmatter with role-based default tools.
  local agents_dir="${HOME%/}/.copilot/agents"
  local agents_source="$script_root/templates/opencode/agents"

  mkdir -p "$agents_dir"

  # Track emitted agent ids so stale managed .agent.md files (agents removed
  # from the source) can be deleted afterwards. Only ids recorded in the
  # previous manifest are eligible for deletion — user-created .agent.md
  # files are never touched.
  local emitted_dir
  emitted_dir="$(mktemp -d)"
  local manifest="$agents_dir/.managed-agents"

  local src id desc tools
  for src in "$agents_source"/*.md; do
    [[ -f "$src" ]] || continue
    id="$(basename "$src" .md)"
    # description is the first frontmatter key; take the rest of its line.
    desc="$(awk '/^---$/{c++; next} c==1 && /^description:/ {sub(/^description:[[:space:]]*/, ""); print; exit}' "$src")"
    if [[ "$id" == "reviewer" ]]; then
      tools="read, search, execute, agent, web"
    else
      tools="read, search, edit, execute, agent, web, todo"
    fi

    local target="$agents_dir/${id}.agent.md"
    local temporary="${target}.tmp-$$"
    local body
    # Body: everything after the closing frontmatter delimiter in the source.
    body="$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$src")"

    if [[ -f "$target" && "$(head -n1 "$target")" == "---" ]]; then
      # Update in place: keep all user-managed frontmatter fields (model,
      # mode, tools, ...) and only refresh name, description, and the body.
      awk -v id="$id" -v desc="$desc" '
        NR==1 && $0=="---" { print; fm=1; next }
        fm==1 {
          if ($0=="---") {
            printf "name: %s\n", id
            printf "description: %s\n", desc
            print
            exit
          }
          if ($0 ~ /^name:/ || $0 ~ /^description:/) next
          print
          next
        }
      ' "$target" > "$temporary"
      printf '%s\n' "$body" >> "$temporary"
    else
      {
        printf '%s\n' "---"
        printf 'name: %s\n' "$id"
        printf 'description: %s\n' "$desc"
        printf 'tools: [%s]\n' "$tools"
        printf '%s\n' "---"
        printf '%s\n' "$body"
      } > "$temporary"
    fi
    mv "$temporary" "$target"
    touch "$emitted_dir/${id}.agent.md"
  done

  # Orphan cleanup: remove managed .agent.md files recorded in the previous
  # manifest whose agent no longer exists in the source. User files (never
  # managed) are left untouched.
  local stale
  if [[ -f "$manifest" ]]; then
    while IFS= read -r stale; do
      [[ -n "$stale" ]] || continue
      if [[ ! -e "$emitted_dir/$stale" && -e "$agents_dir/$stale" ]]; then
        rm -f "$agents_dir/$stale"
        echo "Removed stale Copilot agent: $agents_dir/$stale"
      fi
    done < "$manifest"
  fi
  printf '%s\n' "$emitted_dir"/* 2>/dev/null | while IFS= read -r f; do
    [[ -e "$f" ]] || continue
    basename "$f"
  done | LC_ALL=C sort > "${manifest}.tmp-$$"
  mv "${manifest}.tmp-$$" "$manifest"
  rm -rf "$emitted_dir"

  echo "Synced OpenCode agents -> $agents_dir"
}

sync_copilot_agents_md() {
  # Install the repository AGENTS.md as Copilot's global custom instructions
  # so every Copilot session picks up the repo guidance.
  local repo_agents_md="$script_root/AGENTS.md"
  local target="${HOME%/}/.copilot/AGENTS.md"

  [[ -f "$repo_agents_md" ]] || {
    echo "[WARNING] No AGENTS.md found at repo root: $repo_agents_md" >&2
    return 0
  }

  mkdir -p "$(dirname "$target")"
  cp "$repo_agents_md" "$target"
  echo "Synced AGENTS.md -> $target"
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

# Install repo-local .opencode/ runtime from templates/opencode (canonical
# source). Only config files and commands are synced; skills are synced
# separately by the managed-skill sync below. Unlike the global
# ~/.config/opencode install, the repo-local .opencode/ is a pure copy — no
# provider merge, because it is generated from the canonical source.
sync_repo_opencode() {
  local local_dir="$script_root/.opencode"
  local temp_opencode
  temp_opencode="$(mktemp -d)"
  cp -R "$source_dir"/. "$temp_opencode"/
  rm -rf "$temp_opencode/skills"

  mkdir -p "$(dirname "$local_dir")"
  rm -rf "$local_dir"
  mkdir -p "$local_dir"
  cp -R "$temp_opencode"/. "$local_dir"/
  rm -rf "$temp_opencode"

  echo "Synced $source_dir -> $local_dir"
}

echo "Synced $source_dir -> $target_dir"
sync_team_scripts
sync_copilot_agents
sync_copilot_agents_md
sync_repo_opencode

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
