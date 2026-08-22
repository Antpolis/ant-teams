#!/usr/bin/env bash
#
# sync_helpers.sh — shared helpers for the SPEC-002-T3 managed-sync test suite
# (issue #24, TEST-1..TEST-4).
#
# Design constraints (issue #24 tech-lead guardrails):
#   - Each test script is STANDALONE: it sources this lib via a path computed
#     from its own $0, so it can run independently of the runner:
#         source "$(dirname "$0")/lib/sync_helpers.sh"
#   - Each test sets `set -euo pipefail` BEFORE sourcing; every helper and
#     assertion here tolerates errexit (grep/test invocations live inside
#     conditionals or `|| var=$?` so a non-match or non-zero never aborts).
#   - Every fixture uses a temp directory created with `mktemp -d` and cleaned
#     via `trap '...' EXIT`. Tests NEVER touch the real `~/.agents/skills/`
#     or `~/.config/opencode/`: they override `$HOME` to a temp dir (TR-1.3 —
#     the script resolves `~` via `$HOME`, never tilde expansion).
#   - No external dependencies: bash + coreutils + grep + the repo's existing
#     `node` runtime (already required by init-company.sh for provider merge).
#
# Two fixture strategies are supported:
#   1. Controlled fixture repo (TEST-1 unit + TEST-2 integration): the REAL
#      `scripts/sync-managed-skills.sh` is COPIED into a temp repo at
#      `<fix>/scripts/`, and a controlled `.opencode/{skills,commands}/` is
#      staged alongside it. The script resolves REPO_ROOT from its own
#      location (`dirname/..`), so it reads the fixture's `.opencode/` while
#      running the production code path byte-for-byte.
#   2. Real repo (TEST-3 E2E): the real repo script + real `.opencode/` are
#      exercised directly with `$HOME` overridden, validating the real
#      install counts (26 source skills + 8 command-derived = 34 entries).
#

# Resolve repo root from this lib path: tests/lib/sync_helpers.sh -> repo root
# is two dirs up. Computed once at source time.
SYNC_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_REPO_ROOT="$(cd "$SYNC_HELPERS_DIR/../.." && pwd)"
SYNC_REAL_SCRIPT="$SYNC_REPO_ROOT/scripts/sync-managed-skills.sh"
SYNC_REAL_COMPANY="$SYNC_REPO_ROOT/scripts/init-company.sh"
SYNC_REAL_OPENCODE="$SYNC_REPO_ROOT/.opencode"

# Per-test counters (reset by sync_begin).
_SYNC_PASS=0
_SYNC_FAIL=0
_SYNC_TEST_NAME="(unset)"

# Last captured exit code from sync_capture.
SYNC_RC=0

# ---------------------------------------------------------------------------
# Portable primitives (TR-1.1, TR-2.1 — no GNU-only flags).
# ---------------------------------------------------------------------------

# sync_sha256 FILE — lowercase hex SHA-256 (matches the script's compute_hash).
sync_sha256() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" 2>/dev/null | awk '{print tolower($1)}'
  else
    shasum -a 256 "$f" 2>/dev/null | awk '{print tolower($1)}'
  fi
}

# sync_mode_of FILE — octal mode string (e.g. "644"); empty if stat unavailable.
sync_mode_of() {
  local f="$1"
  if stat -c %a "$f" 2>/dev/null; then return 0; fi
  stat -f %Lp "$f" 2>/dev/null
}

# sync_count_dirs DIR — number of subdirectories directly under DIR (0 if absent).
sync_count_dirs() {
  local d="$1"
  if [[ ! -d "$d" ]]; then printf '0'; return; fi
  find "$d" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '
}

# sync_count_files_recursively DIR — number of regular files under DIR (0 if absent).
sync_count_files_recursively() {
  local d="$1"
  if [[ ! -d "$d" ]]; then printf '0'; return; fi
  find "$d" -type f 2>/dev/null | wc -l | tr -d ' '
}

# ---------------------------------------------------------------------------
# Fixture builders (all temp-based; caller owns cleanup via trap EXIT).
# ---------------------------------------------------------------------------

# sync_make_fixture_repo — mktemp -d a fixture repo, copy the REAL script into
# <fix>/scripts/, and create empty <fix>/.opencode/{skills,commands}/. Echoes
# the fixture root path. Each test then stages the skills/commands it needs.
sync_make_fixture_repo() {
  local fix
  fix="$(mktemp -d 2>/dev/null || mktemp -d -t synctests)"
  mkdir -p "$fix/scripts" "$fix/.opencode/skills" "$fix/.opencode/commands"
  cp "$SYNC_REAL_SCRIPT" "$fix/scripts/sync-managed-skills.sh"
  chmod 0755 "$fix/scripts/sync-managed-skills.sh" 2>/dev/null || true
  printf '%s' "$fix"
}

# sync_make_fixture_repo_with_company — like the above but also copies the real
# init-company.sh (for tests that exercise the two-target coordinator). The
# canonical install source is the fixture's `.opencode/`, so a real run is
# isolated. Echoes the fixture root path.
sync_make_fixture_repo_with_company() {
  local fix
  fix="$(sync_make_fixture_repo)"
  cp "$SYNC_REAL_COMPANY" "$fix/scripts/init-company.sh"
  chmod 0755 "$fix/scripts/init-company.sh" 2>/dev/null || true
  printf '%s' "$fix"
}

# sync_make_home — mktemp -d a fake HOME so the script writes into
# <home>/.agents/skills and <home>/.config/opencode without ever touching the
# operator's real directories. Echoes the home path.
sync_make_home() {
  local h
  h="$(mktemp -d 2>/dev/null || mktemp -d -t synchome)"
  printf '%s' "$h"
}

# sync_write_skill FIX NAME SKILLMD_BODY — create a minimal source skill
# <fix>/.opencode/skills/<NAME>/SKILL.md with the given body.
sync_write_skill() {
  local fix="$1" name="$2" body="$3"
  mkdir -p "$fix/.opencode/skills/$name"
  printf '%s' "$body" > "$fix/.opencode/skills/$name/SKILL.md"
}

# sync_write_skill_file FIX NAME RELPATH CONTENT — write an arbitrary file at
# <fix>/.opencode/skills/<NAME>/<RELPATH> (creating parent dirs).
sync_write_skill_file() {
  local fix="$1" name="$2" rel="$3" content="$4"
  local dest="$fix/.opencode/skills/$name/$rel"
  mkdir -p "$(dirname "$dest")"
  printf '%s' "$content" > "$dest"
}

# sync_write_command FIX NAME FRONTMATTER_BLOCK BODY — create a source command
# <fix>/.opencode/commands/<NAME>.md. FRONTMATTER_BLOCK is written verbatim
# between `---` fences (pass the inner lines); BODY follows a blank separator.
sync_write_command() {
  local fix="$1" name="$2" fm="$3" body="$4"
  mkdir -p "$fix/.opencode/commands"
  {
    printf '%s\n' '---'
    printf '%s\n' "$fm"
    printf '%s\n' '---'
    printf '\n'
    printf '%s' "$body"
  } > "$fix/.opencode/commands/$name.md"
}

# ---------------------------------------------------------------------------
# Run helpers (override $HOME; capture combined output + exit code).
# ---------------------------------------------------------------------------

# sync_capture OUTFILE SCRIPT_PATH HOME_DIR [args...] — run SCRIPT_PATH with
# HOME=HOME_DIR, redirecting stdout+stderr to OUTFILE. Sets SYNC_RC to the
# script's exit code. Safe under `set -e` (the `|| __rc=$?` form does not
# trigger errexit).
sync_capture() {
  local _out="$1" _script="$2" _home="$3"; shift 3
  SYNC_RC=0
  HOME="$_home" bash "$_script" "$@" >"$_out" 2>&1 || SYNC_RC=$?
}

# sync_capture_managed OUTFILE FIX_HOME_OR_REALSCRIPT HOME_DIR [args...]
# Convenience: if first arg is a fixture dir, run its copied managed script;
# otherwise treat as an absolute script path (real-repo E2E). Kept simple by
# having callers pass the script path explicitly; tests use sync_capture.
# (Provided for completeness; most tests call sync_capture directly.)

# ---------------------------------------------------------------------------
# Manifest queries (node-backed; the manifest is JSON per DM-2).
# ---------------------------------------------------------------------------

# sync_manifest_count_entries MANIFEST — number of managed_entries keys.
sync_manifest_count_entries() {
  local m="$1"
  if [[ ! -f "$m" ]]; then printf '0'; return; fi
  node -e 'const m=require(process.argv[1]); console.log(Object.keys(m.managed_entries||{}).length)' "$m" 2>/dev/null \
    || printf '0'
}

# sync_manifest_has_entry MANIFEST NAME — echoes "yes"/"no".
sync_manifest_has_entry() {
  local m="$1" name="$2"
  if [[ ! -f "$m" ]]; then printf 'no'; return; fi
  if node -e 'const m=require(process.argv[1]); process.exit(m.managed_entries&&m.managed_entries[process.argv[2]]?0:1)' \
        "$m" "$name" 2>/dev/null; then
    printf 'yes'
  else
    printf 'no'
  fi
}

# sync_manifest_entry_type MANIFEST NAME — echoes type or "".
sync_manifest_entry_type() {
  local m="$1" name="$2"
  if [[ ! -f "$m" ]]; then printf ''; return; fi
  node -e 'const m=require(process.argv[1]); const e=m.managed_entries&&m.managed_entries[process.argv[2]]; process.stdout.write((e&&e.type)||"")' \
    "$m" "$name" 2>/dev/null || printf ''
}

# sync_manifest_file_hash MANIFEST NAME FILEKEY — echoes recorded hash or "".
sync_manifest_file_hash() {
  local m="$1" name="$2" fk="$3"
  if [[ ! -f "$m" ]]; then printf ''; return; fi
  node -e 'const m=require(process.argv[1]); const e=m.managed_entries&&m.managed_entries[process.argv[2]]; const f=e&&e.files&&e.files[process.argv[3]]; process.stdout.write((f&&f.hash)||"")' \
    "$m" "$name" "$fk" 2>/dev/null || printf ''
}

# sync_manifest_entry_filekeys MANIFEST NAME — newline-joined file keys.
sync_manifest_entry_filekeys() {
  local m="$1" name="$2"
  if [[ ! -f "$m" ]]; then printf ''; return; fi
  node -e 'const m=require(process.argv[1]); const e=m.managed_entries&&m.managed_entries[process.argv[2]]; process.stdout.write(Object.keys((e&&e.files)||{}).join("\n"))' \
    "$m" "$name" 2>/dev/null || printf ''
}

# sync_manifest_target_path MANIFEST NAME FILEKEY — echoes recorded target_path or "".
sync_manifest_target_path() {
  local m="$1" name="$2" fk="$3"
  if [[ ! -f "$m" ]]; then printf ''; return; fi
  node -e 'const m=require(process.argv[1]); const e=m.managed_entries&&m.managed_entries[process.argv[2]]; const f=e&&e.files&&e.files[process.argv[3]]; process.stdout.write((f&&f.target_path)||"")' \
    "$m" "$name" "$fk" 2>/dev/null || printf ''
}

# sync_manifest_is_valid_json MANIFEST — "yes"/"no" (parse + top-level keys).
sync_manifest_is_valid_json() {
  local m="$1"
  if [[ ! -f "$m" ]]; then printf 'no'; return; fi
  if node -e 'const m=require(process.argv[1]); if(typeof m!=="object"||m===null||m.version!==1||typeof m.managed_entries!=="object")process.exit(1)' \
        "$m" 2>/dev/null; then
    printf 'yes'
  else
    printf 'no'
  fi
}

# ---------------------------------------------------------------------------
# Assertion helpers (all tolerate `set -e`; failures increment _SYNC_FAIL).
# ---------------------------------------------------------------------------

check() {
  if [[ "$1" == "OK" ]]; then
    _SYNC_PASS=$((_SYNC_PASS + 1))
    printf '  ok   - %s\n' "$2"
  else
    _SYNC_FAIL=$((_SYNC_FAIL + 1))
    printf '  FAIL - %s\n' "$2" >&2
  fi
}

assert_exists()             { if [[ -e "$2" ]]; then check OK   "$1 exists"; else check FAIL "$1 missing ($2)"; fi; }
assert_not_exists()         { if [[ ! -e "$2" ]]; then check OK   "$1 absent"; else check FAIL "$1 unexpectedly present ($2)"; fi; }
assert_file_contains()      { if grep -qE -- "$3" "$2" 2>/dev/null; then check OK   "$1: pattern present"; else check FAIL "$1: pattern MISSING ($3 in $2)"; fi; }
assert_file_contains_str()  { if grep -qF -- "$3" "$2" 2>/dev/null; then check OK   "$1: substring present"; else check FAIL "$1: substring MISSING ($3 in $2)"; fi; }
assert_file_not_contains_str() { if grep -qF -- "$3" "$2" 2>/dev/null; then check FAIL "$1: unexpected substring ($3 in $2)"; else check OK   "$1: substring absent"; fi; }
assert_exit_zero()          { if [[ "$2" == "0" ]]; then check OK   "$1: exit 0"; else check FAIL "$1: expected exit 0 got $2"; fi; }
assert_exit_nonzero()       { if [[ "$2" != "0" ]]; then check OK   "$1: non-zero exit ($2)"; else check FAIL "$1: expected non-zero exit got 0"; fi; }
assert_eq()                 { if [[ "$2" == "$3" ]]; then check OK   "$1: [$2]"; else check FAIL "$1: expected [$3] got [$2]"; fi; }
assert_neq()                { if [[ "$2" != "$3" ]]; then check OK   "$1: [$2] != [$3]"; else check FAIL "$1: expected != [$3]"; fi; }
assert_ge()                 { if (( $2 >= $3 )); then check OK   "$1: $2 >= $3"; else check FAIL "$1: expected >= $3 got $2"; fi; }
assert_gt()                 { if (( $2 > $3 )); then check OK   "$1: $2 > $3"; else check FAIL "$1: expected > $3 got $2"; fi; }
# assert_count LABEL OUTFILE SUBSTRING EXPECTED — count of fixed-string lines.
assert_count() {
  local _got
  _got="$(grep -cF -- "$3" "$2" 2>/dev/null || true)"
  assert_eq "$1" "$_got" "$4"
}
assert_exec() {
  # assert_exec LABEL PATH — file exists, is readable, and has an exec bit.
  local p="$2"
  if [[ -f "$p" && -r "$p" && -x "$p" ]]; then check OK   "$1: executable"; else check FAIL "$1: not executable ($p)"; fi
}

# ---------------------------------------------------------------------------
# Lifecycle.
# ---------------------------------------------------------------------------

sync_begin() {
  _SYNC_TEST_NAME="$1"
  _SYNC_PASS=0
  _SYNC_FAIL=0
  printf '\n=== %s ===\n' "$1"
}

# sync_done — print per-test summary; exit 0 (all passed) or 1 (>=1 failure).
sync_done() {
  printf '[%s] %d passed, %d failed\n' "$_SYNC_TEST_NAME" "$_SYNC_PASS" "$_SYNC_FAIL"
  if [[ "$_SYNC_FAIL" -gt 0 ]]; then return 1; fi
  return 0
}
