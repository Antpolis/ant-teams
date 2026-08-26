#!/usr/bin/env bash
#
# init-project.sh — project-local initialization engine (SPEC-001).
#
# Tooling-path contract (founder-approved 2026-08): the engine lives in
# templates/scripts/ and is installed by scripts/init-company.sh to
# ~/.agents/scripts/init-project.sh, with its support assets in the sibling
# init-project/ directory (github-project.env.template).
# The project-initialization skill wrapper was removed; the repo entry is the
# thin delegator scripts/init-project.sh → "$ANT_TEAM_SCRIPTS/init-project.sh".
#
# T2 (issue #3): CLI flag expansion, env-var resolution, TTY-based mode
# detection, and validation per CLI-2 / FR-4 / ERR-4.
# T3 (issue #4): AGENTS.md generation — default-only minimal baseline (FR-4),
# AGENTS.md artifact contract (FR-5 / DM-2 / ARCH-003 Artifact 2): timestamped
# header, DM-2.2 H2 sections, empty sections omitted (DM-2.3), "Local
# Configuration Files" always present, and pre-existing-file handling with
# overwrite/merge/skip + .bak.<ts> backup on --force (FR-5.5 / ERR-3.2).
# Env-only configuration contract (founder-confirmed 2026-08): the initializer
# seeds and updates `.github-project.env` (ANT_TEAM_* exports) directly — it is
# the sole committed project config source. There is no JSON config and no
# JSON import/removal path.
# T6 (issue #7): observability prefixes wired through every emit path (OBS-1),
# true no-write --dry-run (OBS-2), pre-flight validation (ERR-1), atomic
# write-temp-then-rename for every generated file (ERR-2.1), trap-based temp
# cleanup on EXIT/INT/TERM (ERR-2.3), content-level idempotency so --force
# reruns with identical inputs leave AGENTS.md byte-for-byte intact (TR-2),
# and the `cp -Rn` non-portable-warning replaced with a find-based merge.
#
set -euo pipefail

# Bumped 0.1.0 → 0.2.0 for T2 (CLI expansion). Bumped 0.2.0 → 0.3.0 for T3
# (AGENTS.md generation). Bumped 0.3.0 → 0.4.0 for T3 follow-up: removed
# Node inspection engine, shipped Bash default-only AGENTS.md generator,
# and retired node runtime requirement.
readonly INIT_PROJECT_VERSION="0.4.0"

# --- T6 (issue #7): OBS-1.2 counters + ERR-2.3 trap-based temp cleanup -----
# Counters are bumped by the emit_* helpers so the final [summary] line is
# always consistent with what the operator saw on stdout/stderr. They are
# initialized here and resolved at call time, so it is safe to define the
# helpers before Phase 2 resolves opt_dry_run.
stat_created=0
stat_merged=0
stat_skipped=0
stat_warnings=0
stat_would_write=0

# ERR-2.3: every scratch file lives under a single mktemp -d removed by the
# EXIT trap. Atomic-rename temps that must live in the target dir (same
# filesystem) are registered via register_cleanup so the same trap catches
# them on INT/TERM/EXIT. The trap is set ONCE here; later code MUST chain
# (append to cleanup_temp), never replace it (issue guardrail).
TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t init-project-docs)"
CLEANUP_FILES=()

cleanup_temp() {
  if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
    rm -rf "$TEMP_DIR"
  fi
  local f
  for f in "${CLEANUP_FILES[@]:-}"; do
    if [[ -n "$f" && -e "$f" ]]; then rm -f "$f"; fi
  done
}
trap cleanup_temp EXIT
trap 'cleanup_temp; exit 130' INT
trap 'cleanup_temp; exit 143' TERM

register_cleanup() {
  CLEANUP_FILES+=("$1")
}

# OBS-1.1 / OBS-2.1 helpers. emit_write swaps [writing] → [would-write] under
# --dry-run (OBS-2.1) and bumps stat_would_write instead of stat_created so
# the final summary reports the dry-run contract. emit_warning always goes to
# stderr (OBS-1.2) and counts warnings for the summary.
emit_write() {
  if [[ "${opt_dry_run:-0}" == "1" ]]; then
    echo "[would-write] $*"
    stat_would_write=$((stat_would_write + 1))
  else
    echo "[writing] $*"
    stat_created=$((stat_created + 1))
  fi
}

emit_merge() {
  if [[ "${opt_dry_run:-0}" == "1" ]]; then
    echo "[would-write] $* (merge)"
    stat_would_write=$((stat_would_write + 1))
  else
    echo "[writing] $* (merge)"
    stat_merged=$((stat_merged + 1))
  fi
}

emit_warning() {
  echo "[warning] $*" >&2
  stat_warnings=$((stat_warnings + 1))
}

emit_skip() {
  # Step-level skip notice (e.g. "AGENTS.md exists; skipped"). Uses the
  # [summary] prefix per the existing T3 contract and OBS-1.1 (there is no
  # dedicated [skip] prefix). Bumps stat_skipped for the final tally.
  echo "[summary] $*"
  stat_skipped=$((stat_skipped + 1))
}

# CLI-2 / FR-4.1 --repo-role enum (per issue guardrails + ARCH-003 schema).
readonly REPO_ROLE_VALID_VALUES="service library infra monorepo-root tool docs other"

usage() {
  cat <<'USAGE'
Usage:
  "$ANT_TEAM_SCRIPTS/init-project.sh" [options]

Copy the company docs into a project repo and create the local workflow-state
folder structure. T2 (issue #3) adds interactive/noninteractive mode selection,
env-var resolution, and full CLI-2 flag surface. T3 (issue #4) adds AGENTS.md
generation. T6 (issue #7) wires structured observability prefixes, true
no-write --dry-run, pre-flight validation, atomic writes, trap-based temp
cleanup, and content-level idempotency (--force reruns with identical inputs
are no-ops). The env-only configuration contract (2026-08) makes
.github-project.env the sole committed project config source.

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
  --github-owner OWNER        GitHub owner recorded in .github-project.env.
  --github-project-number N   GitHub Project number (positive integer; e.g. 9).

AGENTS.md shaping inputs (FR-4.1):
  --conventions TEXT|@FILE    Working conventions (multiline or @/path/to/file).
  --commands TEXT|@FILE       Build/test/run commands (multiline or @/path/to/file).
  --scratch-dir PATH          Scratch/log dir (default: ./tmp/).

Behavior modifiers (CLI-2):
  --force                     Overwrite existing AGENTS.md / re-copy skills.
                              Idempotent at the content level: a --force rerun
                              with identical inputs leaves AGENTS.md byte-for-byte
                              intact and creates no new .bak (TR-2.2).
  --merge                     Merge new content instead of overwriting.
                              Default: interactive=on, noninteractive=off.
  --dry-run                   Resolve and validate flags but suppress EVERY
                              write (OBS-2). Emits [would-write] lines and a
                              dry-run summary. No file is created or modified.

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
  "$ANT_TEAM_SCRIPTS/init-project.sh"

  # Noninteractive, fully specified (AC-T2-002)
  "$ANT_TEAM_SCRIPTS/init-project.sh" \
      --noninteractive \
      --name my-service --github-owner antpolis --github-project-number 9

  # Env var provides default; CLI flag overrides (AC-T2-004)
  INIT_PROJECT_GITHUB_OWNER=antpolis \
      "$ANT_TEAM_SCRIPTS/init-project.sh" \
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

# --- T6 (issue #7): ERR-1 pre-flight validation --------------------------------
# Runs BEFORE any file is written (ERR-1.1). Each failure exits 1 with a
# specific [error] message on stderr (ERR-1.2). The exit-1 path is reachable
# only before the write phase, so no partial state is ever left behind.
#
# Checks (ERR-1.1):
#   1. target project dir exists AND is a git repo (has .git/ or .git file)
#   2. the sibling managed skills root contains every required skill
#      (github-issues-projects-cli, do-task)
#   3. jq is on PATH — required by ensure_opencode_config (strict JSON gate)
#      and ensure_project_runtime_env (env seed/update) (OBS-3.2)
#   4. coreutils cp/mkdir/cat/rm/mktemp are on PATH
#
# The .git/ existence check (NOT `git rev-parse`) is deliberate: the init
# engine tests create a `.git/` directory marker in tmp fixtures, and
# ERR-1.1 only requires the marker to be present. A real `git rev-parse`
# check would reject those valid test fixtures and break T1-T5 suites.
run_preflight() {
  local project_dir_arg="$1"
  local managed_skills_root_arg="$2"

  # ERR-1.1 item 1: target dir exists + is a git repo (AC-T6-003).
  if [[ ! -d "$project_dir_arg" ]]; then
    echo "[error] Target project directory does not exist: $project_dir_arg" >&2
    echo "[error] Create it first (e.g. 'mkdir -p $project_dir_arg && cd $project_dir_arg && git init')" >&2
    exit 1
  fi
  if [[ ! -e "$project_dir_arg/.git" ]]; then
    echo "[error] Target project directory is not a git repository: $project_dir_arg" >&2
    echo "[error] '.git' not found — run 'git init' in the target before init-project (ERR-1.1)." >&2
    exit 1
  fi

  # ERR-1.1 item 2 / OBS-3.1: the sibling managed skills root contains every
  # required skill. This holds identically in the installed tooling layout
  # (~/.agents/scripts with skills at ~/.agents/skills after
  # scripts/init-company.sh) and in a source checkout (templates/scripts with
  # skills at templates/opencode/skills). Include the resolved path the script
  # actually checked so the operator can see why an init from a wrong
  # location failed.
  local required_skill
  for required_skill in github-issues-projects-cli do-task; do
    if [[ ! -d "$managed_skills_root_arg/$required_skill" ]]; then
      echo "[error] Required skill not found in the sibling skills root: $managed_skills_root_arg/$required_skill" >&2
      echo "[error] init-project must run from the team-scripts install (~/.agents/scripts/ after scripts/init-company.sh; skills at ~/.agents/skills) or a source checkout (templates/scripts/; skills at templates/opencode/skills) (OBS-3.1)." >&2
      echo "[error] Resolved sibling skills root: $managed_skills_root_arg" >&2
      exit 1
    fi
  done

  # ERR-1.1 item 3: jq on PATH — required by ensure_opencode_config (strict
  # JSON gate) and ensure_project_runtime_env (env seed/update).
  if ! command -v jq >/dev/null 2>&1; then
    echo "[error] jq is required but was not found on PATH." >&2
    echo "[error] jq is used by ensure_opencode_config (strict JSON validation)" >&2
    echo "[error] and ensure_project_runtime_env (env seed/update) (OBS-3.2)." >&2
    echo "[error] Install jq and re-run." >&2
    exit 1
  fi

  # ERR-1.1 item 4: coreutils presence.
  local util
  for util in cp mkdir cat rm mktemp; do
    if ! command -v "$util" >/dev/null 2>&1; then
      echo "[error] Required coreutil '$util' not found on PATH (ERR-1.1)." >&2
      exit 1
    fi
  done
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
  fi

  # FRESH-repo path: no existing config anywhere — create the canonical
  # minimal file at .opencode/opencode.json (ARCH-003 Artifact 4). In dry-run
  # we report what WOULD be created and skip the mkdir + write (OBS-2.1).
  if [[ -z "$config_path" ]]; then
    local would_create="$project_dir/.opencode/opencode.json"
    local would_create_rel="${would_create#$project_dir/}"
    if [[ "${opt_dry_run:-0}" == "1" ]]; then
      echo "[would-write] ${would_create_rel} (minimal opencode config)"
      stat_would_write=$((stat_would_write + 1))
      return 0
    fi
    # mkdir -p is idempotent and never complains if the directory already
    # exists (SEC-3.1: mkdir -p is an allowed primitive).
    mkdir -p "$project_dir/.opencode"
    config_path="$would_create"
    write_file_atomic "$config_path" '{
  "permission": {
    "external_directory": {}
  }
}
'
    emit_write "${would_create_rel} (minimal opencode config)"
    # Fresh minimal config has no external_directory entry yet — fall through
    # to the merge step so the worktree pattern is added in the same run.
  fi

  local config_rel="${config_path#$project_dir/}"

  # STRICT JSON GATE: jq validates strict JSON only. Comments and trailing
  # commas are rejected with a clear error (AC-03). No Node, no Go, no JSONC
  # parser — jq is the sole JSON mechanism.
  #
  # COMPUTE-ONLY jq helper (no writes). It prints one of:
  #   NO_CHANGE\n            — external_directory entry already present
  #   WRITE\n<content>       — merge needed; bash does the atomic write below
  #   MALFORMED\n<message>   — file is not strict JSON; bash exits 1
  # Splitting compute (jq) from write (bash) lets bash own the atomic
  # temp+rename AND register the temp with the EXIT trap (ERR-2.1 / ERR-2.3).
  local jq_rc
  local jq_out
  jq_out="$(jq --arg pat "$external_pattern" '
    if (.permission | type) != "object" then true
    elif (.permission.external_directory | type) != "object" then true
    elif .permission.external_directory[$pat] == "allow" then false
    else true
    end
  ' "$config_path" 2>/tmp/jq_err_$$)" && jq_rc=0 || jq_rc=$?

  if [[ "$jq_rc" -eq 5 ]]; then
    # jq exit 5 = parse error (not strict JSON).
    local jq_err
    jq_err="$(cat /tmp/jq_err_$$ 2>/dev/null || true)"
    rm -f /tmp/jq_err_$$
    echo "[error] Malformed $config_rel: not strict JSON — $jq_err" >&2
    echo "[error] Remove comments and trailing commas, then re-run; init will not overwrite a non-JSON file." >&2
    exit 1
  elif [[ "$jq_rc" -ne 0 ]]; then
    rm -f /tmp/jq_err_$$
    echo "[error] jq error validating $config_rel (exit $jq_rc)" >&2
    exit 1
  fi
  rm -f /tmp/jq_err_$$

  if [[ "$jq_out" == "false" ]]; then
    echo "[summary] $config_rel already allows $external_pattern; no changes needed"
    return 0
  fi

  # Build the updated config via jq.
  local content
  content="$(jq --arg pat "$external_pattern" '
    if (.permission | type) != "object" then .permission = {} else . end |
    if (.permission.external_directory | type) != "object" then .permission.external_directory = {} else . end |
    .permission.external_directory[$pat] = "allow"
  ' "$config_path")"

  if [[ "${opt_dry_run:-0}" == "1" ]]; then
    echo "[would-write] $config_rel (external_directory entry for $external_pattern)"
    stat_would_write=$((stat_would_write + 1))
    return 0
  fi

  write_file_atomic "$config_path" "$content"
  emit_write "$config_rel (external_directory entry for $external_pattern)"
  return 0
}

# T6 (issue #7) / ERR-2.1 atomic write helper. Writes CONTENT to TARGET via a
# temp file in the SAME directory (same-filesystem atomic rename), then mv -f.
# The temp path is registered with the EXIT trap so an interrupt between write
# and rename is cleaned up (ERR-2.3). Used for opencode.json, .github-project.env,
# and AGENTS.md writes so every generated file shares the same atomic guarantee.
write_file_atomic() {
  local target="$1"
  local content="$2"
  local target_dir
  target_dir="$(dirname "$target")"
  local tmp
  tmp="$(mktemp "${target_dir}/.$(basename "$target").XXXXXX")"
  register_cleanup "$tmp"
  printf '%s' "$content" > "$tmp"
  mv -f "$tmp" "$target"
}

# T6 (issue #7): portable recursive copy that skips existing target files.
# Replaces `cp -Rn` (GNU coreutils ≥9 emits a non-portable-warning on every
# invocation; the warning was pre-existing and is owned by T6). Semantics are
# identical to `cp -Rn`: never overwrite, only create missing files. Uses
# `cp -p` so the source execute bit is preserved (SEC-3.2) — the same
# primitive copy_required_skills uses for skills.
copy_tree_no_clobber() {
  local src="$1"
  local dst="$2"
  [[ -d "$src" ]] || return 0
  mkdir -p "$dst"
  while IFS= read -r -d '' src_file; do
    local rel="${src_file#"$src"/}"
    local tgt="$dst/$rel"
    [[ -e "$tgt" ]] && continue
    mkdir -p "$(dirname "$tgt")"
    cp -p "$src_file" "$tgt"
  done < <(find "$src" -type f -print0)
}

# T6 (issue #7) / TR-2.2: strip the generation-comment header (line 1) from
# AGENTS.md content so two generations with identical inputs compare equal
# even though the ISO 8601 timestamp differs. This is what makes --force
# idempotent at the content level: if nothing but the timestamp would
# change, the caller skips the rewrite and preserves the existing file
# byte-for-byte (TR-2.1 — no new timestamps on identical reruns).
strip_agents_md_header() {
  awk 'NR==1 && /^<!-- Generated by init-project/ {next} {print}' "$1"
}

# FR-7.4 / AC-T4-006: ensure `.opencode/.gitignore` exists with a `node_modules`
# entry so generated dependencies are never committed accidentally. Existing
# entries are preserved verbatim; only the missing `node_modules` line is added.
ensure_opencode_gitignore() {
  local opencode_dir="$1"
  local gitignore_path="$opencode_dir/.gitignore"
  local required_entry="node_modules"

  # Dry-run (OBS-2): report what would be written; do not mkdir or write.
  if [[ ! -f "$gitignore_path" ]]; then
    if [[ "${opt_dry_run:-0}" == "1" ]]; then
      echo "[would-write] .opencode/.gitignore"
      stat_would_write=$((stat_would_write + 1))
      return 0
    fi
    mkdir -p "$opencode_dir"
    write_file_atomic "$gitignore_path" "${required_entry}"$'\n'
    emit_write ".opencode/.gitignore"
    return 0
  fi

  if ! grep -Fxq "$required_entry" "$gitignore_path" 2>/dev/null; then
    if [[ "${opt_dry_run:-0}" == "1" ]]; then
      echo "[would-write] .opencode/.gitignore (node_modules entry added)"
      stat_would_write=$((stat_would_write + 1))
      return 0
    fi
    # Append-only: read current, append entry, write atomically so an
    # interrupt mid-write cannot truncate the existing gitignore.
    local current
    current="$(cat "$gitignore_path")"
    write_file_atomic "$gitignore_path" "${current}"$'\n'"${required_entry}"$'\n'
    emit_write ".opencode/.gitignore (node_modules entry added)"
  fi
}

# FR-7.1 / FR-7.2 / FR-7.3 / SEC-3.2 / ARCH-003 guarantee 4: copy the two
# required script-bearing skills (github-issues-projects-cli, do-task) from
# the sibling managed skills root into the project-local `.opencode/skills/`
# directory. The sibling root is resolved next to the engine's install
# location: ~/.agents/skills in the team-scripts install, or
# templates/opencode/skills in a source checkout — the copy source is
# identical in both locations. Copy is a per-file merge: every regular source
# file is copied when absent at target and preserved when already present
# (this is what protects project-customized SKILL.md files). No other skill
# is ever copied. (The project-initialization skill was removed from the
# copy contract with the tooling-path migration: the engine now lives at
# $ANT_TEAM_SCRIPTS/init-project.sh and is not re-installed into targets.)
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
  local managed_skills_root="$2"
  local source_skills_dir="$managed_skills_root"
  local target_skills_dir="$project_dir/.opencode/skills"
  local -a required_skills=(
    "github-issues-projects-cli"
    "do-task"
  )
  local -a excluded_skills=(
    "skill-creator"
    "webapp-testing"
    "doc-coauthoring"
    "frontend-design"
  )

  # Dry-run (OBS-2): do not create directories or copy files. Still walk the
  # source tree so [would-write] lines reflect exactly what a real run writes.
  if [[ "${opt_dry_run:-0}" != "1" ]]; then
    mkdir -p "$target_skills_dir"
  fi
  ensure_opencode_gitignore "$project_dir/.opencode"

  local total_copied=0
  local total_merged=0

  for skill_name in "${required_skills[@]}"; do
    local src_skill_dir="$source_skills_dir/$skill_name"
    local tgt_skill_dir="$target_skills_dir/$skill_name"

    if [[ ! -d "$src_skill_dir" ]]; then
      emit_warning "Required skill source not found: $src_skill_dir"
      continue
    fi

    if [[ "${opt_dry_run:-0}" != "1" ]]; then
      mkdir -p "$tgt_skill_dir"
    fi

    while IFS= read -r -d '' src_file; do
      local rel="${src_file#"$src_skill_dir"/}"
      local tgt_file="$tgt_skill_dir/$rel"

      if [[ -e "$tgt_file" ]]; then
        # FR-7.3: merge, do not overwrite. Protects customized SKILL.md and
        # any other project-local override.
        total_merged=$((total_merged + 1))
        continue
      fi

      if [[ "${opt_dry_run:-0}" == "1" ]]; then
        echo "[would-write] .opencode/skills/$skill_name/$rel"
        stat_would_write=$((stat_would_write + 1))
      else
        mkdir -p "$(dirname "$tgt_file")"
        # SEC-3.2: `cp -p` preserves the source execute bit.
        cp -p "$src_file" "$tgt_file"
        echo "[writing] .opencode/skills/$skill_name/$rel"
        stat_created=$((stat_created + 1))
      fi
      total_copied=$((total_copied + 1))
    done < <(find "$src_skill_dir" -type f -print0)
  done

  # FR-7.2: defensive check that no excluded skill directory is present at
  # target. We never write them; this only catches pre-existing stray dirs
  # that would otherwise masquerade as initializer output.
  for excluded in "${excluded_skills[@]}"; do
    if [[ -d "$target_skills_dir/$excluded" ]]; then
      emit_warning "Excluded skill already present in target: .opencode/skills/$excluded"
    fi
  done

  # Per-skill summary line (OBS-1.1 — uses the same prefix family so agents
  # can grep [writing] / [would-write] uniformly).
  if [[ "${opt_dry_run:-0}" == "1" ]]; then
    echo "[would-write] .opencode/skills/ (${#required_skills[@]} required skills, $total_copied would-copy, $total_merged merged)"
  else
    echo "[writing] .opencode/skills/ (${#required_skills[@]} required skills, $total_copied copied, $total_merged merged)"
  fi
}

# --- Env-only project runtime configuration -------------------------------------
# Founder-confirmed contract (2026-08): `.github-project.env` (ANT_TEAM_* shell
# exports) is the SOLE committed project config source. The initializer seeds
# and updates it DIRECTLY:
#
#   - Fresh repo: seed the full canonical key set. Operator flags fill values
#     where provided; the rest get clearly-marked placeholders the founder
#     replaces with verified values (init has no network access and must not
#     invent real-looking IDs).
#   - Existing env: FOUNDER VALUES ARE PRESERVED. Only missing keys are filled
#     (placeholders/defaults); the canonical header is normalized. Nothing the
#     founder set is ever overwritten.
#     import/removal path — the env is the only config the initializer reads or
#     writes.
#   - ANT_TEAM_DOCS_PROJECT_NAME defaults to the detected git repository name
#     (basename of the project root), never overriding a founder value.
#
# The seed/update is computed with jq (compute) + bash (write). Output is
# deterministic (no timestamps); an unchanged env is never rewritten (stable
# mtime, byte-for-byte idempotent).
#
# Canonical Workflow State model: the nine option keys below (open, backlog,
# need-attentions, ready, in-progress, in-review, ready-to-merge, blocked,
# done) are the canonical state set, mirrored as constants in skills, tests,
# and docs — not as a config field.
#
# Parameter contract:
#   $1 project_dir                — target project root (canonicalized)
#   $2 worktree_root              — canonical absolute worktree root path
#   $3 repo_name                  — detected repo name (basename of project root)
#   $4 opt_github_owner           — --github-owner seed value (may be empty)
#   $5 opt_github_project_number  — --github-project-number seed value (may be empty)
ensure_project_runtime_env() {
  local project_dir="$1"
  local worktree_root="$2"
  local repo_name="$3"
  local opt_github_owner="$4"
  local opt_github_project_number="$5"
  local env_template="$6"
  local env_path="$project_dir/.github-project.env"

  # jq @sh equivalent: single-quote a value for a sourceable shell file.
  shq() { printf "'%s'" "${1//\'/\'\\\'\'}"; }
  nonempty() { [[ -n "$1" ]]; }

  # Option keys normalize to uppercase underscore variable-name fragments
  # (ASCII-only upcase; non-alphanumerics -> "_"), e.g. "in-progress" ->
  # IN_PROGRESS, "need-attentions" -> NEED_ATTENTIONS.
  opt_key() {
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g'
  }

  # --- parse the existing env (founder-owned values) ---------------------------
  # Recognized lines: export NAME='<single-quoted value>' (' escaped as '\'').
  # Unrecognized non-comment lines are preserved verbatim at the end so a
  # founder edit is never silently dropped on rewrite.
  local -a env_order=()
  local -A env_map=()
  local -a foreign_lines=()

  if [[ -f "$env_path" ]]; then
    while IFS= read -r line; do
      if [[ "$line" =~ ^export\ ([A-Za-z0-9_]+)=\'(.*)\'$ ]]; then
        local name="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]//\'\\\'\'/\'}"
        if [[ -z "${env_map[$name]+x}" ]]; then
          env_order+=("$name")
          env_map[$name]="$value"
        fi
      else
        local trimmed="${line// /}"
        if [[ -n "$trimmed" && "$line" != "#"* ]]; then
          foreign_lines+=("$line")
        fi
      fi
    done < "$env_path"
  fi

  # first non-empty source wins: env (founder) -> operator flag ->
  # placeholder/default.
  pick() {
    local v
    for v in "$@"; do
      if [[ -n "$v" ]]; then
        printf '%s' "$v"
        return
      fi
    done
  }

  # Canonical option key sets (mirrored in skills/tests/docs constants).
  # The legacy "Status" field and its STATUS_* env keys are retired: the board
  # is driven only by the Workflow State field and its options.
  local -a WORKFLOW_STATE_OPTION_KEYS=(
    "open"
    "backlog"
    "need-attentions"
    "ready"
    "in-progress"
    "in-review"
    "ready-to-merge"
    "blocked"
    "done"
  )

  local owner
  owner="$(pick "${env_map[ANT_TEAM_GITHUB_OWNER]:-}" "$opt_github_owner" "your-github-owner")"

  # Use jq to build the values JSON deterministically.
  local values_json
  values_json="$(jq -n \
    --arg owner "$owner" \
    --arg owner_type "$(pick "${env_map[ANT_TEAM_GITHUB_OWNER_TYPE]:-}" "org")" \
    --arg repo "$(pick "${env_map[ANT_TEAM_GITHUB_REPO]:-}" "${owner}/${repo_name}")" \
    --arg project_number "$(pick "${env_map[ANT_TEAM_GITHUB_PROJECT_NUMBER]:-}" "$opt_github_project_number" "1")" \
    --arg project_id "$(pick "${env_map[ANT_TEAM_GITHUB_PROJECT_ID]:-}" "PVT_kwDOEXAMPLE")" \
    --arg ws_field_id "$(pick "${env_map[ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID]:-}" "workflow-state-field-id")" \
    --arg worktree_root "$worktree_root" \
    --arg docs_vault "$(pick "${env_map[ANT_TEAM_DOCS_VAULT_PATH]:-}" "")" \
    --arg docs_project_name "$(pick "${env_map[ANT_TEAM_DOCS_PROJECT_NAME]:-}" "$repo_name")" \
    --arg docs_repository "$(pick "${env_map[ANT_TEAM_DOCS_REPOSITORY]:-}" "")" \
    --arg github_owner "$owner" \
    '{
      ANT_TEAM_GITHUB_OWNER: $owner,
      ANT_TEAM_GITHUB_OWNER_TYPE: $owner_type,
      ANT_TEAM_GITHUB_REPO: $repo,
      ANT_TEAM_GITHUB_PROJECT_NUMBER: $project_number,
      ANT_TEAM_GITHUB_PROJECT_ID: $project_id,
      ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID: $ws_field_id,
      ANT_TEAM_WORKTREE_ROOT: $worktree_root,
      ANT_TEAM_DOCS_PROJECT_NAME: $docs_project_name,
    }')"

  # Build workflow state option lines.
  local -a ws_option_entries=()
  local -A emitted_vars=()
  for key in "${WORKFLOW_STATE_OPTION_KEYS[@]}"; do
    local var_name="ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_$(opt_key "$key")_ID"
    local val
    val="$(pick "${env_map[$var_name]:-}" "${key}-option-id")"
    ws_option_entries+=("$var_name=$val")
    emitted_vars[$var_name]=1
  done

  # Founder-defined extra option entries in the existing env.
  for name in "${env_order[@]}"; do
    if [[ -z "${emitted_vars[$name]+x}" ]]; then
      if [[ "$name" == ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_*_ID ]] && nonempty "${env_map[$name]:-}"; then
        ws_option_entries+=("$name=${env_map[$name]}")
        emitted_vars[$name]=1
      fi
    fi
  done

  # Add workflow state option values to the JSON via jq.
  for entry in "${ws_option_entries[@]}"; do
    local var_name="${entry%%=*}"
    local val="${entry#*=}"
    values_json="$(printf '%s' "$values_json" | jq --arg k "$var_name" --arg v "$val" '. + {($k): $v}')"
  done

  # Documentation path resolution.
  local docs_vault_path="" docs_repository="" docs_project_path=""
  if [[ -f "$env_template" ]]; then
    docs_vault_path="$(sed -n "s/^export ANT_TEAM_DOCS_VAULT_PATH='\(.*\)'/\1/p" "$env_template" | sed "s|__HOME__|$HOME|g")"
    docs_repository="$(sed -n "s/^export ANT_TEAM_DOCS_REPOSITORY='\(.*\)'/\1/p" "$env_template" | sed "s|__GITHUB_OWNER__|$owner|g")"
  fi
  docs_vault_path="$(pick "${env_map[ANT_TEAM_DOCS_VAULT_PATH]:-}" "$docs_vault_path")"
  docs_repository="$(pick "${env_map[ANT_TEAM_DOCS_REPOSITORY]:-}" "$docs_repository")"

  # docs_project_path: resolve as VAULT_PATH/02-Architecture-Landscape/projects/PROJECT_NAME when both are set.
  if nonempty "$docs_vault_path" && nonempty "${env_map[ANT_TEAM_DOCS_PROJECT_NAME]:-$repo_name}"; then
    docs_project_path="$(pick "${env_map[ANT_TEAM_DOCS_PROJECT_PATH]:-}" "${docs_vault_path}/02-Architecture-Landscape/projects/${env_map[ANT_TEAM_DOCS_PROJECT_NAME]:-$repo_name}")"
  else
    docs_project_path="$(pick "${env_map[ANT_TEAM_DOCS_PROJECT_PATH]:-}" "")"
  fi

  values_json="$(printf '%s' "$values_json" | jq \
    --arg vault "$docs_vault_path" \
    --arg repo "$docs_repository" \
    --arg path "$docs_project_path" \
    '. + {
      ANT_TEAM_DOCS_VAULT_PATH: $vault,
      ANT_TEAM_DOCS_REPOSITORY: $repo,
      ANT_TEAM_DOCS_PROJECT_PATH: $path,
    }')"

  # Canonical output order (stable, deterministic).
  local -a ordered_names=(
    "ANT_TEAM_GITHUB_OWNER"
    "ANT_TEAM_GITHUB_OWNER_TYPE"
    "ANT_TEAM_GITHUB_REPO"
    "ANT_TEAM_GITHUB_PROJECT_NUMBER"
    "ANT_TEAM_GITHUB_PROJECT_ID"
    "ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID"
  )
  for entry in "${ws_option_entries[@]}"; do
    ordered_names+=("${entry%%=*}")
  done
  ordered_names+=(
    "ANT_TEAM_WORKTREE_ROOT"
    "ANT_TEAM_DOCS_VAULT_PATH"
    "ANT_TEAM_DOCS_PROJECT_NAME"
    "ANT_TEAM_DOCS_REPOSITORY"
    "ANT_TEAM_DOCS_PROJECT_PATH"
  )

  # Build the content line by line.
  local header="# Project runtime configuration (ANT_TEAM_* exports) — the sole committed project config source.
# Seeded and updated by init-project: existing values are preserved, missing keys are filled.
# Edit values directly; re-running init-project never overwrites a value already set here.
# Safe to commit: shared project metadata only, no secrets."

  local -a lines=()
  for name in "${ordered_names[@]}"; do
    local val
    val="$(printf '%s' "$values_json" | jq -r --arg k "$name" '.[$k] // ""')"
    if nonempty "$val"; then
      lines+=("export ${name}=$(shq "$val")")
    fi
  done

  # Preserve founder-added keys that are not part of the canonical set.
  local -A canonical_set=()
  for name in "${ordered_names[@]}"; do
    canonical_set[$name]=1
  done
  for name in "${env_order[@]}"; do
    if [[ -z "${canonical_set[$name]+x}" ]] && nonempty "${env_map[$name]:-}"; then
      lines+=("export ${name}=$(shq "${env_map[$name]}")")
    fi
  done

  # Assemble content.
  local content="${header}"$'\n\n'
  local l
  for l in "${lines[@]}"; do
    content+="${l}"$'\n'
  done
  if [[ ${#foreign_lines[@]} -gt 0 ]]; then
    for l in "${foreign_lines[@]}"; do
      content+="${l}"$'\n'
    done
  fi

  # Determine verdict via byte-preserving comparison (cmp -s). Command
  # substitution strips trailing newlines, so `existing="$(cat ...)"` would
  # never match a content that ends with a newline.
  local verdict=""
  if [[ ! -f "$env_path" ]]; then
    verdict="CREATE"
  else
    local tmp_cmp
    tmp_cmp="$(mktemp)"
    printf '%s' "$content" > "$tmp_cmp"
    if cmp -s "$env_path" "$tmp_cmp"; then
      verdict="NO_CHANGE"
    else
      verdict="UPDATE"
    fi
    rm -f "$tmp_cmp"
  fi

  case "$verdict" in
    NO_CHANGE)
      echo "[summary] .github-project.env already up to date"
      stat_skipped=$((stat_skipped + 1))
      ;;
    CREATE|UPDATE)
      if [[ "${opt_dry_run:-0}" == "1" ]]; then
        echo "[would-write] .github-project.env (ANT_TEAM_* runtime config)"
        stat_would_write=$((stat_would_write + 1))
      else
        write_file_atomic "$env_path" "$content"
        if [[ "$verdict" == "CREATE" ]]; then
          emit_write ".github-project.env (ANT_TEAM_* runtime config)"
        else
          emit_merge ".github-project.env (missing keys filled; founder values preserved)"
        fi
      fi
      ;;
    *)
      echo "[error] Unexpected decision from .github-project.env helper: '$verdict'" >&2
      exit 1
      ;;
  esac
}

# ===========================================================================
# SPEC-001 T3 (issue #4): AGENTS.md generation — default-only minimal baseline.
#
# Implements FR-4 (noninteractive flag-driven generation), FR-5 (AGENTS.md
# artifact contract), DM-2 (AGENTS.md structure), ERR-3.2 (--force backup),
# and ARCH-003 Artifact 2 guarantees.
#
# The generator produces a minimal baseline with no inspection-derived content
# and no interactive prompts. Operator prompt flags (--description/--conventions
# /--commands/--related-repos/--repo-role) are accepted for CLI compatibility
# but no longer drive AGENTS.md section content.
#
# Flow (invoked from main after skills/config/docs writes per ERR-2.1 step 4;
# AGENTS.md is the final artifact so "Local Configuration Files" can enumerate
# what was written):
#   1. generate_agents_md_content → minimal baseline markdown via Bash.
#   2. decide_existing_agents_md_action → skip unless --force (FR-5.5).
#   3. backup_agents_md + write (overwrite) or merge (FR-5.5 / ERR-3.2).
# ===========================================================================

# Default-only AGENTS.md generator. Produces a minimal baseline the operator
# customizes through conversation. No inspection, no prompts, no positional
# parameters — reads from the caller's AGENTSMD_* env vars.
generate_agents_md_content() {
  local project_dir="${AGENTSMD_PROJECT_DIR:-.}"
  local repo_name="${AGENTSMD_REPO_NAME:-}"
  local version="${AGENTSMD_VERSION:-}"
  local scratch_dir="${AGENTSMD_SCRATCH_DIR:-}"

  # Read env values for documentation routing and GitHub config.
  local vault_path="" project_path="" gh_owner="" gh_project=""
  if [[ -f "$project_dir/.github-project.env" ]]; then
    vault_path="$(sed -n "s/^export ANT_TEAM_DOCS_VAULT_PATH='\(.*\)'/\1/p" "$project_dir/.github-project.env" 2>/dev/null || true)"
    project_path="$(sed -n "s/^export ANT_TEAM_DOCS_PROJECT_PATH='\(.*\)'/\1/p" "$project_dir/.github-project.env" 2>/dev/null || true)"
    gh_owner="$(sed -n "s/^export ANT_TEAM_GITHUB_OWNER='\(.*\)'/\1/p" "$project_dir/.github-project.env" 2>/dev/null || true)"
    gh_project="$(sed -n "s/^export ANT_TEAM_GITHUB_PROJECT_NUMBER='\(.*\)'/\1/p" "$project_dir/.github-project.env" 2>/dev/null || true)"
    # Filter placeholder values.
    [[ "$gh_owner" == "your-github-owner" ]] && gh_owner=""
    [[ "$gh_project" == "1" ]] && gh_project=""
  fi

  # Resolve scratch directory: passed value > env > default.
  if [[ -z "$scratch_dir" ]]; then
    scratch_dir="$(sed -n "s/^export ANT_TEAM_SCRATCH_DIR='\(.*\)'/\1/p" "$project_dir/.github-project.env" 2>/dev/null || true)"
  fi
  if [[ -z "$scratch_dir" ]]; then
    scratch_dir="./tmp/"
  fi

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"

  cat <<EOF
<!-- Generated by init-project v${version} on ${ts} — edit freely -->

## Repository Identity

${repo_name}

## Documentation

Central Obsidian documentation vault: \`\$ANT_TEAM_DOCS_VAULT_PATH\` from \`.github-project.env\` (currently \`${vault_path:-not set}\`)
EOF

  if [[ -n "$project_path" ]]; then
    printf '\nProject documentation path: `$ANT_TEAM_DOCS_PROJECT_PATH` from `.github-project.env` (currently `%s`)\n' "$project_path"
  else
    printf '\nProduct documentation is stored in the central Obsidian vault; this repository keeps only code-adjacent guidance.\n'
  fi

  cat <<EOF

## Scratch and Log Directories

Scratch directory for work-in-progress and logs: \`${scratch_dir}\`

## GitHub Project Helper

When GitHub Issues, Projects, milestones, pull requests, or workflow-state operations require the repository helper, load the \`github-issues-projects-cli\` skill first. Use the helper commands documented by that skill; do not hard-code or hunt for the helper shell-script path in agent instructions. Source \`.github-project.env\` before using the skill.
EOF

  # Append optional sections only when real values exist.
  if [[ -n "$gh_owner" || -n "$gh_project" ]]; then
    printf '\n## GitHub Project Configuration\n\n'
    [[ -n "$gh_owner" ]] && printf 'GitHub owner: `%s`\n' "$gh_owner"
    [[ -n "$gh_project" ]] && printf 'GitHub project number: `%s`\n' "$gh_project"
    printf '\n'
  fi

  # Local Configuration Files (DM-2.4 — always present).
  printf '%s\n' '## Local Configuration Files'
  printf '\n'
  printf '%s\n' '- `AGENTS.md` — This file — canonical agent guidance for this repository'
  if [[ -f "$project_dir/.github-project.env" ]]; then
    printf '%s\n' '- `.github-project.env` — ANT_TEAM_* runtime exports — the sole project config source; source it for GitHub, documentation, and worktree metadata'
  fi
  # Detect opencode config path.
  local oc_path=""
  for c in .opencode/opencode.json .opencode/opencode.jsonc opencode.jsonc opencode.json; do
    if [[ -f "$project_dir/$c" ]]; then oc_path="$c"; break; fi
  done
  if [[ -n "$oc_path" ]]; then
    printf '%s\n' "- \`${oc_path}\` — OpenCode runtime config"
  fi
  printf '\n'
}

# FR-5.5: decide how to handle a pre-existing AGENTS.md. Sets the global
# AGENTS_MD_ACTION to one of: "create", "skip", "overwrite", or "merge".
# Noninteractive: skip unless --force (FR-5.5).
decide_existing_agents_md_action() {
  local target="$1"
  local force_arg="$2"
  local merge_arg="$3"

  if [[ ! -f "$target" ]]; then
    AGENTS_MD_ACTION="create"
    return 0
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
# Implemented with awk/sed — no Node dependency.
merge_agents_md_content() {
  local existing_content="$1"
  local fresh_content="$2"
  # T6 / ERR-2.3: scratch files live under the trap-managed TEMP_DIR so any
  # interrupt is cleaned up by the EXIT trap.
  local tmp_existing="$TEMP_DIR/agents-merge-existing"
  local tmp_fresh="$TEMP_DIR/agents-merge-fresh"
  # Use printf '%s\n' to ensure trailing newline (command substitution
  # strips trailing newlines from cat).
  printf '%s\n' "$existing_content" > "$tmp_existing"
  printf '%s\n' "$fresh_content" > "$tmp_fresh"

  # Collect existing H2 headings, strip old header from existing, split fresh
  # into header + sections, and compose merged output — all in one awk pass.
  AGENTSMD_EXISTING_FILE="$tmp_existing" \
  AGENTSMD_FRESH_FILE="$tmp_fresh" \
  awk '
    BEGIN { existing_file = ENVIRON["AGENTSMD_EXISTING_FILE"]; fresh_file = ENVIRON["AGENTSMD_FRESH_FILE"] }

    # Pass 1: read existing file, collect H2 headings and body.
    FNR == NR && FILENAME == existing_file {
      existing_lines[FNR] = $0
      existing_count = FNR
      if ($0 ~ /^## /) {
        heading = $0
        sub(/^## /, "", heading)
        gsub(/^[ \t]+|[ \t]+$/, "", heading)
        existing_headings[heading] = 1
      }
      next
    }

    # Pass 2: read fresh file.
    {
      fresh_lines[FNR] = $0
      fresh_count = FNR
    }

    END {
      # Find fresh header (comment + blank lines before first ##).
      fresh_header_end = 0
      for (i = 1; i <= fresh_count; i++) {
        if (fresh_lines[i] ~ /^## /) { fresh_header_end = i - 1; break }
        if (i == fresh_count) fresh_header_end = fresh_count
      }
      # Print fresh header.
      for (i = 1; i <= fresh_header_end; i++) {
        if (fresh_lines[i] != "") print fresh_lines[i]
      }
      print ""

      # Existing body: strip old generation comment if present.
      start = 1
      if (existing_count > 0 && existing_lines[1] ~ /<!-- Generated by init-project/) {
        start = 2
        while (start <= existing_count && existing_lines[start] ~ /^[ \t]*$/) start++
      }
      # Print existing body.
      for (i = start; i <= existing_count; i++) print existing_lines[i]
      print ""

      # Parse fresh sections and append those not already present.
      in_section = 0
      cur_heading = ""
      cur_text = ""
      for (i = fresh_header_end + 1; i <= fresh_count; i++) {
        line = fresh_lines[i]
        if (line ~ /^## /) {
          # Flush previous section if any.
          if (in_section && !(cur_heading in existing_headings)) {
            print cur_text
            print ""
          }
          heading = line
          sub(/^## /, "", heading)
          gsub(/^[ \t]+|[ \t]+$/, "", heading)
          cur_heading = heading
          cur_text = line
          in_section = 1
        } else if (in_section) {
          cur_text = cur_text "\n" line
        }
      }
      # Flush last section.
      if (in_section && !(cur_heading in existing_headings)) {
        print cur_text
        print ""
      }
    }
  ' "$tmp_existing" "$tmp_fresh"
  # Scratch files are under TEMP_DIR → cleaned by the EXIT trap (ERR-2.3).
}

# AGENTS.md atomic write is now the shared write_file_atomic helper (T6).
# Kept as a thin wrapper so existing call sites and tests referencing this
# name continue to work; the write is atomic + trap-cleaned via the shared
# helper (ERR-2.1 / ERR-2.3).
write_agents_md_atomic() {
  write_file_atomic "$1" "$2"
}

# Engine install root: the directory this script lives in — either the
# team-scripts install (~/.agents/scripts, populated by scripts/init-company.sh
# from templates/scripts/) or a source checkout (templates/scripts). Support
# assets (github-project.env.template) ship in the sibling init-project/
# directory next to the engine.
engine_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
engine_assets="$engine_root/init-project"

# Sibling managed skills root: where the required skills live relative to the
# engine. Two layouts are supported, resolved by first match:
#   1. team-scripts install:  <engine_root>/../skills      (~/.agents/skills)
#   2. source checkout:       <engine_root>/../opencode/skills
#                             (templates/scripts/../opencode/skills)
# The engine must run correctly from BOTH locations (tests drive the source
# checkout directly; production invokes "$ANT_TEAM_SCRIPTS/init-project.sh"),
# so required-skill discovery resolves from the engine's install root — never
# from a CWD-derived path. When neither candidate exists, the first candidate
# is kept so run_preflight reports the expected install location.
managed_skills_root="$engine_root/../skills"
if [[ ! -d "$managed_skills_root" && -d "$engine_root/../opencode/skills" ]]; then
  managed_skills_root="$engine_root/../opencode/skills"
fi
if [[ -d "$managed_skills_root" ]]; then
  managed_skills_root="$(cd "$managed_skills_root" && pwd)"
fi
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

# T6 runs ERR-1 pre-flight next (before any write), then the existing
# skills-copy / config / docs / AGENTS.md flow follows — all gated on
# opt_dry_run (OBS-2) and using the shared atomic-write helper (ERR-2.1).

# --- T6 (issue #7): ERR-1 pre-flight validation ------------------------------
# Runs after flag resolution and BEFORE any write (ERR-1.1). Each failure
# exits 1 with a specific [error] message (ERR-1.2) and no file is touched.
run_preflight "$project_dir" "$managed_skills_root"

project_dir="$(mkdir -p "$project_dir" && cd "$project_dir" && pwd)"
docs_root="${docs_root%/}"
repo_name="${opt_name:-$(basename "$project_dir")}"

if [[ -z "$worktree_root" ]]; then
  worktree_root="$HOME/Projects/worktree/$repo_name"
fi

worktree_root="$(expand_path "$worktree_root")"

# T6 / OBS-2 dry-run: do not create the worktree root dir under --dry-run
# (OBS-2.1: zero file changes). Report what would happen instead.
if [[ "${opt_dry_run:-0}" == "1" ]]; then
  echo "[would-write] worktree root $worktree_root (mkdir -p)"
  stat_would_write=$((stat_would_write + 1))
else
  mkdir -p "$worktree_root"
fi
ensure_project_runtime_env \
  "$project_dir" \
  "$worktree_root" \
  "$repo_name" \
  "$opt_github_owner" \
  "$opt_github_project_number" \
  "$engine_assets/github-project.env.template"
ensure_opencode_config "$project_dir" "$worktree_root"
copy_required_skills "$project_dir" "$managed_skills_root"

# --- Local docs root (CLI-1 --docs-root contract) ----------------------------
# Regression fix (2026-08-22 review finding, AC-T2-005a): the central-Obsidian
# routing change removed local docs creation entirely, breaking the CLI-1
# --docs-root contract. Restore the minimal honoring: create ONLY the
# requested docs root directory. No scaffold is copied — product documentation
# still lives in the central Obsidian vault (see the routing section below);
# this directory is the repository's code-adjacent docs area.
if [[ "${opt_dry_run:-0}" == "1" ]]; then
  echo "[would-write] local docs root $project_dir/$docs_root (mkdir -p)"
  stat_would_write=$((stat_would_write + 1))
else
  if [[ -d "$project_dir/$docs_root" ]]; then
    echo "[summary] Local docs root $docs_root already exists; no changes needed"
    stat_skipped=$((stat_skipped + 1))
  else
    mkdir -p "$project_dir/$docs_root"
    emit_write "$docs_root/ (local docs root)"
  fi
fi

# --- Central Obsidian documentation routing -----------------------------------
# Product documentation is not copied or scaffolded into project repositories.
# The target repository receives only AGENTS.md guidance pointing to the
# project-specific path resolved from the ANT_TEAM_DOCS_* exports in
# .github-project.env.
if [[ "${opt_dry_run:-0}" == "1" ]]; then
  echo "[would-write] central Obsidian documentation routing in AGENTS.md"
  stat_would_write=$((stat_would_write + 1))
else
  echo "[summary] Product documentation remains in the central Obsidian vault"
fi
# --- SPEC-001 T3 (issue #4): AGENTS.md generation ---------------------------
# Runs after skills/config/docs writes per ERR-2.1 step 4 (AGENTS.md is the
# final artifact so "Local Configuration Files" can enumerate what was
# written). Implements FR-4 (default-only generation), FR-5 (artifact
# contract), DM-2 (structure), ERR-3.2 (backup).
agents_md_target="$project_dir/AGENTS.md"

# 1. Generate default-only content.
AGENTS_MD_CONTENT="$(
  AGENTSMD_PROJECT_DIR="$project_dir" \
  AGENTSMD_REPO_NAME="$repo_name" \
  AGENTSMD_VERSION="$INIT_PROJECT_VERSION" \
  AGENTSMD_SCRATCH_DIR="$opt_scratch_dir" \
  generate_agents_md_content
)"

# 2. Existing-file policy (FR-5.5). Sets AGENTS_MD_ACTION global.
decide_existing_agents_md_action "$agents_md_target" "$opt_force" "$opt_merge"

if [[ "$AGENTS_MD_ACTION" == "skip" ]]; then
  emit_skip "AGENTS.md exists; skipped (use --force to overwrite, --force --merge to append)"
else
  # 3. Write (with backup if --force + existing — ERR-3.2).
  # T6 / TR-2.2: for overwrite/merge on an existing file, compare the
  # structural body (header timestamp stripped) against the existing file.
  # If identical, downgrade to skip — no backup, no rewrite, no timestamp
  # churn. This is what makes `--force` idempotent at the content level
  # (TR-2.1: second run with identical parameters = no-op). The first
  # --force on a genuinely-changed file still backs up + rewrites (ERR-3.2).
  # T6 / OBS-2: in dry-run, emit [would-write] lines and skip every write
  # and backup (OBS-2.1: zero file changes).
  if [[ "$AGENTS_MD_ACTION" != "skip" ]]; then
    case "$AGENTS_MD_ACTION" in
      create)
        if [[ "${opt_dry_run:-0}" == "1" ]]; then
          echo "[would-write] AGENTS.md (new)"
          stat_would_write=$((stat_would_write + 1))
        else
          write_agents_md_atomic "$agents_md_target" "$AGENTS_MD_CONTENT"
          emit_write "AGENTS.md (new)"
        fi
        ;;
      overwrite)
        # Compute the structural comparison BEFORE deciding backup vs skip.
        existing_content_for_cmp="$(cat "$agents_md_target")"
        merged_for_cmp="$AGENTS_MD_CONTENT"
        if [[ "$(strip_agents_md_header <(printf '%s' "$existing_content_for_cmp"))" \
              == "$(strip_agents_md_header <(printf '%s' "$merged_for_cmp"))" ]]; then
          emit_skip "AGENTS.md already matches regenerated content; no changes needed (idempotent --force)"
        elif [[ "${opt_dry_run:-0}" == "1" ]]; then
          echo "[would-write] ${agents_md_target}.bak.<ts> (backup of previous AGENTS.md)"
          echo "[would-write] AGENTS.md (overwritten)"
          stat_would_write=$((stat_would_write + 2))
        else
          agents_md_backup="$(backup_agents_md "$agents_md_target")"
          write_agents_md_atomic "$agents_md_target" "$AGENTS_MD_CONTENT"
          emit_write "${agents_md_backup} (backup of previous AGENTS.md)"
          emit_write "AGENTS.md (overwritten)"
        fi
        ;;
      merge)
        existing_content_for_merge="$(cat "$agents_md_target")"
        merged_content="$(merge_agents_md_content "$existing_content_for_merge" "$AGENTS_MD_CONTENT")"
        # TR-2.2 idempotency on merge: if the merge result is structurally
        # identical to the existing file (all fresh sections already present),
        # skip the backup + write. Otherwise behave as ERR-3.2 requires.
        if [[ "$(strip_agents_md_header <(printf '%s' "$existing_content_for_merge"))" \
              == "$(strip_agents_md_header <(printf '%s' "$merged_content"))" ]]; then
          emit_skip "AGENTS.md already contains every merged section; no changes needed (idempotent --force --merge)"
        elif [[ "${opt_dry_run:-0}" == "1" ]]; then
          echo "[would-write] ${agents_md_target}.bak.<ts> (backup of previous AGENTS.md)"
          echo "[would-write] AGENTS.md (merged)"
          stat_would_write=$((stat_would_write + 2))
        else
          agents_md_backup="$(backup_agents_md "$agents_md_target")"
          write_agents_md_atomic "$agents_md_target" "$merged_content"
          emit_write "${agents_md_backup} (backup of previous AGENTS.md)"
          emit_merge "AGENTS.md"
        fi
        ;;
    esac
  fi
fi

# --- T6 (issue #7) / OBS-1.2: final summary line -----------------------------
# Always emitted last so downstream agents can detect completion by reading
# the trailing [summary] line. Dry-run reports would-write instead of
# created/merged (OBS-2.1).
if [[ "${opt_dry_run:-0}" == "1" ]]; then
  echo "[summary] Dry run complete. ${stat_would_write} would-write; ${stat_skipped} skipped; ${stat_warnings} warning(s)."
else
  echo "[summary] Initialization complete. ${stat_created} created; ${stat_merged} merged/updated; ${stat_skipped} skipped; ${stat_warnings} warning(s)."
fi
