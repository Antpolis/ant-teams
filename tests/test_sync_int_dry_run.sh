#!/usr/bin/env bash
#
# test_sync_int_dry_run.sh — SPEC-002 TEST-2.7: --dry-run.
#
# Traceability:
#   - FR-9.1 dry-run computes actions and reports them without writing files.
#   - FR-9.2 action categories: [INSTALL]/[UPDATE]/[SKIP modified]/[SKIP orphan]/
#     [FORCE overwrite]/[SKIP collision]/[NOOP].
#   - FR-9.3 dry-run creates/modifies no manifest and no managed file.
#   - OBS-3.1 [DRY-RUN] prefix; OBS-3.1 dry-run summary header.
#   - OBS-3.2 entries that would be NOOP are [NOOP] in dry-run too.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.7 dry-run writes nothing"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha\n'
sync_write_command "$FIX" "do-thing" \
  $'description: d\nagent: orchestrator' $'body\n'

# Snapshot HOME/.agents BEFORE (only the seeded empty dir).
mkdir -p "$HOME_DIR/.agents/skills"
BEFORE="$(find "$HOME_DIR" -type f -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"

# Dry-run against a fresh (no manifest) state.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" --dry-run
assert_exit_zero "dry-run exit 0 (FR-9.4)" "$SYNC_RC"
assert_file_contains_str "dry-run: [DRY-RUN] prefix" "$OUT" "[DRY-RUN]"
assert_file_contains_str "dry-run: planned INSTALL reported" "$OUT" "[DRY-RUN] [INSTALL]"
assert_file_contains_str "dry-run: summary header" "$OUT" "Dry-Run Summary"

# FR-9.3: nothing written — manifest absent, no managed files, snapshot identical.
assert_not_exists "dry-run: no manifest created" "$MANIFEST"
assert_not_exists "dry-run: no alpha installed" "$HOME_DIR/.agents/skills/alpha"
AFTER="$(find "$HOME_DIR" -type f -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"
assert_eq "dry-run: HOME tree unchanged" "$AFTER" "$BEFORE"

# Now do a REAL install, then a dry-run re-run: everything is [NOOP] (OBS-3.2).
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "real install exit 0" "$SYNC_RC"
M_BEFORE="$(sha256sum "$MANIFEST" | cut -d' ' -f1)"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" --dry-run
assert_exit_zero "dry-run re-run exit 0" "$SYNC_RC"
assert_count      "dry-run re-run: NOOP for alpha" "$OUT" "[NOOP]" 2
# Manifest not modified by dry-run.
M_AFTER="$(sha256sum "$MANIFEST" | cut -d' ' -f1)"
assert_eq "dry-run re-run: manifest untouched" "$M_AFTER" "$M_BEFORE"

rm -f "$OUT"
sync_done
