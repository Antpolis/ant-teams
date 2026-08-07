#!/usr/bin/env bash
#
# run_sync_tests.sh — SPEC-002-T3 managed-sync test suite runner (issue #24).
#
# Runs every tests/test_sync_*.sh scenario (TEST-1 unit, TEST-2 integration,
# TEST-3 e2e, TEST-4 coverage matrix). Each scenario is standalone
# (`set -euo pipefail`, mktemp + trap cleanup, temp HOME — never touches the
# real ~/.agents/skills or ~/.config/opencode) and may also be invoked
# directly, e.g. `bash tests/test_sync_int_dry_run.sh`.
#
# Exit codes: 0 when every scenario passes; 1 if any scenario fails. The runner
# ALWAYS runs ALL scenarios (does not abort on first failure) so the operator
# sees the complete pass/fail picture in one pass.
#
# The literal per-suite invocation also works:
#   for f in tests/test_sync_*.sh; do bash "$f" || exit 1; done
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shopt -s nullglob
tests=( "$script_dir"/test_sync_*.sh )
shopt -u nullglob

if [[ ${#tests[@]} -eq 0 ]]; then
  printf 'No tests/test_sync_*.sh scenarios found under %s\n' "$script_dir" >&2
  exit 1
fi

# Run the coverage matrix LAST so a coverage drift is reported after the
# per-scenario results (the matrix only verifies file existence / pipefail, not
# scenario correctness, but ordering it last keeps the readable flow).
matrix=()
scenarios=()
for t in "${tests[@]}"; do
  if [[ "$(basename "$t")" == "test_sync_coverage_matrix.sh" ]]; then
    matrix=( "$t" )
  else
    scenarios+=( "$t" )
  fi
done

passed=0
failed=0
failures=()

run_one() {
  local t="$1" label="$2"
  if bash "$t"; then
    passed=$((passed + 1))
    printf '\n>>> %s: PASS (%s)\n' "$label" "$(basename "$t")"
  else
    failed=$((failed + 1))
    failures+=("$t")
    printf '\n>>> %s: FAIL (%s)\n' "$label" "$(basename "$t")"
  fi
}

printf '========================================================\n'
printf 'SPEC-002-T3 managed-sync test suite (issue #24)\n'
printf '========================================================\n'

printf '\n--- TEST-1 unit + TEST-2 integration + TEST-3 e2e scenarios ---\n'
for t in "${scenarios[@]}"; do
  if [[ ! -f "$t" ]]; then
    printf 'MISSING scenario: %s\n' "$t" >&2
    failed=$((failed + 1)); failures+=("$t (missing)")
    continue
  fi
  run_one "$t" "scenario"
done

if [[ ${#matrix[@]} -eq 1 ]]; then
  printf '\n--- TEST-4 coverage matrix ---\n'
  run_one "${matrix[0]}" "coverage"
fi

printf '\n========================================================\n'
printf 'Summary: %d passed, %d failed (%d total)\n' \
  "$passed" "$failed" "${#tests[@]}"
if [[ "$failed" -gt 0 ]]; then
  printf 'Failing scenarios:\n'
  for f in "${failures[@]}"; do printf '  - %s\n' "$f"; done
  printf '========================================================\n'
  exit 1
fi
printf 'All managed-sync scenarios passed.\n'
printf '========================================================\n'
exit 0
