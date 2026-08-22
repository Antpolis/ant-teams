#!/usr/bin/env bash
#
# run_e2e_tests.sh — SPEC-001-T7 end-to-end + smoke test runner.
# Traceability: AC-T7-001 (executes the e2e cases, exit 0 when all pass)
# + TEST-2.1 (6 e2e cases) + TEST-5.1 (representative ant-teams dry-run smoke).
#
# Issue #8 scope lists 9 core test cases (7 e2e + 2 migration) plus the
# TEST-5.1 smoke. The 3 migration cases (legacy .github-project.json import)
# were retired with the env-only configuration contract (2026-08); this runner
# executes the 6 remaining e2e cases plus the smoke, reported separately so it
# never masks a core-suite failure.
#
# Each test script is standalone (`set -euo pipefail`, mktemp + trap cleanup)
# and may be invoked directly: `tests/e2e/test_e2e_idempotent.sh`.
#
# Exit codes: 0 when every script passes; 1 if any script fails. The runner
# always runs ALL scripts (does not abort on first failure) so the operator
# sees the complete pass/fail picture in one pass.
#
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
e2e_dir="$script_dir/e2e"

# Ordered list mirroring the issue #8 scope order (migration cases retired).
core_tests=(
  # TEST-2.1 end-to-end cases (6)
  "$e2e_dir/test_e2e_interactive_bare.sh"
  "$e2e_dir/test_e2e_noninteractive_node.sh"
  "$e2e_dir/test_e2e_noninteractive_missing.sh"
  "$e2e_dir/test_e2e_idempotent.sh"
  "$e2e_dir/test_e2e_force.sh"
  "$e2e_dir/test_e2e_dry_run.sh"
)

# TEST-5.1 representative smoke (kept separate from the "9 core" count).
smoke_tests=(
  "$e2e_dir/test_smoke_ant_teams_dry_run.sh"
)

passed=0
failed=0
failures=()

run_one() {
  local t="$1"
  local label="$2"
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
printf 'SPEC-001-T7 e2e + smoke test suite\n'
printf '========================================================\n'
printf '\n--- Core suite (6 e2e cases, AC-T7-001) ---\n'
for t in "${core_tests[@]}"; do
  if [[ ! -f "$t" ]]; then
    printf 'MISSING test script: %s\n' "$t" >&2
    failed=$((failed + 1))
    failures+=("$t (missing)")
    continue
  fi
  run_one "$t" "core"
done

printf '\n--- Smoke (TEST-5.1, representative) ---\n'
for t in "${smoke_tests[@]}"; do
  if [[ ! -f "$t" ]]; then
    printf 'MISSING smoke script: %s\n' "$t" >&2
    failed=$((failed + 1))
    failures+=("$t (missing)")
    continue
  fi
  run_one "$t" "smoke"
done

printf '\n========================================================\n'
printf 'Summary: %d passed, %d failed (core=%d, smoke=%d)\n' \
  "$passed" "$failed" "${#core_tests[@]}" "${#smoke_tests[@]}"
if [[ "$failed" -gt 0 ]]; then
  printf 'Failing scripts:\n'
  for f in "${failures[@]}"; do printf '  - %s\n' "$f"; done
  printf '========================================================\n'
  exit 1
fi
printf 'All e2e + smoke tests passed.\n'
printf '========================================================\n'
exit 0
