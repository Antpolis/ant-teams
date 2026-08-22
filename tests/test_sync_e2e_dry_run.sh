#!/usr/bin/env bash
#
# test_sync_e2e_dry_run.sh — SPEC-002 TEST-3.3: real managed-sync dry-run.
#
# Traceability:
#   - FR-9.1 scripts/sync-managed-skills.sh --dry-run computes all planned
#     actions and reports them WITHOUT writing any file.
#   - FR-9.3 no manifest, no managed file created/modified/deleted.
#   - AC-8.1 find ... -newer <before> returns nothing; manifest unchanged/absent.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-3.3 real managed-sync dry-run writes nothing"

HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR"' EXIT
OUT="$(mktemp)"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"

# Baseline: empty managed subtree (no manifest).
BEFORE="$(find "$HOME_DIR" -type f -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"

# Real managed dry-run against the real source tree.
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$HOME_DIR" --dry-run
assert_exit_zero "dry-run exit 0" "$SYNC_RC"
assert_file_contains_str "dry-run: [DRY-RUN] prefix" "$OUT" "[DRY-RUN]"
assert_file_contains_str "dry-run: dry-run summary" "$OUT" "Dry-Run Summary"

# FR-9.3 / AC-8.1: nothing written.
assert_not_exists "dry-run: no manifest" "$MANIFEST"
assert_not_exists "dry-run: no skills dir created" "$HOME_DIR/.agents/skills/agent-communication-log"
AFTER="$(find "$HOME_DIR" -type f -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)"
assert_eq "dry-run: HOME tree identical" "$AFTER" "$BEFORE"

# Dry-run reports every planned entry per-NAME (OBS-1.2 lists actions per-FILE),
# so the exact entry count is read from the summary line. The summary counts
# every source skill directory — including untracked empty placeholder dirs
# that yield no installable files — plus every command file. Compute the
# expectation with the same rule so the assertion stays machine-independent.
REAL_SKILLS="$(sync_count_dirs "$SYNC_REAL_OPENCODE/skills")"
REAL_CMDS="$(find "$SYNC_REAL_OPENCODE/commands" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')"
EXPECTED_TOTAL=$(( REAL_SKILLS + REAL_CMDS ))
assert_file_contains_str "dry-run: total managed entries in summary" "$OUT" "Total managed entries: $EXPECTED_TOTAL"
assert_gt "dry-run: per-file installs exceed entry count" \
  "$(grep -cF '[DRY-RUN] [INSTALL]' "$OUT" || true)" "$EXPECTED_TOTAL"

rm -f "$OUT"
sync_done
