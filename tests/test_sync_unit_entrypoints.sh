#!/usr/bin/env bash
#
# test_sync_unit_entrypoints.sh — SPEC-002 FR-12 / CLI-1..3 script entry-point
# contracts (static + behavioral).
#
# Traceability:
#   - FR-12.1 / CLI-1.2 sync-managed-skills.sh accepts --force and --dry-run.
#   - CLI-1.3 --force and --dry-run may be combined.
#   - FR-12.2 / CLI-2.1 init-company.sh accepts --force and forwards it.
#   - FR-12.3 / CLI-3.1 init-company.sh and init-company.sh delegate to
#     init-company.sh without modification (they `exec`).
#   - CLI-1.2 unknown flag => usage error exit 1.
#
# Part static (grep the real scripts for the delegation + flag handling) and
# part behavioral (run the real scripts against a temp HOME).
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "FR-12 / CLI-1..3 entry-point contracts"

HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR"' EXIT
OUT="$(mktemp)"

# --- FR-12.1 / CLI-1.2: managed script accepts --force and --dry-run ---------
# --help works offline and lists both flags.
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$HOME_DIR" --help
assert_exit_zero "managed --help exit 0" "$SYNC_RC"
assert_file_contains_str "managed usage lists --force" "$OUT" --force
assert_file_contains_str "managed usage lists --dry-run" "$OUT" --dry-run

# Unknown flag => usage error exit 1.
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$HOME_DIR" --bogus
assert_eq "managed unknown flag => exit 1" "$SYNC_RC" "1"

# --- FR-12.2 / CLI-2.1 (amended 2026-08-25): force/reset surface -------------
# Normal runs forward --force to the managed sync UNCONDITIONALLY; --force is
# accepted as a deprecated no-op; --reset (behavioral coverage lives in
# test_sync_e2e_company_reset.sh) moves the installed trees to .bak.<UTC>.
assert_file_contains_str "sync-company usage lists --force" "$SYNC_REAL_COMPANY" --force
assert_file_contains_str "sync-company usage lists --reset" "$SYNC_REAL_COMPANY" --reset
assert_file_contains_str "sync-company forwards --force unconditionally" "$SYNC_REAL_COMPANY" 'sync-managed-skills.sh" --force'
assert_file_contains_str "sync-company marks --force deprecated" "$SYNC_REAL_COMPANY" "deprecated"

# --- FR-12.3 / CLI-3.1: thin delegating wrappers stay flag-free ----------------
# Post-audit scripts/ layout: the retired init-company/update-company wrapper
# pair was consolidated — scripts/init-company.sh IS the coordinator that owns
# --force (asserted above), and scripts/init-project.sh is the remaining thin
# delegator (exec the installed init engine, no flags of its own).
INIT_PROJECT="$SYNC_REPO_ROOT/scripts/init-project.sh"
assert_exists "init-project.sh present" "$INIT_PROJECT"
assert_file_contains_str "init-project delegates to the init engine" "$INIT_PROJECT" 'init-project.sh" "$@"'
assert_file_not_contains_str "init-project adds no --force handling" "$INIT_PROJECT" --force

# --- CLI-1.3: --force and --dry-run combined (reports, writes nothing) -------
# A real-repo dry-run+force against temp HOME must exit 0 and write nothing
# under the managed subtree (no manifest created in dry-run).
FIX_HOME2="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR" "$FIX_HOME2"' EXIT
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$FIX_HOME2" --force --dry-run
assert_exit_zero "managed --force --dry-run exit 0" "$SYNC_RC"
assert_file_contains_str "force+dry-run: dry-run summary" "$OUT" "Dry-Run Summary"
assert_not_exists "force+dry-run: no manifest written" "$FIX_HOME2/.agents/skills/.manifest.json"

# --- FR-12.2 (amended 2026-08-25): --force on init-company.sh is a no-op ------
# Behavioral: the deprecated flag is ACCEPTED (exit 0) and warns. It must not
# change the outcome vs a normal run, which already syncs with --force.
DEP_HOME="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR" "$FIX_HOME2" "$DEP_HOME"' EXIT
sync_capture "$OUT" "$SYNC_REAL_COMPANY" "$DEP_HOME" --force
assert_exit_zero "init-company --force (deprecated no-op) exit 0" "$SYNC_RC"
assert_file_contains_str "--force warns it is deprecated" "$OUT" "deprecated"
assert_file_contains_str "--force warns it is deprecated" "$OUT" "deprecated"
assert_exists "--force still installs managed skills" \
  "$DEP_HOME/.agents/skills/do-tasks/SKILL.md"

rm -f "$OUT"
sync_done
