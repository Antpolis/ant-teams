#!/usr/bin/env bash
#
# init_project_docs.sh — project-local initialization entrypoint (SPEC-001).
#
# T2 scope (issue #3): CLI flag expansion, env-var resolution, TTY-based mode
# detection, and validation per CLI-2 / FR-4 / ERR-4. The actual AGENTS.md
# generation (T3 / issue #4), .github-project.json schema extension (T5 /
# issue #6), and OBS-2 dry-run + idempotency overhaul (T6 / issue #7) consume
# the `opt_*` variables resolved below. T2's responsibility stops at parsing,
# resolution, and validation — the existing skills-copy / config / docs flow
# is unchanged.
#
set -euo pipefail

# Bumped from 0.1.0 → 0.2.0 for the T2 CLI expansion. AGENTS.md generation
# (T3) will stamp this into the `initMeta.version` field per ARCH-003 / DM-1.3.
readonly INIT_PROJECT_VERSION="0.2.0"

# CLI-2 / FR-4.1 --repo-role enum (per issue guardrails + ARCH-003 schema).
readonly REPO_ROLE_VALID_VALUES="service library infra monorepo-root tool docs other"

usage() {
  cat <<'USAGE'
Usage:
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh [options]

Copy the company docs into a project repo and create the local workflow-state
folder structure. T2 (issue #3) adds interactive/noninteractive mode selection,
env-var resolution, and full CLI-2 flag surface. AGENTS.md generation (T3),
.github-project.json extension (T5), and dry-run/idempotency (T6) are wired
to the same flags and ship in later issues.

Mode (CLI-2.2):
  --interactive       Force interactive mode (prompts for AGENTS.md shaping).
  --noninteractive    Force noninteractive mode. Requires --name,
                      --github-owner, --github-project-number (or their
                      INIT_PROJECT_* env equivalents). Missing values exit 1
                      per ERR-4.1.
  (default)           If stdout is a TTY → interactive; otherwise noninteractive.

Repository identity (FR-4.1):
  --name NAME                 Repo name (default: detected from --project-dir).
  --description TEXT          One-sentence repo purpose.
  --repo-role ROLE            Enum: service | library | infra | monorepo-root |
                              tool | docs | other.
  --related-repos TRIPLES     Comma-separated name:url:relationship triples.
                              Stored as-is; never fetched (SEC-1.3).

GitHub Project (FR-4.1):
  --github-owner OWNER        GitHub owner for .github-project.json.
  --github-project-number N   GitHub Project number.

AGENTS.md shaping inputs (FR-4.1):
  --conventions TEXT|@FILE    Working conventions (multiline or @/path/to/file).
  --commands TEXT|@FILE       Build/test/run commands (multiline or @/path/to/file).
  --scratch-dir PATH          Scratch/log dir (default: ./tmp/).

Behavior modifiers (CLI-2):
  --force                     Overwrite existing AGENTS.md / re-copy skills.
                              (Full effect ships with T3/T6; parsed by T2.)
  --merge                     Merge new content instead of overwriting.
                              Default: interactive=on, noninteractive=off.
  --migrate-agent-md          Migrate legacy agent.md content (noninteractive).
  --skip-inspection           Skip repository inspection; use only provided
                              inputs. (FR-2 / CLI-2.3.)
  --dry-run                   Resolve and validate flags but suppress writes.
                              (Full OBS-2 suppression ships with T6; parsed by T2.)

Pre-existing flags (preserved verbatim per CLI-1):
  --project-dir PATH          Target project directory (default: $PWD).
  --docs-root PATH            Docs root inside the project (default: docs).
  --worktree-root PATH        Issue worktree root (default:
                              ~/Projects/worktree/<repo-name>).
  -h, --help                  Show this help and exit.

Environment variables (CLI-2.1): every flag has an INIT_PROJECT_* equivalent
(uppercase, dashes → underscores). Resolution order is default < env < CLI
flag, so explicit flags always win.

Examples:
  # TTY default → interactive
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh

  # Noninteractive, fully specified (AC-T2-002)
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh \
      --noninteractive \
      --name my-service --github-owner antpolis --github-project-number 9

  # Env var provides default; CLI flag overrides (AC-T2-004)
  INIT_PROJECT_GITHUB_OWNER=antpolis \
      ./.opencode/skills/project-initialization/scripts/init_project_docs.sh \
      --noninteractive --github-owner override \
      --name t --github-project-number 1
USAGE
}

expand_path() {
  local path="$1"
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${path#~/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

# --- T2 helpers (CLI-2 / FR-4 / ERR-4) ---------------------------------------
# These functions implement parsing, env-var resolution, mode detection, and
# validation only. The downstream AGENTS.md / config / dry-run behaviors that
# hang off the same `opt_*` variables ship with T3/T5/T6 (issues #4/#6/#7).

# validate_repo_role ROLE — exit 1 if ROLE is not in the CLI-2 enum
# (issue guardrails + ARCH-003 schema). Empty input is "not provided" and
# passes; noninteractive required-flag accounting is handled separately.
validate_repo_role() {
  local role="$1"
  if [[ -z "$role" ]]; then
    return 0
  fi
  if [[ " $REPO_ROLE_VALID_VALUES " != *" $role "* ]]; then
    echo "[error] Invalid --repo-role value: '$role'" >&2
    echo "[error] Valid values: $(printf '%s, ' $REPO_ROLE_VALID_VALUES | sed 's/, $//')" >&2
    echo "[error] Or set INIT_PROJECT_ROLE to one of those values." >&2
    return 1
  fi
  return 0
}

# validate_related_repos TRIPLES — exit 1 if TRIPLES is not a comma-separated
# list of `name:url:relationship` triples. URLs may themselves contain colons
# (e.g. https://...), so we only require at least two colons per triple.
# Stored as-is per SEC-1.3; never fetched or resolved.
validate_related_repos() {
  local raw="$1"
  if [[ -z "$raw" ]]; then
    return 0
  fi
  local -a triples=()
  local IFS=','
  read -ra triples <<< "$raw"
  local triple colons
  for triple in "${triples[@]}"; do
    # Skip wholly-empty entries (e.g. trailing comma) — those are not invalid,
    # just ignorable. A non-empty entry must look like name:url:relationship.
    [[ -z "${triple// }" ]] && continue
    colons="${triple//[^:]}"
    if [[ ${#colons} -lt 2 ]]; then
      echo "[error] Invalid --related-repos entry: '$triple'" >&2
      echo "[error] Expected 'name:url:relationship' (comma-separated triples)." >&2
      echo "[error] Stored as-is; never fetched/resolved (SEC-1.3)." >&2
      return 1
    fi
  done
  return 0
}

# resolve_at_value RAW FLAG_NAME — if RAW starts with '@', replace it with the
# contents of the referenced file; otherwise return RAW unchanged. Used for
# --commands and --conventions per issue guardrails. File-not-found is a
# hard error (exit 1) — silent fallback would mask operator intent.
resolve_at_value() {
  local raw="$1" flag="$2"
  if [[ "$raw" == @* ]]; then
    local fp="${raw#@}"
    if [[ ! -f "$fp" ]]; then
      echo "[error] --$flag: file not found: $fp" >&2
      return 1
    fi
    cat "$fp"
  else
    printf '%s' "$raw"
  fi
}

# die_missing_noninteractive_flags MISSING... — print the ERR-4.1 missing-flag
# block to stderr and exit 1. Called only after mode is resolved noninteractive
# and at least one required value is empty.
die_missing_noninteractive_flags() {
  local -a missing=("$@")
  echo "[error] Noninteractive mode requires: --name, --github-owner, --github-project-number" >&2
  local m
  for m in "${missing[@]}"; do
    echo "[error] Missing: $m" >&2
  done
  echo "[error] Run interactively (--interactive) or supply the values via INIT_PROJECT_* env vars." >&2
  exit 1
}

ensure_opencode_config() {
  local project_dir="$1"
  local worktree_root="$2"
  local external_pattern="${worktree_root%/}/**"
  local config_path=""

  if [[ -f "$project_dir/opencode.jsonc" ]]; then
    config_path="$project_dir/opencode.jsonc"
  elif [[ -f "$project_dir/opencode.json" ]]; then
    config_path="$project_dir/opencode.json"
  else
    config_path="$project_dir/opencode.jsonc"
    cat > "$config_path" <<'EOF'
{
  "permission": {
    "external_directory": {}
  }
}
EOF
    echo "Created repo config at $config_path"
  fi

  node - "$config_path" "$external_pattern" <<'NODE'
const fs = require("fs");

const [configPath, externalPattern] = process.argv.slice(2);
const raw = fs.readFileSync(configPath, "utf8");
const stripped = stripJsonComments(raw);

let parsed;
try {
  parsed = JSON.parse(removeTrailingCommas(stripped));
} catch (error) {
  console.error(`Failed to parse ${configPath}: ${error.message}`);
  process.exit(1);
}

if (!parsed.permission || typeof parsed.permission !== "object" || Array.isArray(parsed.permission)) {
  parsed.permission = {};
}
if (!parsed.permission.external_directory || typeof parsed.permission.external_directory !== "object" || Array.isArray(parsed.permission.external_directory)) {
  parsed.permission.external_directory = {};
}

if (parsed.permission.external_directory[externalPattern] === "allow") {
  process.exit(0);
}

parsed.permission.external_directory[externalPattern] = "allow";
fs.writeFileSync(configPath, JSON.stringify(parsed, null, 2) + "\n");

function stripJsonComments(input) {
  let output = "";
  let inString = false;
  let stringChar = "";
  let escaping = false;

  for (let i = 0; i < input.length; i += 1) {
    const char = input[i];
    const next = input[i + 1];

    if (inString) {
      output += char;
      if (escaping) {
        escaping = false;
      } else if (char === "\\") {
        escaping = true;
      } else if (char === stringChar) {
        inString = false;
        stringChar = "";
      }
      continue;
    }

    if (char === '"' || char === "'") {
      inString = true;
      stringChar = char;
      output += char;
      continue;
    }

    if (char === "/" && next === "/") {
      while (i < input.length && input[i] !== "\n") i += 1;
      output += "\n";
      continue;
    }

    if (char === "/" && next === "*") {
      i += 2;
      while (i < input.length && !(input[i] === "*" && input[i + 1] === "/")) i += 1;
      i += 1;
      continue;
    }

    output += char;
  }

  return output;
}

function removeTrailingCommas(input) {
  return input.replace(/,\s*([}\]])/g, "$1");
}
NODE

  echo "Ensured external directory permission in $config_path"
}

# FR-7.4 / AC-T4-006: ensure `.opencode/.gitignore` exists with a `node_modules`
# entry so generated dependencies are never committed accidentally. Existing
# entries are preserved verbatim; only the missing `node_modules` line is added.
ensure_opencode_gitignore() {
  local opencode_dir="$1"
  local gitignore_path="$opencode_dir/.gitignore"
  local required_entry="node_modules"

  mkdir -p "$opencode_dir"

  if [[ ! -f "$gitignore_path" ]]; then
    printf '%s\n' "$required_entry" > "$gitignore_path"
    echo "[writing] .opencode/.gitignore"
    return 0
  fi

  if ! grep -Fxq "$required_entry" "$gitignore_path" 2>/dev/null; then
    printf '%s\n' "$required_entry" >> "$gitignore_path"
    echo "[writing] .opencode/.gitignore (node_modules entry added)"
  fi
}

# FR-7.1 / FR-7.2 / FR-7.3 / SEC-3.2 / ARCH-003 guarantee 4: copy the three
# required script-bearing skills (github-issues-projects-cli, do-task,
# project-initialization) from the source repo into the project-local
# `.opencode/skills/` directory. Copy is a per-file merge: every regular source
# file is copied when absent at target and preserved when already present (this
# is what protects project-customized SKILL.md files). No other skill is ever
# copied.
#
# Execute-bit policy (smallest robust approach): the source repository owns the
# execute bit for every shell script under `.opencode/skills/*/scripts/`, and
# `cp -p` preserves it into the target. This satisfies ARCH-003 guarantee 4
# ("Shell scripts under `scripts/` have execute permission") at the source so
# SEC-3.2's "no explicit `chmod` call is required" holds verbatim, and avoids a
# post-copy `chmod` that would violate SEC-3.1 ("must not set explicit
# permissions beyond what `mkdir -p` and `cp` provide by default"). Tests in
# `tests/test_skills_copy.js` assert the source invariant AND the target
# outcome for every required shell script so a source-mode regression cannot
# silently ship a non-executable script into a fresh init.
copy_required_skills() {
  local project_dir="$1"
  local repo_root="$2"
  local source_skills_dir="$repo_root/.opencode/skills"
  local target_skills_dir="$project_dir/.opencode/skills"
  local -a required_skills=(
    "github-issues-projects-cli"
    "do-task"
    "project-initialization"
  )
  local -a excluded_skills=(
    "skill-creator"
    "webapp-testing"
    "doc-coauthoring"
    "frontend-design"
  )

  mkdir -p "$target_skills_dir"
  ensure_opencode_gitignore "$project_dir/.opencode"

  local total_copied=0
  local total_merged=0

  for skill_name in "${required_skills[@]}"; do
    local src_skill_dir="$source_skills_dir/$skill_name"
    local tgt_skill_dir="$target_skills_dir/$skill_name"

    if [[ ! -d "$src_skill_dir" ]]; then
      echo "[warning] Required skill source not found: $src_skill_dir" >&2
      continue
    fi

    mkdir -p "$tgt_skill_dir"

    while IFS= read -r -d '' src_file; do
      local rel="${src_file#"$src_skill_dir"/}"
      local tgt_file="$tgt_skill_dir/$rel"

      if [[ -e "$tgt_file" ]]; then
        # FR-7.3: merge, do not overwrite. Protects customized SKILL.md and
        # any other project-local override.
        total_merged=$((total_merged + 1))
        continue
      fi

      mkdir -p "$(dirname "$tgt_file")"
      # SEC-3.2: `cp -p` preserves the source execute bit.
      cp -p "$src_file" "$tgt_file"
      echo "[writing] .opencode/skills/$skill_name/$rel"
      total_copied=$((total_copied + 1))
    done < <(find "$src_skill_dir" -type f -print0)
  done

  # FR-7.2: defensive check that no excluded skill directory is present at
  # target. We never write them; this only catches pre-existing stray dirs
  # that would otherwise masquerade as initializer output.
  for excluded in "${excluded_skills[@]}"; do
    if [[ -d "$target_skills_dir/$excluded" ]]; then
      echo "[warning] Excluded skill already present in target: .opencode/skills/$excluded" >&2
    fi
  done

  echo "[writing] .opencode/skills/ (${#required_skills[@]} required skills, $total_copied copied, $total_merged merged)"
}

ensure_github_project_config() {
  local project_dir="$1"
  local worktree_root="$2"
  local config_path="$project_dir/.github-project.json"

  if [[ ! -f "$config_path" ]]; then
    cat > "$config_path" <<EOF
{
  "owner": "your-github-owner",
  "owner_type": "org",
  "repo": "your-github-owner/your-repo",
  "project": {
    "number": 1,
    "id": "PVT_kwDOEXAMPLE"
  },
  "fields": {
    "status": "PVTSSF_EXAMPLE"
  },
  "status_options": {
    "todo": "todo-option-id",
    "in-progress": "in-progress-option-id",
    "in-review": "in-review-option-id",
    "done": "done-option-id"
  },
  "worktreeRoot": "$worktree_root"
}
EOF
    echo "Created .github-project.json"
    return 0
  fi

  node - "$config_path" "$worktree_root" <<'NODE'
const fs = require("fs");

const [configPath, worktreeRoot] = process.argv.slice(2);
const parsed = JSON.parse(fs.readFileSync(configPath, "utf8"));

if (!parsed.worktreeRoot) {
  parsed.worktreeRoot = worktreeRoot;
  fs.writeFileSync(configPath, JSON.stringify(parsed, null, 2) + "\n");
}
NODE

  echo "Ensured worktreeRoot in .github-project.json"
}

skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$skill_root/../../.." && pwd)"
project_dir="$(pwd)"
docs_root="docs"
worktree_root=""

# --- Phase 1: env-var resolution (CLI-2.1: default < env < CLI flag) ---------
# Pre-existing flags (CLI-1) are also env-overridable per FR-4.1. CLI flags
# parsed in Phase 2 always win over these values.
docs_root="${INIT_PROJECT_DOCS_ROOT:-$docs_root}"
worktree_root="${INIT_PROJECT_WORKTREE_ROOT:-$worktree_root}"

# New T2 string flags
opt_name="${INIT_PROJECT_NAME:-}"
opt_description="${INIT_PROJECT_DESCRIPTION:-}"
opt_repo_role="${INIT_PROJECT_ROLE:-}"
opt_related_repos="${INIT_PROJECT_RELATED_REPOS:-}"
opt_github_owner="${INIT_PROJECT_GITHUB_OWNER:-}"
opt_github_project_number="${INIT_PROJECT_GITHUB_PROJECT_NUMBER:-}"
opt_conventions="${INIT_PROJECT_CONVENTIONS:-}"
opt_commands="${INIT_PROJECT_COMMANDS:-}"
opt_scratch_dir="${INIT_PROJECT_SCRATCH_DIR:-}"

# New T2 boolean flags (0/1; empty / "0" / absent = off). Normalize absent → 0.
opt_force="${INIT_PROJECT_FORCE:-0}"
opt_migrate_agent_md="${INIT_PROJECT_MIGRATE_AGENT_MD:-0}"
opt_skip_inspection="${INIT_PROJECT_SKIP_INSPECTION:-0}"
opt_dry_run="${INIT_PROJECT_DRY_RUN:-0}"

# --merge has a mode-dependent default (interactive=on, noninteractive=off per
# CLI-2). Defer defaulting until after mode is resolved; only env vars set it
# here so empty truly means "unset".
opt_merge="${INIT_PROJECT_MERGE:-}"

# Mode env vars (mutually exclusive; CLI flags override in Phase 2).
mode_env_interactive="${INIT_PROJECT_INTERACTIVE:-0}"
mode_env_noninteractive="${INIT_PROJECT_NONINTERACTIVE:-0}"

# --- Phase 2: CLI flag parsing (overrides Phase 1 env values) ----------------
# `mode_cli` tracks whether --interactive / --noninteractive was given on the
# CLI so we can distinguish "TTY default" from "explicit interactive".
mode_cli=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    # Mode selection (CLI-2.2)
    --interactive)
      mode_cli="interactive"
      shift
      ;;
    --noninteractive)
      mode_cli="noninteractive"
      shift
      ;;
    # New string flags (FR-4.1 / CLI-2)
    --name)
      opt_name="${2:-}"; shift 2
      ;;
    --description)
      opt_description="${2:-}"; shift 2
      ;;
    --repo-role)
      opt_repo_role="${2:-}"; shift 2
      ;;
    --related-repos)
      opt_related_repos="${2:-}"; shift 2
      ;;
    --github-owner)
      opt_github_owner="${2:-}"; shift 2
      ;;
    --github-project-number)
      opt_github_project_number="${2:-}"; shift 2
      ;;
    --conventions)
      opt_conventions="${2:-}"; shift 2
      ;;
    --commands)
      opt_commands="${2:-}"; shift 2
      ;;
    --scratch-dir)
      opt_scratch_dir="${2:-}"; shift 2
      ;;
    # New boolean flags (CLI-2)
    --force)
      opt_force=1; shift
      ;;
    --merge)
      opt_merge=1; shift
      ;;
    --migrate-agent-md)
      opt_migrate_agent_md=1; shift
      ;;
    --skip-inspection)
      opt_skip_inspection=1; shift
      ;;
    --dry-run)
      opt_dry_run=1; shift
      ;;
    # Pre-existing flags preserved verbatim (CLI-1)
    --project-dir)
      project_dir="${2:-}"; shift 2
      ;;
    --docs-root)
      docs_root="${2:-}"; shift 2
      ;;
    --worktree-root)
      worktree_root="${2:-}"; shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[error] Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# --- Phase 3: mode resolution + validation (CLI-2.2 / ERR-4 / FR-4) ----------

# Reject contradictory env signals first (FR-4 / guardrails).
if [[ "$mode_env_interactive" == "1" && "$mode_env_noninteractive" == "1" && -z "$mode_cli" ]]; then
  echo "[error] Both INIT_PROJECT_INTERACTIVE and INIT_PROJECT_NONINTERACTIVE are set; pick one." >&2
  exit 1
fi

# Resolution order for mode: CLI flag → env var → TTY default (CLI-2.2).
if [[ -n "$mode_cli" ]]; then
  mode="$mode_cli"
elif [[ "$mode_env_noninteractive" == "1" ]]; then
  mode="noninteractive"
elif [[ "$mode_env_interactive" == "1" ]]; then
  mode="interactive"
elif [[ -t 1 ]]; then
  mode="interactive"
else
  mode="noninteractive"
fi

# --merge mode-dependent default (CLI-2). Only applied when neither env nor
# CLI set it (empty == unset).
if [[ -z "$opt_merge" ]]; then
  if [[ "$mode" == "interactive" ]]; then
    opt_merge=1
  else
    opt_merge=0
  fi
fi

# --repo-role enum validation (guardrails / AC-T2-006).
if ! validate_repo_role "$opt_repo_role"; then
  exit 1
fi

# --related-repos format validation (guardrails / SEC-1.3).
if ! validate_related_repos "$opt_related_repos"; then
  exit 1
fi

# --commands / --conventions @file resolution (guardrails / AC-T2-007).
if [[ -n "$opt_commands" ]]; then
  if ! opt_commands="$(resolve_at_value "$opt_commands" commands)"; then
    exit 1
  fi
fi
if [[ -n "$opt_conventions" ]]; then
  if ! opt_conventions="$(resolve_at_value "$opt_conventions" conventions)"; then
    exit 1
  fi
fi

# Noninteractive required-flags accounting (FR-4.3 / ERR-4.1 / AC-T2-003).
# Interactive mode never requires any flag (FR-3.3); noninteractive requires
# the three identity inputs that cannot be guessed without breaking
# AC-SPEC-006's "no fabricated claims" rule.
if [[ "$mode" == "noninteractive" ]]; then
  missing=()
  [[ -z "$opt_name" ]] && missing+=( "--name (or INIT_PROJECT_NAME)" )
  [[ -z "$opt_github_owner" ]] && missing+=( "--github-owner (or INIT_PROJECT_GITHUB_OWNER)" )
  [[ -z "$opt_github_project_number" ]] && missing+=( "--github-project-number (or INIT_PROJECT_GITHUB_PROJECT_NUMBER)" )
  if [[ ${#missing[@]} -gt 0 ]]; then
    die_missing_noninteractive_flags "${missing[@]}"
  fi
fi

# T2 stops here. The `opt_*` variables are now authoritative for every
# downstream phase: AGENTS.md generation (T3 / issue #4), .github-project.json
# extension (T5 / issue #6), and OBS-2 dry-run / idempotency (T6 / issue #7).
# The existing skills-copy / config / docs flow below is unchanged.

project_dir="$(mkdir -p "$project_dir" && cd "$project_dir" && pwd)"
docs_root="${docs_root%/}"
repo_name="$(basename "$project_dir")"

if [[ -z "$worktree_root" ]]; then
  worktree_root="$HOME/Projects/worktree/$repo_name"
fi

worktree_root="$(expand_path "$worktree_root")"

mkdir -p "$worktree_root"
ensure_github_project_config "$project_dir" "$worktree_root"
ensure_opencode_config "$project_dir" "$worktree_root"
copy_required_skills "$project_dir" "$repo_root"

mkdir -p "$project_dir/$docs_root"
if [[ -d "$repo_root/docs" ]]; then
  cp -Rn "$repo_root/docs"/. "$project_dir/$docs_root"/
fi

mkdir -p \
  "$project_dir/$docs_root/adr" \
  "$project_dir/$docs_root/gov" \
  "$project_dir/$docs_root/arch" \
  "$project_dir/$docs_root/spec" \
  "$project_dir/$docs_root/runbook" \
  "$project_dir/$docs_root/qa" \
  "$project_dir/$docs_root/memory" \
  "$project_dir/$docs_root/proj-management/tasks" \
  "$project_dir/$docs_root/proj-management/communication" \
  "$project_dir/$docs_root/proj-management/templates"

echo "Created project docs folders under $project_dir/$docs_root"
echo "Use DOC_ROOT=$docs_root when running workflow scripts for this project."
echo "Issue worktrees will default to $worktree_root"
