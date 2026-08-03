#!/usr/bin/env bash
#
# test_sync_int_idempotent.sh — SPEC-002 TEST-2.2: idempotent re-run.
#
# Traceability:
#   - FR-10.1 second run with no source/target changes => no file writes beyond
#     manifest last_sync timestamp.
#   - FR-10.2 command-derived re-run produces bit-identical output.
#   - OBS-1.1 unchanged entries report [NOOP].
#   - TR-4.3 last_sync is the only field allowed to differ.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.2 idempotent re-run"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha body\n'
sync_write_command "$FIX" "do-thing" \
  $'description: do it\nagent: orchestrator' $'Run $ARGUMENTS now\n'

# Run 1: fresh install.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"

# Capture manifest WITHOUT last_sync + managed-tree snapshot after run 1.
# FR-10.1 allows the manifest last_sync to be rewritten on run 2, so the tree
# snapshot excludes .manifest.json (the manifest-only diff is asserted separately).
M_NO_TS_1="$(grep -v '"last_sync"' "$MANIFEST" | sha256sum | cut -d' ' -f1)"
SNAP1="$(find "$HOME_DIR/.agents/skills" -type f -not -name '.manifest.json' -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"

# Run 2: idempotent — nothing should change except the manifest timestamp line.
sleep 1  # ensure last_sync timestamp would differ if rewritten
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 2 exit 0" "$SYNC_RC"
assert_count      "run 2: all NOOP (alpha)" "$OUT" "[NOOP]" 2   # alpha + do-thing
assert_count      "run 2: no INSTALL" "$OUT" "[INSTALL]" 0
assert_count      "run 2: no UPDATE"  "$OUT" "[UPDATE]" 0

# Managed-tree file content snapshot identical (FR-10.1: no file writes; the
# manifest timestamp rewrite is excluded above).
SNAP2="$(find "$HOME_DIR/.agents/skills" -type f -not -name '.manifest.json' -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"
assert_eq "run 2: managed tree byte-identical" "$SNAP2" "$SNAP1"

# Manifest identical except last_sync (TR-4.3).
M_NO_TS_2="$(grep -v '"last_sync"' "$MANIFEST" | sha256sum | cut -d' ' -f1)"
assert_eq "run 2: manifest identical except last_sync" "$M_NO_TS_2" "$M_NO_TS_1"

rm -f "$OUT"
sync_done
