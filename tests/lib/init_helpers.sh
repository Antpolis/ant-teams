#!/usr/bin/env bash
#
# init_helpers.sh — shared helpers for the init-project engine test suites
# (SPEC-004-T4, issue #54: Node harnesses migrated to Bash+jq).
#
# Design constraints (mirrors lib/sync_helpers.sh — issue #24 guardrails):
#   - Each test script is STANDALONE: it sources this lib via a path computed
#     from its own $0, so it can run independently of any runner:
#         source "$(dirname "$0")/lib/init_helpers.sh"
#   - Each test sets `set -euo pipefail` BEFORE sourcing; every helper and
#     assertion here tolerates errexit (grep/test invocations live inside
#     conditionals or `|| rc=$?` so a non-match or non-zero never aborts).
#   - Every fixture uses a temp directory created with `mktemp -d` and cleaned
#     via `trap '...' EXIT`. Tests NEVER touch the real vault, the real user
#     HOME contents, or the generated `.opencode/` mirror: init targets are
#     throwaway temp repos, and env/HOME overrides are passed explicitly.
#   - No external dependencies beyond bash + coreutils + grep + jq (the same
#     runtime the engine itself requires; Node is NOT required — that is the
#     SPEC-004 point of this migration).
#
# Canonical-source rule: assertions run against `templates/scripts/` and
# `templates/opencode/` (canonical sources), never the generated `.opencode/`
# mirror.
#

# Resolve repo root from this lib path: tests/lib/init_helpers.sh -> repo root
# is two dirs up. Computed once at source time.
INIT_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_REPO_ROOT="$(cd "$INIT_HELPERS_DIR/../.." && pwd)"
INIT_SCRIPT="$INIT_REPO_ROOT/templates/scripts/init-project.sh"

# Per-suite counters.
_INIT_PASS=0
_INIT_FAIL=0

# Last captured exit code from init_run / init_run_in / init_run_cmd.
INIT_RC=0

# ---------------------------------------------------------------------------
# Assertion helpers (all tolerate `set -e`; failures increment _INIT_FAIL).
# ---------------------------------------------------------------------------

check() {
  if [[ "$1" == "OK" ]]; then
    _INIT_PASS=$((_INIT_PASS + 1))
    printf '  ok   - %s\n' "$2"
  else
    _INIT_FAIL=$((_INIT_FAIL + 1))
    printf '  FAIL - %s\n' "$2" >&2
  fi
}

assert_exists()         { if [[ -e "$2" ]]; then check OK   "$1 exists"; else check FAIL "$1 missing ($2)"; fi; }
assert_not_exists()     { if [[ ! -e "$2" ]]; then check OK   "$1 absent"; else check FAIL "$1 unexpectedly present ($2)"; fi; }
assert_file_contains()  { if grep -qE -- "$3" "$2" 2>/dev/null; then check OK   "$1: pattern present"; else check FAIL "$1: pattern MISSING ($3 in $2)"; fi; }
assert_file_contains_str() { if grep -qF -- "$3" "$2" 2>/dev/null; then check OK   "$1: substring present"; else check FAIL "$1: substring MISSING ($3 in $2)"; fi; }
assert_file_not_contains_str() { if grep -qF -- "$3" "$2" 2>/dev/null; then check FAIL "$1: unexpected substring ($3 in $2)"; else check OK   "$1: substring absent"; fi; }
assert_exit_zero()      { if [[ "$2" == "0" ]]; then check OK   "$1: exit 0"; else check FAIL "$1: expected exit 0 got $2"; fi; }
assert_exit_nonzero()   { if [[ "$2" != "0" ]]; then check OK   "$1: non-zero exit ($2)"; else check FAIL "$1: expected non-zero exit got 0"; fi; }
assert_eq()             { if [[ "$2" == "$3" ]]; then check OK   "$1: [$2]"; else check FAIL "$1: expected [$3] got [$2]"; fi; }
assert_neq()            { if [[ "$2" != "$3" ]]; then check OK   "$1: [$2] != [$3]"; else check FAIL "$1: expected != [$3]"; fi; }
assert_ge()             { if (( $2 >= $3 )); then check OK   "$1: $2 >= $3"; else check FAIL "$1: expected >= $3 got $2"; fi; }
assert_count() {
  # assert_count LABEL OUTFILE SUBSTRING EXPECTED — count of fixed-string lines.
  local _got
  _got="$(grep -cF -- "$3" "$2" 2>/dev/null || true)"
  assert_eq "$1" "$_got" "$4"
}
assert_exec() {
  # assert_exec LABEL PATH — file exists, is readable, and has an exec bit.
  local p="$2"
  if [[ -f "$p" && -r "$p" && -x "$p" ]]; then check OK   "$1: executable"; else check FAIL "$1: not executable ($p)"; fi
}
assert_out_contains()     { if grep -qE -- "$2" "$1" 2>/dev/null; then check OK   "$3"; else check FAIL "$3 (pattern MISSING: $2)"; fi; }
assert_out_contains_str() { if grep -qF -- "$2" "$1" 2>/dev/null; then check OK   "$3"; else check FAIL "$3 (substring MISSING: $2)"; fi; }
assert_out_not_contains_str() { if grep -qF -- "$2" "$1" 2>/dev/null; then check FAIL "$3 (unexpected substring: $2)"; else check OK   "$3"; fi; }

# ---------------------------------------------------------------------------
# Fixture builders (temp-based; caller owns cleanup via trap EXIT).
# ---------------------------------------------------------------------------

# init_make_repo [PREFIX] — mktemp -d a throwaway target repo with a `.git/`
# marker (the engine's preflight requires a git project). Echoes the path.
init_make_repo() {
  local d
  d="$(mktemp -d "${1:-init-target}-XXXXXX")"
  mkdir -p "$d/.git"
  printf '%s' "$d"
}

# init_make_empty_dir [PREFIX] — mktemp -d with NO .git marker (non-git
# fixture for ERR-1.1 preflight tests). Echoes the path.
init_make_empty_dir() {
  mktemp -d "${1:-init-nogit}-XXXXXX"
}

# init_clone_fixture FIXTURE PREFIX — copy a fixture repo (including dotfiles)
# into a fresh temp dir so init can run against it without polluting the real
# fixture; re-creates the `.git/` marker. Echoes the temp path.
init_clone_fixture() {
  local fixture="$1" prefix="${2:-init-fixture}"
  local tmp
  tmp="$(mktemp -d "${prefix}-XXXXXX")"
  rm -rf "$tmp/.git"
  # Copy all entries including dotfiles.
  local entry
  for entry in "$fixture"/* "$fixture"/.*; do
    [[ -e "$entry" ]] || continue
    case "$(basename "$entry")" in '.'|'..') continue ;; esac
    cp -R "$entry" "$tmp/"
  done
  mkdir -p "$tmp/.git"
  printf '%s' "$tmp"
}

# ---------------------------------------------------------------------------
# Run helpers (capture stdout/stderr separately + exit code; safe under `set -e`).
# ---------------------------------------------------------------------------

# init_run OUTFILE ERRFILE [ENV_ASSIGNMENT|-u NAME ...--] ARG...
# Run the init engine with stdin from /dev/null (noninteractive default: no
# TTY). Optional env assignments / `-u NAME` unsets may be given before the
# `--` separator; everything after `--` is passed to the engine.
init_run() {
  local _out="$1" _err="$2"; shift 2
  local -a _env=()
  while [[ "${1:-}" != "--" ]]; do
    _env+=("$1")
    shift
  done
  shift
  INIT_RC=0
  if (( ${#_env[@]} > 0 )); then
    env "${_env[@]}" bash "$INIT_SCRIPT" "$@" >"$_out" 2>"$_err" </dev/null || INIT_RC=$?
  else
    bash "$INIT_SCRIPT" "$@" >"$_out" 2>"$_err" </dev/null || INIT_RC=$?
  fi
}

# init_run_in OUTFILE ERRFILE INPUTFILE ARG... — run the engine with stdin
# read from INPUTFILE (for pipe-fed mode invocations).
init_run_in() {
  local _out="$1" _err="$2" _input="$3"; shift 3
  INIT_RC=0
  bash "$INIT_SCRIPT" "$@" >"$_out" 2>"$_err" <"$_input" || INIT_RC=$?
}

# init_run_cmd OUTFILE ERRFILE WORKDIR [ENV_ASSIGNMENT|-u NAME ...--] CMD...
# Generic runner for non-engine scripts (validator, helper, wrappers).
init_run_cmd() {
  local _out="$1" _err="$2" _cwd="$3"; shift 3
  local -a _env=()
  while [[ "${1:-}" != "--" ]]; do
    _env+=("$1")
    shift
  done
  shift
  INIT_RC=0
  if (( ${#_env[@]} > 0 )); then
    env "${_env[@]}" bash -c 'cd "$1"; shift; exec "$@"' _ "$_cwd" "$@" >"$_out" 2>"$_err" </dev/null || INIT_RC=$?
  else
    bash -c 'cd "$1"; shift; exec "$@"' _ "$_cwd" "$@" >"$_out" 2>"$_err" </dev/null || INIT_RC=$?
  fi
}

# ---------------------------------------------------------------------------
# Env-file query (jq-free; strict-source round-trip).
# ---------------------------------------------------------------------------

# init_source_env_var DIR VARNAME — source DIR/.github-project.env in a strict
# bash subshell and print VARNAME (empty string when unset). Sets INIT_RC to
# the subshell exit code so callers can assert the env sources cleanly:
#   val="$(init_source_env_var "$tmp" ANT_TEAM_GITHUB_OWNER)" || true
#   assert_exit_zero "env sources cleanly" "$INIT_RC"
init_source_env_var() {
  local dir="$1" var="$2"
  INIT_RC=0
  ( cd "$dir" && set -euo pipefail && source ./.github-project.env && printf '%s' "${!var-}" ) || INIT_RC=$?
}

# ---------------------------------------------------------------------------
# Lifecycle.
# ---------------------------------------------------------------------------

init_suite() {
  printf '\n=== %s ===\n' "$1"
}

# init_done — print the suite summary; exit 0 (all passed) or 1 (any failure).
init_done() {
  printf '\n%d passed, %d failed\n' "$_INIT_PASS" "$_INIT_FAIL"
  if (( _INIT_FAIL > 0 )); then return 1; fi
  return 0
}
