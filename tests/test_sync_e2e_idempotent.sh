#!/usr/bin/env bash
#
# test_sync_e2e_idempotent.sh — SPEC-002 TEST-3.2: real idempotent re-run.
#
# Traceability:
#   - FR-10.1 a second managed sync with no intervening changes writes nothing
#     beyond the manifest last_sync timestamp.
#   - AC-7.1 every managed entry reports [NOOP]; exit 0.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-3.2 real idempotent re-run"

HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR"' EXIT
OUT="$(mktemp)"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"

# Run 1: full managed install against temp HOME.
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"

# Snapshot the managed tree (files + hashes) EXCLUDING the manifest, since
# FR-10.1 permits the manifest last_sync to be rewritten on the idempotent run.
# The manifest-only diff (excluding last_sync) is asserted separately below.
SNAP1="$(find "$HOME_DIR/.agents/skills" -type f -not -name '.manifest.json' -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"
M_NOTS_1="$(grep -v '"last_sync"' "$MANIFEST" | sha256sum | cut -d' ' -f1)"

# Run 2: idempotent.
sleep 1
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$HOME_DIR"
assert_exit_zero "run 2 exit 0" "$SYNC_RC"

# AC-7.1: every entry NOOP. 38 entries => 38 [NOOP] lines.
assert_eq "run 2: 38 NOOP lines" "$(grep -cF '[NOOP]' "$OUT" || true)" "38"
assert_count "run 2: no INSTALL" "$OUT" "[INSTALL]" 0
assert_count "run 2: no UPDATE"  "$OUT" "[UPDATE]" 0
assert_count "run 2: no SKIP"    "$OUT" "[SKIP modified]" 0

# FR-10.1: managed tree byte-identical (manifest excluded — its timestamp may
# be rewritten on the idempotent run).
SNAP2="$(find "$HOME_DIR/.agents/skills" -type f -not -name '.manifest.json' -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"
assert_eq "run 2: managed tree identical" "$SNAP2" "$SNAP1"
# TR-4.3: manifest identical except last_sync.
M_NOTS_2="$(grep -v '"last_sync"' "$MANIFEST" | sha256sum | cut -d' ' -f1)"
assert_eq "run 2: manifest identical except last_sync" "$M_NOTS_2" "$M_NOTS_1"

rm -f "$OUT"
sync_done
