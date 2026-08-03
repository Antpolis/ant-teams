#!/usr/bin/env bash
#
# test_sync_int_orphan.sh — SPEC-002 FR-6.1d / ERR-2.2: orphan preservation.
#
# Traceability:
#   - FR-6.1d a managed entry whose source no longer exists is preserved by
#     default and reported with a [SKIP orphan] WARNING (it is never deleted).
#   - ERR-2.2 a source skill recorded in the manifest but missing from source
#     becomes an orphan handled per FR-6.1d.
#   - ERR-5.2 orphans are never auto-deleted; cleanup is a manual operator act.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "FR-6.1d / ERR-2.2 orphan preservation"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha\n'
sync_write_skill "$FIX" "gone"  $'---\nname: gone\ndescription: g\n---\n\ngone\n'

# Run 1: install both.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"
assert_exists "gone installed initially" "$HOME_DIR/.agents/skills/gone/SKILL.md"
GONE_HASH="$(sync_sha256 "$HOME_DIR/.agents/skills/gone/SKILL.md")"

# Remove the "gone" source skill entirely.
rm -rf "$FIX/.opencode/skills/gone"

# Run 2: gone becomes an orphan => preserved + WARNING, alpha NOOP, exit 0.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 2 exit 0 (orphan non-fatal)" "$SYNC_RC"
assert_file_contains_str "orphan: SKIP orphan warning" "$OUT" "[SKIP orphan]"
assert_file_contains_str "orphan: reason named" "$OUT" "gone"

# ERR-5.2: orphan NOT deleted.
assert_exists "orphan: gone NOT deleted" "$HOME_DIR/.agents/skills/gone/SKILL.md"
assert_eq "orphan: gone content unchanged" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/gone/SKILL.md")" "$GONE_HASH"
# Orphan is carried forward in the manifest (still managed/trackable).
assert_eq "orphan: gone still recorded in manifest" \
  "$(sync_manifest_has_entry "$MANIFEST" gone)" "yes"
# alpha still NOOPs normally.
assert_file_contains_str "orphan: alpha NOOP" "$OUT" "[NOOP]"

rm -f "$OUT"
sync_done
