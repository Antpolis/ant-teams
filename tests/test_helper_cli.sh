#!/usr/bin/env bash
#
# test_helper_cli.sh — behavioral tests for scripts/ant-team-help.sh.
#
# Covers the helper-CLI contract:
#   - lists installed helper scripts from $ANT_TEAM_SCRIPTS with a stable
#     one-line description per script
#   - unknown scripts stay visible with a generic note
#   - fails with a clear "run scripts/sync-company.sh first" message when
#     ANT_TEAM_SCRIPTS is unset or does not point to a directory
#   - never sources .github-project.env (behavior is env-independent)
#
# Standalone: `set -euo pipefail`, mktemp + trap cleanup, temp HOME only.
# Run directly: `bash tests/test_helper_cli.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELP_CLI="$REPO_ROOT/scripts/ant-team-help.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   - %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL - %s\n' "$1" >&2; }

assert_exit_zero()  { if [[ "$2" == "0" ]]; then ok "$1: exit 0"; else fail "$1: expected exit 0 got $2"; fi; }
assert_exit_code()  { if [[ "$2" == "$3" ]]; then ok "$1: exit $2"; else fail "$1: expected exit $3 got $2"; fi; }
assert_contains()   { if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1: substring present"; else fail "$1: substring MISSING ($3)"; fi; }
assert_not_contains() { if grep -qF -- "$3" "$2" 2>/dev/null; then fail "$1: unexpected substring ($3)"; else ok "$1: substring absent"; fi; }

run_help() {
  # run_help OUTFILE CMD... — run the command, capture combined output in
  # OUTFILE, record the exit code in RUN_RC. Safe under `set -e`.
  local out="$1"; shift
  RUN_RC=0
  "$@" >"$out" 2>&1 || RUN_RC=$?
}

echo "=== ant-team-help.sh: installed listing ==="

INSTALLED="$TMP/home/.agents/scripts"
mkdir -p "$INSTALLED"
# Real script under test plus representative real helpers and one unknown
# future helper, exactly as sync-company.sh would install them.
cp "$HELP_CLI" "$INSTALLED/ant-team-help.sh"
cp "$REPO_ROOT/scripts/sync-company.sh" "$INSTALLED/sync-company.sh"
cp "$REPO_ROOT/scripts/validate-agents-md.sh" "$INSTALLED/validate-agents-md.sh"
cp "$REPO_ROOT/scripts/record-communication.sh" "$INSTALLED/record-communication.sh"
printf '#!/usr/bin/env bash\n' > "$INSTALLED/future-helper.sh"

OUT="$TMP/out.txt"
run_help "$OUT" env "ANT_TEAM_SCRIPTS=$INSTALLED" "HOME=$TMP/home" bash "$HELP_CLI"
assert_exit_zero "listing exits 0" "$RUN_RC"
assert_contains "lists install dir header" "$OUT" "$INSTALLED"
assert_contains "stable description (ant-team-help)" "$OUT" "List installed team helper scripts with one-line descriptions"
assert_contains "stable description (sync-company)" "$OUT" "Install .opencode/ to ~/.config/opencode and team scripts"
assert_contains "stable description (validate-agents-md)" "$OUT" "Structural validator for AGENTS.md"
assert_contains "stable description (record-communication)" "$OUT" "Record or list agent communication event files"
assert_contains "unknown helper stays visible" "$OUT" "future-helper.sh"
assert_contains "unknown helper gets generic note" "$OUT" "No stable description recorded yet"

echo "=== ant-team-help.sh: does not source .github-project.env ==="

# A poisoned env file would abort the run (exit 7) if it were ever sourced.
mkdir -p "$TMP/project"
printf 'exit 7\n' > "$TMP/project/.github-project.env"
OUT="$TMP/out-env.txt"
( cd "$TMP/project" && run_help "$OUT" env "ANT_TEAM_SCRIPTS=$INSTALLED" "HOME=$TMP/home" bash "$HELP_CLI" )
assert_exit_zero "poisoned ./.github-project.env ignored" "$RUN_RC"

echo "=== ant-team-help.sh: sync-company has not run ==="

OUT="$TMP/out-missing.txt"
run_help "$OUT" env -u ANT_TEAM_SCRIPTS "HOME=$TMP/home" bash "$HELP_CLI"
assert_exit_code "unset ANT_TEAM_SCRIPTS exits 1" "$RUN_RC" "1"
assert_contains "clear message points to sync-company" "$OUT" "sync-company.sh"
assert_contains "clear message names the variable" "$OUT" "ANT_TEAM_SCRIPTS"

OUT="$TMP/out-stale.txt"
run_help "$OUT" env "ANT_TEAM_SCRIPTS=$TMP/does-not-exist" "HOME=$TMP/home" bash "$HELP_CLI"
assert_exit_code "non-directory ANT_TEAM_SCRIPTS exits 1" "$RUN_RC" "1"
assert_contains "stale dir message points to sync-company" "$OUT" "sync-company.sh"

echo "=== ant-team-help.sh: help flag ==="

OUT="$TMP/out-help.txt"
run_help "$OUT" env "ANT_TEAM_SCRIPTS=$INSTALLED" "HOME=$TMP/home" bash "$HELP_CLI" --help
assert_exit_zero "--help exits 0" "$RUN_RC"
assert_contains "usage shown" "$OUT" "Usage:"

printf '\n[test_helper_cli] %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
