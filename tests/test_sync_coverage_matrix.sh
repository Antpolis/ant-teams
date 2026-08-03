#!/usr/bin/env bash
#
# test_sync_coverage_matrix.sh — SPEC-002 TEST-4: coverage verification.
#
# Traceability:
#   - TEST-4.1 every functional requirement (FR-1 .. FR-12) is covered by at
#     least one test case in the suite.
#   - TEST-4.2 every error-handling scenario (ERR-1 .. ERR-6) is covered by at
#     least one test case.
#   - TEST-4.3 the suite passes with `set -euo pipefail` active (this file and
#     every test_sync_*.sh enforce it at the top).
#
# This is a self-checking coverage matrix: it maps each FR/ERR to the set of
# test files that assert it, and verifies each mapped file exists under tests/.
# It does not re-run the scenarios (the per-concern files do that); it guards
# against accidental coverage drift if a file is renamed or removed.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-4 coverage matrix (FR/ERR -> test files)"

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Each requirement maps to one or more test files (relative to tests/).
# At least one file per requirement MUST exist (TEST-4.1 / TEST-4.2).
declare -a REQ_IDS=()
declare -A REQ_FILES
add_req() { REQ_IDS+=("$1"); REQ_FILES["$1"]="$2"; }

# --- FR coverage (TEST-4.1) ---------------------------------------------------
add_req FR-1  "test_sync_e2e_company_run.sh"                              # canonical install
add_req FR-2  "test_sync_int_fresh_install.sh test_sync_e2e_company_run.sh test_sync_int_full_directory_copy.sh"  # managed sync
add_req FR-3  "test_sync_unit_manifest.sh"                                # manifest ownership
add_req FR-4  "test_sync_unit_frontmatter.sh test_sync_int_command_transform.sh"  # command transform
add_req FR-5  "test_sync_unit_hashing.sh test_sync_int_local_modification.sh"  # modified detection
add_req FR-6  "test_sync_int_fresh_install.sh test_sync_int_local_modification.sh test_sync_int_orphan.sh"  # default behavior
add_req FR-7  "test_sync_unit_paths.sh test_sync_int_boundary_enforcement.sh test_sync_int_unmanaged_protection.sh"  # boundary
add_req FR-8  "test_sync_int_force_overwrite.sh test_sync_e2e_force_overwrite.sh"  # force
add_req FR-9  "test_sync_int_dry_run.sh test_sync_e2e_dry_run.sh"         # dry-run
add_req FR-10 "test_sync_int_idempotent.sh test_sync_e2e_idempotent.sh"   # idempotency
add_req FR-11 "test_sync_unit_collision.sh test_sync_int_collision_resolution.sh test_sync_int_unmanaged_collision.sh"  # collision
add_req FR-12 "test_sync_unit_entrypoints.sh test_sync_e2e_company_run.sh"  # entry points

# --- ERR coverage (TEST-4.2) --------------------------------------------------
add_req ERR-1 "test_sync_unit_frontmatter.sh test_sync_int_command_transform.sh test_sync_unit_source_errors.sh"  # ERR-1.1 malformed frontmatter + ERR-1.2 unreadable command source
add_req ERR-2 "test_sync_unit_source_errors.sh test_sync_int_orphan.sh"   # unreadable source / orphan
add_req ERR-3 "test_sync_unit_manifest.sh"                                # manifest corruption
add_req ERR-4 "test_sync_int_fs_error.sh"                                 # permission errors
add_req ERR-5 "test_sync_int_partial_recovery.sh"                         # partial-run recovery
add_req ERR-6 "test_sync_int_fs_error.sh"                                 # disk-full / FS error

printf 'Requirement | Mapped test file(s) | Status\n'
printf -- '------------|-------------------|--------\n'
COV_FAIL=0
for id in "${REQ_IDS[@]}"; do
  files="${REQ_FILES[$id]}"
  hit=""
  for f in $files; do
    if [[ -f "$TESTS_DIR/$f" ]]; then hit="$f"; break; fi
  done
  if [[ -n "$hit" ]]; then
    printf '%s | %s | OK\n' "$id" "$hit"
    check OK "$id covered by $hit"
  else
    printf '%s | %s | MISSING\n' "$id" "$files"
    check FAIL "$id has no covering test file ($files)"
    COV_FAIL=$((COV_FAIL + 1))
  fi
done

# TEST-4.3: assert every test_sync_*.sh in tests/ enforces set -euo pipefail.
printf '\nVerifying TEST-4.3 (set -euo pipefail active in every test_sync_*.sh)...\n'
SH_VIOL=0
shopt -s nullglob
for f in "$TESTS_DIR"/test_sync_*.sh; do
  if grep -qE '^set -euo pipefail' "$f"; then
    check OK "pipefail: $(basename "$f")"
  else
    check FAIL "pipefail: $(basename "$f") (missing 'set -euo pipefail')"
    SH_VIOL=$((SH_VIOL + 1))
  fi
done
shopt -u nullglob

# Inventory summary.
printf '\nSuite inventory: %d test files (test_sync_*.sh)\n' \
  "$(find "$TESTS_DIR" -maxdepth 1 -name 'test_sync_*.sh' -type f 2>/dev/null | wc -l | tr -d ' ')"

sync_done
