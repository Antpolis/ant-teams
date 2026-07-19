#!/usr/bin/env bash
#
# init_project_docs.sh — project-local initialization entrypoint (SPEC-001).
#
# T2 (issue #3): CLI flag expansion, env-var resolution, TTY-based mode
# detection, and validation per CLI-2 / FR-4 / ERR-4.
# T3 (issue #4): AGENTS.md generation — interactive 6-prompt flow (FR-3),
# noninteractive flag-driven generation (FR-4), AGENTS.md artifact contract
# (FR-5 / DM-2 / ARCH-003 Artifact 2): timestamped header, DM-2.2 H2
# sections, empty sections omitted (DM-2.3), "Local Configuration Files"
# always present, every claim traceable to inspection or operator input
# (FR-5.3), and pre-existing-file handling with overwrite/merge/skip +
# .bak.<ts> backup on --force (FR-5.5 / ERR-3.2).
# T5 (issue #6): .github-project.json DM-1 schema extension is consumed
# unchanged. OBS-2 dry-run + idempotency overhaul (T6 / issue #7) remains
# deferred — --dry-run is parsed here but does not suppress AGENTS.md writes.
#
set -euo pipefail

# Bumped 0.1.0 → 0.2.0 for T2 (CLI expansion). Bumped 0.2.0 → 0.3.0 for T3
# (AGENTS.md generation): the init now produces a tailored AGENTS.md whose
# generation comment and initMeta.version carry this stamp per ARCH-003 /
# DM-1.3. `ensure_github_project_config` (T5) consumes it on first init /
# material merge.
readonly INIT_PROJECT_VERSION="0.3.0"

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
                              First colon splits name from url; last colon
                              splits url from relationship; url is opaque and
                              may carry scheme/port/path colons (https://h:443,
                              ssh://git@h:22, git@h:path). Stored as-is; never
                              fetched (SEC-1.3).

GitHub Project (FR-4.1):
  --github-owner OWNER        GitHub owner for .github-project.json.
  --github-project-number N   GitHub Project number (positive integer; e.g. 9).

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
# list of `name:url:relationship` triples per CLI-2 / FR-4.1 / SEC-1.3.
#
# Contract: each triple is parsed by split-points, not field-count:
#   <name> : <url> : <relationship>
#     ^^^^   ^^^^^   ^^^^^^^^^^^^^
#     first  middle  last
#     colon  (opaque colon
#     delim  URL)    delim
#
# The first colon in the entry is the name delimiter; the last colon is the
# relationship delimiter; everything in between is the url field, treated as
# opaque per SEC-1.3 (never fetched, never parsed). Internal url colons are
# preserved verbatim so realistic Git remote forms are accepted:
#
# Accepted examples:
#   name:https://github.com/org/repo:relationship        (https URL)
#   name:https://github.com:443/org/repo:relationship    (https URL with port)
#   name:ssh://git@github.com:22/org/repo:relationship   (ssh:// URL with port)
#   name:git@github.com:org/repo:relationship            (SCP-style git remote)
#   name:github.com/org/repo:relationship                (no-scheme url/path)
#   name:./local/path:relationship                       (relative path)
#   name:/abs/path:relationship                          (absolute path)
#
# Unambiguous failures (rejected):
#   just-a-name                  (fewer than 2 colons — no url+relationship)
#   a:b                          (only 1 colon — missing relationship field)
#   :url:relationship            (empty name)
#   name::relationship           (empty url — middle is blank)
#   a:url:                       (empty relationship)
#
# Ambiguous cases with extra internal colons (e.g. `a:b:c:d:e`) are accepted
# because the url field is opaque per SEC-1.3 — the parser cannot know whether
# the middle colons belong to a port, a path, an SCP remote, etc.
validate_related_repos() {
  local raw="$1"
  if [[ -z "$raw" ]]; then
    return 0
  fi
  local -a triples=()
  local IFS=','
  read -ra triples <<< "$raw"
  local triple
  for triple in "${triples[@]}"; do
    # Skip wholly-empty entries (e.g. trailing comma) — those are not invalid,
    # just ignorable. A non-empty entry must look like name:url:relationship.
    [[ -z "${triple// }" ]] && continue

    # Need at least two colons so name + url + relationship can each exist as
    # distinct fields. With fewer than two colons the entry is unambiguously
    # malformed (no relationship delimiter, e.g. `just-a-name` or `a:b`).
    local colons="${triple//[^:]}"
    if (( ${#colons} < 2 )); then
      echo "[error] Invalid --related-repos entry: '$triple'" >&2
      echo "[error] Expected 'name:url:relationship' (comma-separated triples)." >&2
      echo "[error] First colon splits name from url; last colon splits url from" >&2
      echo "[error] relationship; url is opaque and may carry scheme/port/path" >&2
      echo "[error] colons (https://h:443/p, ssh://git@h:22/p, git@h:path)." >&2
      echo "[error] Stored as-is; never fetched/resolved (SEC-1.3)." >&2
      return 1
    fi

    # Parse via first-colon / last-colon so internal url colons are preserved
    # as opaque URL content. Parameter expansion gives us trailing-empty-field
    # visibility that `read -ra` would silently drop (`a:url:` and `:url:rel`).
    local name="${triple%%:*}"        # text before first colon
    local relationship="${triple##*:}" # text after last colon
    local url="${triple#*:}"          # strip "<name>:"
    url="${url%:*}"                   # strip ":<relationship>"

    if [[ -z "$name" || -z "$url" || -z "$relationship" ]]; then
      echo "[error] Invalid --related-repos entry: '$triple'" >&2
      echo "[error] Expected 'name:url:relationship' (comma-separated triples)." >&2
      echo "[error] First colon splits name from url; last colon splits url from" >&2
      echo "[error] relationship; url is opaque and may carry scheme/port/path" >&2
      echo "[error] colons (https://h:443/p, ssh://git@h:22/p, git@h:path)." >&2
      echo "[error] Stored as-is; never fetched/resolved (SEC-1.3)." >&2
      return 1
    fi
  done
  return 0
}

# validate_github_project_number NUM — exit 1 if NUM is set but not a positive
# integer (CLI-2 types --github-project-number as `Integer`; GitHub Project
# numbers are positive). Empty input is "not provided" and passes; the
# noninteractive required-flag accounting handles the missing case.
validate_github_project_number() {
  local num="$1"
  if [[ -z "$num" ]]; then
    return 0
  fi
  # Positive integer with no leading zero, no sign, no decimal point, no
  # exponent. Rejects: '', '0', '-1', '1.5', '1e10', '0x10', '07', ' 9',
  # '9 ', 'nope', '123abc'. Bash regex (ERE subset) under `set -u` is safe
  # here because the regex is a literal.
  if [[ ! "$num" =~ ^[1-9][0-9]*$ ]]; then
    echo "[error] Invalid --github-project-number value: '$num' (must be a positive integer)" >&2
    echo "[error] Or set INIT_PROJECT_GITHUB_PROJECT_NUMBER to a positive integer." >&2
    return 1
  fi
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

# SPEC-001 T5 / ARCH-003 Artifact 4: detection covers BOTH the canonical
# `.opencode/` location AND the legacy repo-root location. Detection order
# is `.opencode/` first (ARCH-003 canonical), then repo root (backward
# compat with prior init output). The default creation target is the
# canonical `.opencode/opencode.json` (ARCH-003 Artifact 4 location
# contract; SPEC-001 migration states: "Fresh repo → upgraded init:
# Creates: ... .opencode/opencode.json (minimal)"). A pre-existing config
# in ANY supported location is detected and updated in place — it is NEVER
# relocated, NEVER rewritten to the other extension (ARCH-003 Artifact 4
# guarantee 3). The legacy repo-root `opencode.jsonc` / `opencode.json`
# fall-backs exist only to keep already-initialized repos working; fresh
# inits land at the canonical location.
ensure_opencode_config() {
  local project_dir="$1"
  local worktree_root="$2"
  local external_pattern="${worktree_root%/}/**"
  local config_path=""

  if [[ -f "$project_dir/.opencode/opencode.json" ]]; then
    config_path="$project_dir/.opencode/opencode.json"
  elif [[ -f "$project_dir/.opencode/opencode.jsonc" ]]; then
    config_path="$project_dir/.opencode/opencode.jsonc"
  elif [[ -f "$project_dir/opencode.jsonc" ]]; then
    config_path="$project_dir/opencode.jsonc"
  elif [[ -f "$project_dir/opencode.json" ]]; then
    config_path="$project_dir/opencode.json"
  else
    # Fresh repo: create at the canonical ARCH-003 Artifact 4 location.
    # `.opencode/` may not exist yet on a true fresh init, so create it
    # before writing. mkdir -p is idempotent and never complains if the
    # directory already exists (SEC-3.1: mkdir -p is an allowed primitive).
    mkdir -p "$project_dir/.opencode"
    config_path="$project_dir/.opencode/opencode.json"
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

# SPEC-001 T5 / ARCH-003 DM-1: extend `.github-project.json` to the canonical
# schema (worktreeRoot, identity, boundaries, initMeta) additively. Existing
# fields are NEVER removed or overwritten (FR-6.3, SEC-2.1, ARCH-003
# guarantee 2: "strictly additive — new fields may be added but existing
# required fields are never removed by the initializer").
#
# The merge is computed in `node` as a single read-modify-write that writes
# ONLY when the desired state differs structurally from the current state.
# This is what makes AC-T5-005 / TR-2.1 (idempotent rerun produces no
# changes) work: a no-op rerun leaves the file byte-for-byte identical,
# including the `initMeta.generatedAt` timestamp from the prior write.
#
# Identity/boundaries value resolution (issue guardrails + FR-8.5):
#   - identity.name: opt_name (--name) → detected repo_name (basename) fallback
#   - identity.description: opt_description, "" when not provided (T3 prompts
#     will populate interactively; empty string is schema-valid per ARCH-003)
#   - identity.role: opt_repo_role → "other" fallback (most generic enum value)
#   - boundaries.owns: "" when not provided (T3 will populate via prompts)
#   - boundaries.depends_on: ALWAYS [] at T5 scope — no --depends-on flag exists
#     yet (CLI-2 / FR-4.1); all operator-provided triples route to related_repos
#   - boundaries.related_repos: parsed from opt_related_repos triples, or []
#
# Parameter contract:
#   $1 project_dir       — target project root (already canonicalized)
#   $2 worktree_root     — canonical absolute worktree root path
#   $3 repo_name         — detected repo name (basename of project_dir); used
#                          as identity.name fallback per FR-8.5 / guardrails
#   $4 opt_name          — --name override (empty → fall back to detected)
#   $5 opt_description   — --description override (empty → "")
#   $6 opt_role          — --repo-role override (empty → "other")
#   $7 opt_related_repos — --related-repos raw triples (empty → [])
#   $8 version           — INIT_PROJECT_VERSION (for initMeta.version)
ensure_github_project_config() {
  local project_dir="$1"
  local worktree_root="$2"
  local repo_name="$3"
  local opt_name="$4"
  local opt_description="$5"
  local opt_role="$6"
  local opt_related_repos="$7"
  local version="$8"
  local config_path="$project_dir/.github-project.json"

  local identity_name="${opt_name:-$repo_name}"
  local identity_role="${opt_role:-other}"

  node - \
    "$config_path" \
    "$worktree_root" \
    "$identity_name" \
    "$opt_description" \
    "$identity_role" \
    "$opt_related_repos" \
    "$version" <<'NODE'
const fs = require("fs");

const [
  configPath,
  worktreeRoot,
  identityName,
  identityDescription,
  identityRole,
  relatedReposRaw,
  version,
] = process.argv.slice(2);

// Parse `name:url:relationship,name:url:relationship,...` into the
// boundaries.related_repos array. The first colon splits name from url; the
// last colon splits url from relationship; everything in between is the url
// field, stored opaque per SEC-1.3 (never fetched). Mirror the bash
// validator's first/last-colon rule so node and bash agree on shape.
function parseRelatedRepos(raw) {
  if (!raw) return [];
  const out = [];
  for (const entry of raw.split(",")) {
    if (!entry.trim()) continue;
    const firstColon = entry.indexOf(":");
    const lastColon = entry.lastIndexOf(":");
    if (firstColon === -1 || lastColon === -1 || firstColon === lastColon) continue;
    const name = entry.slice(0, firstColon);
    const url = entry.slice(firstColon + 1, lastColon);
    const relationship = entry.slice(lastColon + 1);
    if (!name || !url || !relationship) continue;
    out.push({ name, url, relationship });
  }
  return out;
}

const relatedRepos = parseRelatedRepos(relatedReposRaw);

let parsed;
let isNew = false;
if (fs.existsSync(configPath)) {
  // SEC-2.1 / ERR-2.1 spirit: abort cleanly BEFORE any mutation if the
  // existing file is malformed. The bash contract for every validation
  // failure in this script is a controlled `[error]`-prefixed stderr
  // message + exit 1 (see validate_repo_role / validate_related_repos /
  // die_missing_noninteractive_flags). Mirror that here so the operator
  // sees the same UX instead of a leaked Node SyntaxError stack trace.
  // No write happens before this point, so the file is preserved
  // byte-for-byte on abort.
  let raw;
  try {
    raw = fs.readFileSync(configPath, "utf8");
  } catch (readErr) {
    console.error(`[error] Failed to read ${configPath}: ${readErr.message}`);
    process.exit(1);
  }
  try {
    parsed = JSON.parse(raw);
  } catch (parseErr) {
    console.error(`[error] Malformed ${configPath}: ${parseErr.message}`);
    console.error("[error] Fix the JSON manually and re-run; init will not overwrite a broken file.");
    process.exit(1);
  }
} else {
  // Fresh repo: seed the operator-editable baseline fields (owner/project/
  // fields/status_options) with placeholder values, exactly as the pre-T5
  // implementation did. The new DM-1 fields (worktreeRoot/identity/
  // boundaries/initMeta) are then added by the additive merge below, so a
  // fresh-init file is complete on first write. The placeholders must be
  // operator-replaced — they cannot be auto-detected without network access
  // (ARCH-003 guarantee: init must not require network access).
  parsed = {
    owner: "your-github-owner",
    owner_type: "org",
    repo: "your-github-owner/your-repo",
    project: { number: 1, id: "PVT_kwDOEXAMPLE" },
    fields: { status: "PVTSSF_EXAMPLE" },
    status_options: {
      todo: "todo-option-id",
      "in-progress": "in-progress-option-id",
      "in-review": "in-review-option-id",
      done: "done-option-id",
    },
  };
  isNew = true;
}

// Deep-clone the current state so we never mutate the parsed input. The
// desired state is built field-by-field against this clone; existing fields
// are preserved verbatim (ARCH-003 guarantee 2 / SEC-2.1).
const desired = JSON.parse(JSON.stringify(parsed));

// worktreeRoot: required per DM-1; do NOT overwrite pre-existing explicit
// value (FR-6.3: "The worktreeRoot default must not overwrite a pre-existing
// explicit value").
if (!desired.worktreeRoot) {
  desired.worktreeRoot = worktreeRoot;
}

// identity block: required per DM-1; each field is additive-only.
if (!desired.identity || typeof desired.identity !== "object" || Array.isArray(desired.identity)) {
  desired.identity = {};
}
if (!desired.identity.name) {
  desired.identity.name = identityName;
}
if (!desired.identity.description) {
  desired.identity.description = identityDescription || "";
}
if (!desired.identity.role) {
  desired.identity.role = identityRole;
}

// boundaries block: required per DM-1; each field is additive-only.
// depends_on and related_repos MUST be [] when empty (FR-8.5 / AC-T5-007),
// never absent — this lets agents distinguish "no relationships" from
// "field missing/legacy file".
if (!desired.boundaries || typeof desired.boundaries !== "object" || Array.isArray(desired.boundaries)) {
  desired.boundaries = {};
}
if (!desired.boundaries.owns) {
  desired.boundaries.owns = "";
}
if (!Array.isArray(desired.boundaries.depends_on)) {
  desired.boundaries.depends_on = [];
}
if (!Array.isArray(desired.boundaries.related_repos)) {
  // First init with operator-provided related-repos populates the array.
  // Subsequent runs preserve whatever is already there (additive-only),
  // so a re-run with different --related-repos does NOT overwrite.
  desired.boundaries.related_repos = relatedRepos;
}

// initMeta block: required per DM-1; additive-only. generatedAt is a
// write-time stamp set ONLY when the file is actually being written — see
// the idempotency check below (AC-T5-005 / TR-2.1).
if (!desired.initMeta || typeof desired.initMeta !== "object" || Array.isArray(desired.initMeta)) {
  desired.initMeta = {};
}
if (!desired.initMeta.version) {
  desired.initMeta.version = version;
}

// Idempotency: write ONLY when the structural state changed. Compare
// parsed vs desired with the volatile generatedAt field stripped from
// both sides, so a true no-op rerun leaves the file (including its
// existing generatedAt) byte-for-byte identical (AC-T5-005 / TR-2.1).
const stripGeneratedAt = (obj) => {
  const c = JSON.parse(JSON.stringify(obj));
  if (c.initMeta && Object.prototype.hasOwnProperty.call(c.initMeta, "generatedAt")) {
    delete c.initMeta.generatedAt;
  }
  return c;
};

const currentStructural = JSON.stringify(stripGeneratedAt(parsed), null, 2);
const desiredStructural = JSON.stringify(stripGeneratedAt(desired), null, 2);

if (!isNew && currentStructural === desiredStructural) {
  // No structural change — preserve the existing file untouched.
  console.log("No changes needed in .github-project.json");
  process.exit(0);
}

// Material change (or first creation). Stamp/refresh generatedAt as the
// last field before write so it represents "last material init write".
desired.initMeta.generatedAt = new Date().toISOString();
fs.writeFileSync(configPath, JSON.stringify(desired, null, 2) + "\n");

if (isNew) {
  console.log("Created .github-project.json");
} else {
  console.log("Updated .github-project.json (additive merge)");
}
NODE
}

# ===========================================================================
# SPEC-001 T3 (issue #4): AGENTS.md generation — interactive + noninteractive.
#
# Implements FR-3 (interactive 6-prompt flow), FR-4 (noninteractive flag-driven
# generation), FR-5 (AGENTS.md artifact contract), DM-2 (AGENTS.md structure),
# ERR-3.2 (--force backup), and ARCH-003 Artifact 2 guarantees.
#
# Flow (invoked from main after skills/config/docs writes per ERR-2.1 step 4;
# AGENTS.md is the final artifact so "Local Configuration Files" can enumerate
# what was written):
#   1. run_repo_inspection        → JSON evidence (issue #2 engine; skipped
#                                   if --skip-inspection).
#   2. compute_prompt_defaults    → JSON with default values for each
#                                   section, derived from inspection +
#                                   existing repo state.
#   3. If interactive: prompt_for_agents_md collects operator responses
#      (each prompt accepts blank = use default / omit per FR-3.3).
#      Else: effective values come from opt_* (T2 resolution).
#   4. generate_agents_md_content → markdown assembled by an inline node
#      helper. Every section grounded in inspection or operator input
#      (FR-5.3 / AC-T3-006). Empty sections omitted (DM-2.3).
#   5. decide_existing_agents_md_action → interactive: ask overwrite/merge/
#      skip; noninteractive: skip unless --force (FR-5.5).
#   6. Interactive preview + Y/n confirmation (FR-3.4).
#   7. backup_agents_md + write (overwrite) or merge (FR-5.5 / ERR-3.2).
# ===========================================================================

# FR-2 / T3: run inspect_repo.js (issue #2 engine) and capture the JSON
# evidence record. Read-only (FR-2.1). On hard failure, emits [warning] to
# stderr and returns empty JSON so AGENTS.md can still be built from
# operator input alone (TR-3.1 / TR-3.2: bare / non-code repos must still
# produce valid AGENTS.md).
run_repo_inspection() {
  local project_dir="$1"
  local inspect_script="$skill_root/scripts/inspect_repo.js"
  if [[ ! -f "$inspect_script" ]]; then
    echo "[warning] inspect_repo.js not found at $inspect_script; AGENTS.md will rely on operator inputs only" >&2
    printf '{}'
    return 0
  fi
  local json
  if ! json="$(node "$inspect_script" --project-dir "$project_dir" 2>/dev/null)"; then
    echo "[warning] Repository inspection failed; AGENTS.md will rely on operator inputs only" >&2
    printf '{}'
    return 0
  fi
  printf '%s' "$json"
}

# FR-3.1: present the operator with a concise summary of detected facts,
# grounded in inspection evidence. Each [inspecting] line is traceable to a
# detection signal (AC-T3-006). Output goes to stdout per OBS-1.
display_inspection_summary() {
  local inspection="$1"
  AGENTSMD_INSPECTION="$inspection" node <<'NODE'
    const data = JSON.parse(process.env.AGENTSMD_INSPECTION || "{}");
    const list = (cat) => {
      if (!cat) return [];
      if (Array.isArray(cat.observed)) return cat.observed;
      if (typeof cat.observed === "string" && cat.observed !== "not detected") return [cat.observed];
      return [];
    };
    const parts = [];
    const lang = list(data.language);
    if (lang.length) parts.push("language: " + lang.join(", "));
    const pm = list(data.package_manager);
    if (pm.length) parts.push("package manager: " + pm.join(", "));
    const docs = list(data.docs_root);
    if (docs.length) parts.push("docs root: " + docs.join(", "));
    const tests = list(data.test_infrastructure);
    if (tests.length) parts.push("tests: " + tests.join(", "));
    const cicd = list(data.cicd);
    if (cicd.length) parts.push("ci/cd: " + cicd.join(", "));
    const ag = list(data.agent_guidance);
    if (ag.length) parts.push("existing agent guidance: " + ag.join(", "));
    const gh = data.github_project_config && data.github_project_config.observed ? "yes" : "no";
    parts.push("existing .github-project.json: " + gh);
    const amb = Array.isArray(data.ambiguities) ? data.ambiguities : [];
    if (amb.length) parts.push("ambiguities: " + amb.length);
    if (!parts.length) parts.push("no inspection signals detected; AGENTS.md will be built from operator input");
    for (const l of parts) console.log("[inspecting] " + l);
NODE
}

# Compute default values for the 6 interactive prompts (FR-3.2). Output is a
# JSON object on stdout. Defaults are derived ONLY from inspection evidence
# and existing repo state (never fabricated — AC-T3-006).
compute_prompt_defaults() {
  local project_dir="$1"
  local repo_name="$2"
  local inspection="$3"
  AGENTSMD_PROJECT_DIR="$project_dir" \
  AGENTSMD_REPO_NAME="$repo_name" \
  AGENTSMD_INSPECTION="$inspection" \
  node <<'NODE'
    const fs = require("fs");
    const path = require("path");
    const projectDir = process.env.AGENTSMD_PROJECT_DIR;
    const repoName = process.env.AGENTSMD_REPO_NAME;
    const inspection = JSON.parse(process.env.AGENTSMD_INSPECTION || "{}");

    const list = (cat) => {
      if (!cat) return [];
      if (Array.isArray(cat.observed)) return cat.observed;
      if (typeof cat.observed === "string" && cat.observed !== "not detected") return [cat.observed];
      return [];
    };

    // FR-3.2 row 1 default: "<repo-name>: a <language> project" or just
    // "<repo-name>" when no language was detected.
    const lang0 = list(inspection.language)[0] || "";
    const purpose = lang0 ? `${repoName}: a ${lang0} project` : repoName;

    // FR-3.2 row 3 default: detected npm scripts + Makefile targets.
    const cmds = [];
    const pkgPath = path.join(projectDir, "package.json");
    if (fs.existsSync(pkgPath)) {
      try {
        const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
        if (pkg && pkg.scripts && typeof pkg.scripts === "object") {
          for (const [name, script] of Object.entries(pkg.scripts)) {
            if (typeof script === "string") cmds.push(`npm run ${name}`);
          }
        }
      } catch (_e) { /* malformed package.json — skip */ }
    }
    const makefilePath = path.join(projectDir, "Makefile");
    if (fs.existsSync(makefilePath)) {
      try {
        const text = fs.readFileSync(makefilePath, "utf8");
        const seen = new Set();
        for (const line of text.split("\n")) {
          const m = line.match(/^([a-zA-Z][a-zA-Z0-9_-]*)\s*:/);
          if (m && !seen.has(m[1])) seen.add(m[1]);
        }
        for (const t of seen) cmds.push(`make ${t}`);
      } catch (_e) { /* malformed Makefile — skip */ }
    }

    // FR-3.2 row 6 default: from existing .github-project.json. Placeholder
    // values from a fresh init (owner="your-github-owner", number=1) are
    // treated as "no real default" so AGENTS.md omits the section unless the
    // operator provides real input.
    let ghOwner = "";
    let ghProjectNumber = "";
    const ghPath = path.join(projectDir, ".github-project.json");
    if (fs.existsSync(ghPath)) {
      try {
        const gh = JSON.parse(fs.readFileSync(ghPath, "utf8"));
        if (gh.owner && gh.owner !== "your-github-owner") ghOwner = String(gh.owner);
        if (gh.project && gh.project.number && gh.project.number !== 1) {
          ghProjectNumber = String(gh.project.number);
        }
      } catch (_e) { /* malformed — skip */ }
    }

    const defaults = {
      purpose,
      commands: cmds.join("\n"),
      commands_summary: cmds.length ? cmds.join(", ") : "none detected",
      conventions: "",
      related_repos: "",
      scratch_dir: "./tmp/",
      github_owner: ghOwner,
      github_project_number: ghProjectNumber,
    };
    process.stdout.write(JSON.stringify(defaults));
NODE
}

# Extract a string field from a JSON object read on stdin. Avoids a jq
# dependency (TR-1.1: bash + node + coreutils only).
json_get() {
  local field="$1"
  node -e '
    let d = "";
    process.stdin.on("data", (c) => { d += c; });
    process.stdin.on("end", () => {
      try {
        const o = JSON.parse(d);
        const v = o[process.argv[1]];
        process.stdout.write(v == null ? "" : String(v));
      } catch (_e) { process.stdout.write(""); }
    });
  ' "$field"
}

# safe_read PROMPT OUT_VAR — read one line from stdin into OUT_VAR. Tolerates
# EOF (returns "" instead of aborting under `set -e`). Used for interactive
# prompts where stdin may close early (test piping, accidental Ctrl-D).
safe_read() {
  local prompt="$1"
  local out_var="$2"
  local input=""
  printf '%s' "$prompt"
  if ! IFS= read -r input; then
    printf '\n'
  fi
  printf -v "$out_var" '%s' "$input"
}

# FR-3.2 / FR-3.3: run the 6 interactive prompts. Each prompt accepts a
# blank response (FR-3.3): blank falls back to opt_* flag, then the computed
# default, then "omit section" for fields without a default. Effective
# values are exported via the AGENTSMD_EFF_* env vars consumed by the
# assembly node helper. Side-effect-only: prompt text to stdout (OBS-1),
# responses from stdin.
prompt_for_agents_md() {
  local project_dir="$1"
  local repo_name="$2"
  local inspection="$3"

  local defaults_json
  defaults_json="$(compute_prompt_defaults "$project_dir" "$repo_name" "$inspection")"

  local def_purpose def_commands_summary def_scratch def_gh_owner def_gh_num
  def_purpose="$(printf '%s' "$defaults_json" | json_get purpose)"
  def_commands_summary="$(printf '%s' "$defaults_json" | json_get commands_summary)"
  def_scratch="$(printf '%s' "$defaults_json" | json_get scratch_dir)"
  def_gh_owner="$(printf '%s' "$defaults_json" | json_get github_owner)"
  def_gh_num="$(printf '%s' "$defaults_json" | json_get github_project_number)"

  display_inspection_summary "$inspection"

  local resp=""

  # FR-3.2 prompt 1: primary purpose.
  echo "[prompt] Q1/6: What is the primary purpose of this repository?"
  safe_read "[prompt]   purpose [$def_purpose]: " resp
  AGENTSMD_EFF_PURPOSE="${resp:-${opt_description:-$def_purpose}}"

  # FR-3.2 prompt 2: working conventions (blank → omit section per FR-5.2).
  echo "[prompt] Q2/6: What should agents know about the working conventions here?"
  safe_read "[prompt]   conventions (blank → omit section): " resp
  AGENTSMD_EFF_CONVENTIONS="${resp:-$opt_conventions}"

  # FR-3.2 prompt 3: build/test/run commands (blank → detected or opt_commands).
  echo "[prompt] Q3/6: Describe any build, test, or run commands agents should use."
  safe_read "[prompt]   commands (blank → ${def_commands_summary}): " resp
  if [[ -n "$resp" ]]; then
    AGENTSMD_EFF_COMMANDS="$resp"
  elif [[ -n "$opt_commands" ]]; then
    AGENTSMD_EFF_COMMANDS="$opt_commands"
  else
    AGENTSMD_EFF_COMMANDS="$(printf '%s' "$defaults_json" | json_get commands)"
  fi

  # FR-3.2 prompt 4: repository relationships (blank → omit unless flag set).
  echo "[prompt] Q4/6: How does this repository relate to other repos in the project?"
  safe_read "[prompt]   related repos (blank → omit section): " resp
  AGENTSMD_EFF_RELATED_REPOS="${resp:-$opt_related_repos}"

  # FR-3.2 prompt 5: scratch dir (blank → ./tmp/ default).
  echo "[prompt] Q5/6: Where should agents store durable work-in-progress and logs?"
  safe_read "[prompt]   scratch dir [${opt_scratch_dir:-$def_scratch}]: " resp
  AGENTSMD_EFF_SCRATCH_DIR="${resp:-${opt_scratch_dir:-$def_scratch}}"

  # FR-3.2 prompt 6: GitHub project config (blank → detected or opt flags).
  echo "[prompt] Q6/6: What is this repo's GitHub Project configuration?"
  safe_read "[prompt]   github owner [$def_gh_owner]: " resp
  AGENTSMD_EFF_GITHUB_OWNER="${resp:-${opt_github_owner:-$def_gh_owner}}"
  safe_read "[prompt]   github project number [$def_gh_num]: " resp
  AGENTSMD_EFF_GITHUB_PROJECT_NUMBER="${resp:-${opt_github_project_number:-$def_gh_num}}"

  # Name + role flow through unchanged (resolved by T2 / T5).
  AGENTSMD_EFF_REPO_NAME="${opt_name:-$repo_name}"
  AGENTSMD_EFF_REPO_ROLE="${opt_repo_role:-}"
}

# FR-5 / DM-2 / ARCH-003 Artifact 2: assemble AGENTS.md content from
# inspection evidence + effective operator values. Every section grounded in
# a detection signal or operator input (FR-5.3 / AC-T3-006). Empty sections
# omitted entirely (DM-2.3). Output: markdown to stdout.
#
# Inputs come from process.env (set by the caller) so multi-line operator
# values survive without argv escaping.
generate_agents_md_content() {
  node <<'NODE'
    const fs = require("fs");
    const path = require("path");

    const projectDir = process.env.AGENTSMD_PROJECT_DIR;
    const repoName = process.env.AGENTSMD_REPO_NAME;
    const docsRoot = process.env.AGENTSMD_DOCS_ROOT;
    const version = process.env.AGENTSMD_VERSION;
    const inspection = JSON.parse(process.env.AGENTSMD_INSPECTION || "{}");

    const eff = {
      purpose:        process.env.AGENTSMD_EFF_PURPOSE           || "",
      conventions:    process.env.AGENTSMD_EFF_CONVENTIONS      || "",
      commands:       process.env.AGENTSMD_EFF_COMMANDS         || "",
      relatedReposRaw:process.env.AGENTSMD_EFF_RELATED_REPOS    || "",
      scratchDir:     process.env.AGENTSMD_EFF_SCRATCH_DIR      || "./tmp/",
      githubOwner:    process.env.AGENTSMD_EFF_GITHUB_OWNER     || "",
      githubNumber:   process.env.AGENTSMD_EFF_GITHUB_PROJECT_NUMBER || "",
      repoRole:       process.env.AGENTSMD_EFF_REPO_ROLE        || "",
    };

    const list = (cat) => {
      if (!cat) return [];
      if (Array.isArray(cat.observed)) return cat.observed;
      if (typeof cat.observed === "string" && cat.observed !== "not detected") return [cat.observed];
      return [];
    };

    const sections = [];

    // ## Repository Identity — operator input or detected default.
    {
      const lines = [];
      if (eff.purpose.trim()) lines.push(eff.purpose.trim());
      if (eff.repoRole.trim()) lines.push(`Role: ${eff.repoRole.trim()}`);
      if (lines.length) sections.push({ heading: "Repository Identity", body: lines.join("\n") });
    }

    // ## Project Structure — detected directory layout + boundaries.
    {
      const lines = [];
      const docs = list(inspection.docs_root);
      if (docs.length) lines.push(`Documentation root: \`${docs[0]}/\``);
      const tests = list(inspection.test_infrastructure);
      const dirs = tests.filter((t) => ["test", "tests", "spec", "__tests__"].includes(t));
      if (dirs.length) lines.push(`Test directories: ${dirs.map((d) => `\`${d}/\``).join(", ")}`);
      const fw = tests.filter((t) => !["test", "tests", "spec", "__tests__"].includes(t));
      if (fw.length) lines.push(`Test frameworks: ${fw.join(", ")}`);
      const bounds = Array.isArray(inspection.app_boundaries?.observed) ? inspection.app_boundaries.observed : [];
      if (bounds.length) {
        lines.push("App/service boundaries:");
        for (const b of bounds) lines.push(`- \`${b.path}\` (manifest: \`${b.manifest}\`)`);
      }
      const cicd = list(inspection.cicd);
      if (cicd.length) lines.push(`CI/CD artifacts: ${cicd.map((c) => `\`${c}\``).join(", ")}`);
      if (lines.length) sections.push({ heading: "Project Structure", body: lines.join("\n") });
    }

    // ## Stack — detected language, package manager, framework.
    {
      const lines = [];
      const lang = list(inspection.language);
      if (lang.length) lines.push(`Language: ${lang.join(", ")}`);
      const inferredLang = Array.isArray(inspection.language?.inferred) ? inspection.language.inferred : [];
      if (inferredLang.length) lines.push(`Additional language signal: ${inferredLang.join(", ")} (inferred from config files)`);
      const pm = list(inspection.package_manager);
      if (pm.length) lines.push(`Package manager: ${pm.join(", ")}`);
      const inferredPm = Array.isArray(inspection.package_manager?.inferred) ? inspection.package_manager.inferred : [];
      if (inferredPm.length) lines.push(`Package manager signal: ${inferredPm.join(", ")} (inferred from manifest; no lockfile)`);
      if (lines.length) sections.push({ heading: "Stack", body: lines.join("\n") });
    }

    // ## Build, Test, and Run Commands — operator input OR detected.
    {
      const lines = [];
      if (eff.commands.trim()) {
        for (const l of eff.commands.split(/\r?\n/)) {
          const t = l.trim();
          if (!t) continue;
          lines.push(t.startsWith("- ") ? t : `- ${t}`);
        }
      } else {
        const pkgPath = path.join(projectDir, "package.json");
        if (fs.existsSync(pkgPath)) {
          try {
            const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
            if (pkg && pkg.scripts && typeof pkg.scripts === "object") {
              for (const [name, script] of Object.entries(pkg.scripts)) {
                if (typeof script === "string") lines.push(`- \`npm run ${name}\` — ${script}`);
              }
            }
          } catch (_e) { /* malformed — skip */ }
        }
        const makefilePath = path.join(projectDir, "Makefile");
        if (fs.existsSync(makefilePath)) {
          try {
            const text = fs.readFileSync(makefilePath, "utf8");
            const seen = new Set();
            for (const line of text.split("\n")) {
              const m = line.match(/^([a-zA-Z][a-zA-Z0-9_-]*)\s*:/);
              if (m && !seen.has(m[1])) seen.add(m[1]);
            }
            for (const t of seen) lines.push(`- \`make ${t}\``);
          } catch (_e) { /* malformed — skip */ }
        }
      }
      if (lines.length) sections.push({ heading: "Build, Test, and Run Commands", body: lines.join("\n") });
    }

    // ## Working Conventions — operator input only. Omitted when blank.
    if (eff.conventions.trim()) {
      sections.push({ heading: "Working Conventions", body: eff.conventions.trim() });
    }

    // ## Repository Relationships — operator input or detected monorepo.
    {
      const lines = [];
      if (eff.relatedReposRaw.trim()) {
        // Try structured triples first; fall back to free text.
        const triples = [];
        for (const entry of eff.relatedReposRaw.split(",")) {
          if (!entry.trim()) continue;
          const firstColon = entry.indexOf(":");
          const lastColon = entry.lastIndexOf(":");
          if (firstColon > 0 && lastColon > firstColon) {
            const n = entry.slice(0, firstColon);
            const u = entry.slice(firstColon + 1, lastColon);
            const r = entry.slice(lastColon + 1);
            if (n && u && r) triples.push({ n, u, r });
          }
        }
        if (triples.length) {
          for (const t of triples) lines.push(`- \`${t.n}\` — ${t.u} (${t.r})`);
        } else {
          for (const l of eff.relatedReposRaw.split(/\r?\n/)) {
            if (l.trim()) lines.push(`- ${l.trim()}`);
          }
        }
      } else {
        const bounds = Array.isArray(inspection.app_boundaries?.observed) ? inspection.app_boundaries.observed : [];
        if (bounds.length) {
          lines.push("Detected app/service boundaries within this repository:");
          for (const b of bounds) lines.push(`- \`${b.path}\``);
        }
      }
      if (lines.length) sections.push({ heading: "Repository Relationships", body: lines.join("\n") });
    }

    // ## Documentation — operator --docs-root flag or default docs/.
    {
      const root = docsRoot || "docs";
      sections.push({ heading: "Documentation", body: `Documentation root: \`${root}/\`` });
    }

    // ## Scratch and Log Directories — operator input or ./tmp/ default.
    {
      const sd = eff.scratchDir || "./tmp/";
      sections.push({ heading: "Scratch and Log Directories", body: `Scratch directory for work-in-progress and logs: \`${sd}\`` });
    }

    // ## GitHub Project Configuration — operator input or existing config.
    // Omitted when neither provides real (non-placeholder) values.
    {
      const lines = [];
      if (eff.githubOwner) lines.push(`GitHub owner: \`${eff.githubOwner}\``);
      if (eff.githubNumber) lines.push(`GitHub project number: \`${eff.githubNumber}\``);
      if (lines.length) sections.push({ heading: "GitHub Project Configuration", body: lines.join("\n") });
    }

    // ## Local Configuration Files (DM-2.4 — always present).
    {
      // Detect actual opencode config path (mirrors ensure_opencode_config
      // detection order: canonical .opencode/* first, then repo root).
      let ocPath = ".opencode/opencode.json";
      for (const c of [".opencode/opencode.json", ".opencode/opencode.jsonc", "opencode.jsonc", "opencode.json"]) {
        if (fs.existsSync(path.join(projectDir, c))) { ocPath = c; break; }
      }
      const artifacts = [
        { p: "AGENTS.md", d: "This file — canonical agent guidance for this repository" },
        { p: ".github-project.json", d: "GitHub workflow metadata and multi-repo identity" },
        { p: ocPath, d: "OpenCode runtime config (worktree permission, agents, providers)" },
        { p: ".opencode/skills/github-issues-projects-cli/", d: "GitHub Projects CLI helper scripts" },
        { p: ".opencode/skills/do-task/", d: "Task worktree management scripts" },
        { p: ".opencode/skills/project-initialization/", d: "Re-initialization scripts (this skill)" },
      ];
      sections.push({ heading: "Local Configuration Files", body: artifacts.map((a) => `- \`${a.p}\` — ${a.d}`).join("\n") });
    }

    // FR-5.4 / DM-2.1: generation timestamp HTML comment on line 1.
    const ts = new Date().toISOString();
    const header = `<!-- Generated by init-project v${version} on ${ts} — edit freely -->`;

    let out = header + "\n\n";
    for (const s of sections) out += `## ${s.heading}\n\n${s.body}\n\n`;
    process.stdout.write(out);
NODE
}

# FR-5.5: decide how to handle a pre-existing AGENTS.md. Sets the global
# AGENTS_MD_ACTION to one of: "create", "skip", "overwrite", or "merge".
# Interactive prompts go to stdout (OBS-1); the decision is returned via a
# global variable (not stdout capture) so prompt text does not pollute the
# return value.
decide_existing_agents_md_action() {
  local target="$1"
  local mode_arg="$2"
  local force_arg="$3"
  local merge_arg="$4"

  if [[ ! -f "$target" ]]; then
    AGENTS_MD_ACTION="create"
    return 0
  fi

  if [[ "$mode_arg" == "interactive" ]]; then
    cat >&2 <<'MSG'
[prompt] An AGENTS.md already exists at the repository root.
[prompt] Choose how to proceed:
[prompt]   o = overwrite (back up existing, write fresh)
[prompt]   m = merge     (back up existing, append new sections not already present)
[prompt]   s = skip      (preserve existing file untouched)
MSG
    local resp=""
    while true; do
      safe_read "[prompt] Action [o/m/s] (default: s): " resp
      case "${resp:-s}" in
        o|O) AGENTS_MD_ACTION="overwrite"; return 0 ;;
        m|M) AGENTS_MD_ACTION="merge"; return 0 ;;
        s|S|'') AGENTS_MD_ACTION="skip"; return 0 ;;
        *) echo "[prompt] Please answer o, m, or s." >&2 ;;
      esac
    done
  fi

  # Noninteractive: skip unless --force (FR-5.5).
  if [[ "$force_arg" == "1" ]]; then
    if [[ "$merge_arg" == "1" ]]; then
      AGENTS_MD_ACTION="merge"
    else
      AGENTS_MD_ACTION="overwrite"
    fi
  else
    AGENTS_MD_ACTION="skip"
  fi
}

# ERR-3.2: back up an existing file to <filename>.bak.<timestamp> before
# overwrite/merge. Timestamp: YYYYMMDDTHHMMSSZ (ISO 8601 basic — no
# filesystem-problematic characters). Echoes the backup path to stdout.
backup_agents_md() {
  local target="$1"
  local ts
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  local backup="${target}.bak.${ts}"
  cp -p "$target" "$backup"
  printf '%s' "$backup"
}

# FR-5.5 --force --merge: produce merged content. Existing H2 sections are
# preserved verbatim; new sections whose H2 heading is NOT already present
# are appended. The generation timestamp comment on line 1 is refreshed to
# reflect this generation. Reads existing + fresh content from env vars
# (multi-line safe) and writes the merged markdown to stdout.
merge_agents_md_content() {
  local existing_content="$1"
  local fresh_content="$2"
  local tmp_existing tmp_fresh
  tmp_existing="$(mktemp)"
  tmp_fresh="$(mktemp)"
  printf '%s' "$existing_content" > "$tmp_existing"
  printf '%s' "$fresh_content" > "$tmp_fresh"
  AGENTSMD_EXISTING_FILE="$tmp_existing" \
  AGENTSMD_FRESH_FILE="$tmp_fresh" \
  node <<'NODE'
    const fs = require("fs");
    const existing = fs.readFileSync(process.env.AGENTSMD_EXISTING_FILE, "utf8");
    const fresh = fs.readFileSync(process.env.AGENTSMD_FRESH_FILE, "utf8");

    // Collect existing H2 headings so we can skip duplicates.
    const existingHeadings = new Set();
    for (const line of existing.split("\n")) {
      const m = line.match(/^## (.+)$/);
      if (m) existingHeadings.add(m[1].trim());
    }

    // Split fresh into [header, body]. Header = generation comment + blank
    // line(s) before the first "## " line.
    const freshLines = fresh.split("\n");
    let i = 0;
    while (i < freshLines.length && !freshLines[i].startsWith("## ")) i++;
    const freshHeader = freshLines.slice(0, i).join("\n").trim();

    // Existing body: strip the prior generation comment (if present) so we
    // don't keep stale headers, but preserve everything else verbatim.
    const existingLines = existing.split("\n");
    let existingBody;
    if (existingLines.length && /<!-- Generated by init-project/.test(existingLines[0])) {
      // Drop line 0 (comment) + any immediately-following blank line.
      let start = 1;
      while (start < existingLines.length && existingLines[start].trim() === "") start++;
      existingBody = existingLines.slice(start).join("\n").trim();
    } else {
      existingBody = existing.trim();
    }

    // Split fresh body into sections by H2 heading so we can append only
    // sections not already present (preserve existing content per FR-5.5).
    const freshBody = freshLines.slice(i).join("\n");
    const freshSections = [];
    let cur = null;
    for (const line of freshBody.split("\n")) {
      if (line.startsWith("## ")) {
        if (cur) freshSections.push(cur);
        cur = { heading: line.replace(/^## /, "").trim(), text: [line] };
      } else if (cur) {
        cur.text.push(line);
      }
    }
    if (cur) freshSections.push(cur);

    const appended = [];
    for (const s of freshSections) {
      if (!existingHeadings.has(s.heading)) {
        appended.push(s.text.join("\n").trim());
      }
    }

    // Compose: new generation comment + existing body + appended new sections.
    let out = freshHeader + "\n\n";
    out += existingBody + "\n\n";
    for (const s of appended) out += s + "\n\n";
    process.stdout.write(out);
NODE
  rm -f "$tmp_existing" "$tmp_fresh"
}

# ERR-2.1 atomic write: write content to a temp file in the same directory,
# then rename. Avoids partial-write corruption if the process is interrupted
# mid-write.
write_agents_md_atomic() {
  local target="$1"
  local content="$2"
  local target_dir
  target_dir="$(dirname "$target")"
  local tmp
  tmp="$(mktemp "${target_dir}/.agents.md.XXXXXX")"
  printf '%s' "$content" > "$tmp"
  mv -f "$tmp" "$target"
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

# --github-project-number positive-integer validation (CLI-2 type: Integer).
if ! validate_github_project_number "$opt_github_project_number"; then
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
ensure_github_project_config \
  "$project_dir" \
  "$worktree_root" \
  "$repo_name" \
  "$opt_name" \
  "$opt_description" \
  "$opt_repo_role" \
  "$opt_related_repos" \
  "$INIT_PROJECT_VERSION"
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

# --- SPEC-001 T3 (issue #4): AGENTS.md generation ---------------------------
# Runs after skills/config/docs writes per ERR-2.1 step 4 (AGENTS.md is the
# final artifact so "Local Configuration Files" can enumerate what was
# written). Implements FR-3 (interactive), FR-4 (noninteractive), FR-5
# (artifact contract), DM-2 (structure), ERR-3.2 (backup).
agents_md_target="$project_dir/AGENTS.md"

# 1. Run inspection (FR-2) unless --skip-inspection.
if [[ "$opt_skip_inspection" != "1" ]]; then
  INSPECTION_JSON="$(run_repo_inspection "$project_dir")"
else
  INSPECTION_JSON='{}'
fi

# 2. Resolve effective AGENTS.md inputs based on mode.
if [[ "$mode" == "interactive" ]]; then
  prompt_for_agents_md "$project_dir" "$repo_name" "$INSPECTION_JSON"
else
  # Noninteractive (FR-4): effective values come from opt_* (T2 resolution).
  AGENTSMD_EFF_PURPOSE="$opt_description"
  AGENTSMD_EFF_CONVENTIONS="$opt_conventions"
  AGENTSMD_EFF_COMMANDS="$opt_commands"
  AGENTSMD_EFF_RELATED_REPOS="$opt_related_repos"
  AGENTSMD_EFF_SCRATCH_DIR="${opt_scratch_dir:-./tmp/}"
  AGENTSMD_EFF_GITHUB_OWNER="$opt_github_owner"
  AGENTSMD_EFF_GITHUB_PROJECT_NUMBER="$opt_github_project_number"
  AGENTSMD_EFF_REPO_NAME="${opt_name:-$repo_name}"
  AGENTSMD_EFF_REPO_ROLE="$opt_repo_role"
fi

# 3. Existing-file policy (FR-5.5). Sets AGENTS_MD_ACTION global.
decide_existing_agents_md_action "$agents_md_target" "$mode" "$opt_force" "$opt_merge"

if [[ "$AGENTS_MD_ACTION" == "skip" ]]; then
  echo "[summary] AGENTS.md exists; skipped (use --force to overwrite, --force --merge to append)"
else
  # 4. Generate content. Env vars consumed by the inline node helper.
  AGENTS_MD_CONTENT="$(
    AGENTSMD_PROJECT_DIR="$project_dir" \
    AGENTSMD_REPO_NAME="$repo_name" \
    AGENTSMD_DOCS_ROOT="$docs_root" \
    AGENTSMD_VERSION="$INIT_PROJECT_VERSION" \
    AGENTSMD_INSPECTION="$INSPECTION_JSON" \
    AGENTSMD_EFF_PURPOSE="$AGENTSMD_EFF_PURPOSE" \
    AGENTSMD_EFF_CONVENTIONS="$AGENTSMD_EFF_CONVENTIONS" \
    AGENTSMD_EFF_COMMANDS="$AGENTSMD_EFF_COMMANDS" \
    AGENTSMD_EFF_RELATED_REPOS="$AGENTSMD_EFF_RELATED_REPOS" \
    AGENTSMD_EFF_SCRATCH_DIR="$AGENTSMD_EFF_SCRATCH_DIR" \
    AGENTSMD_EFF_GITHUB_OWNER="$AGENTSMD_EFF_GITHUB_OWNER" \
    AGENTSMD_EFF_GITHUB_PROJECT_NUMBER="$AGENTSMD_EFF_GITHUB_PROJECT_NUMBER" \
    AGENTSMD_EFF_REPO_NAME="$AGENTSMD_EFF_REPO_NAME" \
    AGENTSMD_EFF_REPO_ROLE="$AGENTSMD_EFF_REPO_ROLE" \
    generate_agents_md_content
  )"

  # 5. Interactive preview + confirmation (FR-3.4).
  if [[ "$mode" == "interactive" ]]; then
    echo "--- AGENTS.md preview ---"
    printf '%s\n' "$AGENTS_MD_CONTENT"
    echo "--- end preview ---"
    local_confirm=""
    while true; do
      safe_read "[prompt] Write AGENTS.md with the above content? [Y/n]: " local_confirm
      case "${local_confirm:-y}" in
        y|Y) break ;;
        n|N)
          echo "[summary] Operator declined AGENTS.md write"
          AGENTS_MD_ACTION="skip"
          break
          ;;
        *) echo "[prompt] Please answer y or n." >&2 ;;
      esac
    done
  fi

  # 6. Write (with backup if --force + existing — ERR-3.2).
  if [[ "$AGENTS_MD_ACTION" != "skip" ]]; then
    case "$AGENTS_MD_ACTION" in
      create)
        write_agents_md_atomic "$agents_md_target" "$AGENTS_MD_CONTENT"
        echo "[writing] AGENTS.md (new)"
        ;;
      overwrite)
        agents_md_backup="$(backup_agents_md "$agents_md_target")"
        write_agents_md_atomic "$agents_md_target" "$AGENTS_MD_CONTENT"
        echo "[writing] ${agents_md_backup} (backup of previous AGENTS.md)"
        echo "[writing] AGENTS.md (overwritten)"
        ;;
      merge)
        agents_md_backup="$(backup_agents_md "$agents_md_target")"
        existing_content="$(cat "$agents_md_target")"
        merged_content="$(merge_agents_md_content "$existing_content" "$AGENTS_MD_CONTENT")"
        write_agents_md_atomic "$agents_md_target" "$merged_content"
        echo "[writing] ${agents_md_backup} (backup of previous AGENTS.md)"
        echo "[writing] AGENTS.md (merged)"
        ;;
    esac
  fi
fi
