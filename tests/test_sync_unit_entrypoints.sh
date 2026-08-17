#!/usr/bin/env bash
#
# test_sync_unit_entrypoints.sh — SPEC-002 FR-12 / CLI-1..3 script entry-point
# contracts (static + behavioral).
#
# Traceability:
#   - FR-12.1 / CLI-1.2 sync-managed-skills.sh accepts --force and --dry-run.
#   - CLI-1.3 --force and --dry-run may be combined.
#   - FR-12.2 / CLI-2.1 sync-company.sh accepts --force and forwards it.
#   - FR-12.3 / CLI-3.1 init-company.sh and update-company.sh delegate to
#     sync-company.sh without modification (they `exec`).
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

# --- FR-12.2 / CLI-2.1: sync-company.sh accepts --force (static) -------------
assert_file_contains_str "sync-company usage lists --force" "$SYNC_REAL_COMPANY" --force
assert_file_contains_str "sync-company forwards --force to managed" "$SYNC_REAL_COMPANY" 'sync-managed-skills.sh" --force'

# --- FR-12.3 / CLI-3.1: wrappers delegate to sync-company.sh unchanged -------
INIT_COMPANY="$SYNC_REPO_ROOT/scripts/init-company.sh"
UPDATE_COMPANY="$SYNC_REPO_ROOT/scripts/update-company.sh"
assert_exists "init-company.sh present" "$INIT_COMPANY"
assert_exists "update-company.sh present" "$UPDATE_COMPANY"
# Both must exec/delegate to sync-company.sh and add NO new flags of their own.
assert_file_contains_str "init-company delegates to sync-company.sh" "$INIT_COMPANY" "sync-company.sh"
assert_file_contains_str "update-company delegates to sync-company.sh" "$UPDATE_COMPANY" "sync-company.sh"
assert_file_not_contains_str "init-company adds no --force handling" "$INIT_COMPANY" --force
assert_file_not_contains_str "update-company adds no --force handling" "$UPDATE_COMPANY" --force

# --- CLI-1.3: --force and --dry-run combined (reports, writes nothing) -------
# A real-repo dry-run+force against temp HOME must exit 0 and write nothing
# under the managed subtree (no manifest created in dry-run).
FIX_HOME2="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR" "$FIX_HOME2"' EXIT
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$FIX_HOME2" --force --dry-run
assert_exit_zero "managed --force --dry-run exit 0" "$SYNC_RC"
assert_file_contains_str "force+dry-run: dry-run summary" "$OUT" "Dry-Run Summary"
assert_not_exists "force+dry-run: no manifest written" "$FIX_HOME2/.agents/skills/.manifest.json"

rm -f "$OUT"
sync_done
