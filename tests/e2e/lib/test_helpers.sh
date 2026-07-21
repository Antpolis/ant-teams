#!/usr/bin/env bash
#
# test_helpers.sh — shared helpers for SPEC-001-T7 e2e/migration tests (issue #8).
#
# Design constraints (per issue #8 tech-lead guardrails):
#   - Each test script is STANDALONE: it sources this lib via a path computed
#     from its own $0, so it can run independently of the runner.
#   - Each test sets `set -euo pipefail` BEFORE sourcing; every helper here is
#     written to tolerate errexit (all grep/test invocations live inside
#     `if/then/fi` conditionals so a non-match never aborts the caller).
#   - No external dependencies: bash + coreutils + grep only.
#   - The interactive e2e test does NOT use `expect` or a Node pseudo-TTY
#     wrapper: `init_project_docs.sh --interactive` forces interactive mode
#     regardless of TTY, and `safe_read` reads piped stdin lines. Feeding
#     newline-delimited answers via a pipe is the portable, dependency-free
#     path endorsed by SPEC-001 TEST-2.2 ("plain shell scripts" for the
#     noninteractive cases; interactive allowed to use a pseudo-TTY wrapper
#     but not required when piped stdin suffices).
#
# Usage from a test script (tests/e2e/test_*.sh):
#   set -euo pipefail
#   source "$(dirname "$0")/lib/test_helpers.sh"
#   REPO_ROOT="$(e2e_repo_root "$0")"
#   e2e_begin "test name"
#   TMP="$(e2e_make_fixture_repo "$(e2e_fixtures_dir "$REPO_ROOT")/repo-node-npm")"
#   trap 'rm -rf "$TMP"' EXIT
#   ... run init, assert ...
#   e2e_done
#
# Counters are per-test (reset by e2e_begin).

_E2E_PASS=0
_E2E_FAIL=0
_E2E_TEST_NAME="(unset)"

# e2e_repo_root SCRIPT_PATH — resolve the repo root from a test script path.
# A test lives at <repo>/tests/e2e/test_*.sh; repo root is two dirs up
# (tests/e2e → tests → <repo>).
e2e_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "$1")" && pwd)"
  ( cd "$script_dir/../.." && pwd )
}

e2e_init_script() { printf '%s/.opencode/skills/project-initialization/scripts/init_project_docs.sh' "$1"; }
e2e_setup_script() { printf '%s/.opencode/skills/project-initialization/scripts/setup_project_docs.sh' "$1"; }
e2e_fixtures_dir() { printf '%s/tests/fixtures' "$1"; }

# e2e_make_fixture_repo FIXTURE_DIR — copy a fixture into a fresh mktemp -d and
# add a `.git` directory marker (ERR-1.1 requires the marker; a real .git cannot
# be tracked inside a fixture per issue #2 builder memory). Echoes the tmp path.
# Caller owns cleanup (trap 'rm -rf "$TMP"' EXIT).
e2e_make_fixture_repo() {
  local fixture="$1"
  local tmp
  tmp="$(mktemp -d)"
  cp -R "$fixture/." "$tmp/"
  mkdir -p "$tmp/.git"
  printf '%s' "$tmp"
}

# e2e_make_empty_repo — fresh mktemp -d + .git marker, no fixture content.
e2e_make_empty_repo() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.git"
  printf '%s' "$tmp"
}

# e2e_snapshot_files DIR — stable snapshot of the regular files under DIR
# (excluding DIR/.git) as "path<TAB>sha256" lines, sorted. Used by dry-run
# zero-change assertions. Portable: find + sort + sha256sum (coreutils).
e2e_snapshot_files() {
  local dir="$1"
  ( cd "$dir" && find . -type f -not -path './.git/*' -print0 \
      | sort -z \
      | xargs -0 sha256sum 2>/dev/null )
}

# e2e_count_skill_dirs DIR — number of skill directories under
# DIR/.opencode/skills/. Empty/missing → 0.
e2e_count_skill_dirs() {
  local sdir="$1/.opencode/skills"
  if [[ ! -d "$sdir" ]]; then printf '0'; return; fi
  find "$sdir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '
}

# e2e_has_skill_dir DIR SKILL — echoes "yes"/"no".
e2e_has_skill_dir() {
  if [[ -d "$1/.opencode/skills/$2" ]]; then printf 'yes'; else printf 'no'; fi
}

# --- assertion helpers (all tolerate `set -e`) --------------------------------

# check OK_OR_FAIL LABEL — core recorder. OK_OR_FAIL == "OK" passes, else fails.
check() {
  if [[ "$1" == "OK" ]]; then
    _E2E_PASS=$((_E2E_PASS + 1))
    printf '  ok   - %s\n' "$2"
  else
    _E2E_FAIL=$((_E2E_FAIL + 1))
    printf '  FAIL - %s\n' "$2" >&2
  fi
}

assert_exists()        { if [[ -e "$2" ]]; then check OK   "$1 exists"; else check FAIL "$1 missing ($2)"; fi; }
assert_not_exists()    { if [[ ! -e "$2" ]]; then check OK   "$1 absent"; else check FAIL "$1 unexpectedly present ($2)"; fi; }
assert_file_contains() { if grep -q -- "$3" "$2" 2>/dev/null; then check OK   "$1: pattern present"; else check FAIL "$1: pattern MISSING ($3 in $2)"; fi; }
assert_file_not_contains() { if grep -q -- "$3" "$2" 2>/dev/null; then check FAIL "$1: unexpected pattern ($3 in $2)"; else check OK   "$1: pattern absent"; fi; }
assert_exit_zero()     { if [[ "$2" == "0" ]]; then check OK   "$1: exit 0"; else check FAIL "$1: expected exit 0 got $2"; fi; }
assert_exit_nonzero()  { if [[ "$2" != "0" ]]; then check OK   "$1: non-zero exit ($2)"; else check FAIL "$1: expected non-zero exit got 0"; fi; }
assert_eq()            { if [[ "$2" == "$3" ]]; then check OK   "$1: [$2]"; else check FAIL "$1: expected [$3] got [$2]"; fi; }
assert_neq()           { if [[ "$2" != "$3" ]]; then check OK   "$1: [$2] != [$3]"; else check FAIL "$1: expected != [$3]"; fi; }
# assert_exec PATH — file exists AND has an executable bit set for the owner.
assert_exec() {
  local p="$1"
  if [[ -f "$p" && -r "$p" && -x "$p" ]]; then check OK   "executable: $p"; else check FAIL "not executable: $p"; fi
}

# e2e_begin TEST_NAME — start a test block, reset counters.
e2e_begin() {
  _E2E_TEST_NAME="$1"
  _E2E_PASS=0
  _E2E_FAIL=0
  printf '\n=== %s ===\n' "$1"
}

# e2e_done — print per-test summary and exit 0 (all passed) or 1 (≥1 failure).
e2e_done() {
  printf '[%s] %d passed, %d failed\n' "$_E2E_TEST_NAME" "$_E2E_PASS" "$_E2E_FAIL"
  if [[ "$_E2E_FAIL" -gt 0 ]]; then return 1; fi
  return 0
}
