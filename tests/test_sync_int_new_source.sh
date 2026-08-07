#!/usr/bin/env bash
#
# test_sync_int_new_source.sh — SPEC-002 TEST-2.4: new source entry.
#
# Traceability:
#   - FR-2.2 install all source entries; adding a new source installs it.
#   - FR-6.1a new entry installed without warning; existing entries NOOP.
#   - SEC-5.1 existing managed entries are not disturbed.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.4 new source entry"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha\n'

# Run 1: only alpha.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"
ALPHA1="$(sync_sha256 "$HOME_DIR/.agents/skills/alpha/SKILL.md")"
assert_eq "run 1: one entry" "$(sync_manifest_count_entries "$MANIFEST")" "1"

# Add a new source skill "newone".
sync_write_skill "$FIX" "newone" $'---\nname: newone\ndescription: n\n---\n\nnew\n'

# Run 2: newone installs; alpha NOOP and untouched.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 2 exit 0" "$SYNC_RC"
assert_file_contains_str "run 2: newone INSTALL" "$OUT" "[INSTALL] newone"
assert_count               "run 2: exactly one INSTALL" "$OUT" "[INSTALL]" 1
assert_count               "run 2: alpha NOOP" "$OUT" "[NOOP]" 1
assert_eq "run 2: two entries total" "$(sync_manifest_count_entries "$MANIFEST")" "2"

# Existing alpha untouched (byte-identical).
assert_eq "alpha untouched by new-entry install" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/alpha/SKILL.md")" "$ALPHA1"
assert_exists "newone installed" "$HOME_DIR/.agents/skills/newone/SKILL.md"

rm -f "$OUT"
sync_done
