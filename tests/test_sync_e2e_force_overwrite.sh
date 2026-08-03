#!/usr/bin/env bash
#
# test_sync_e2e_force_overwrite.sh — SPEC-002 TEST-3.4: real force overwrite.
#
# Traceability:
#   - FR-8.1 --force overwrites a locally modified managed entry with current
#     source content and emits a [FORCE overwrite] notice.
#   - AC-5.1 after --force, the file hash matches the source.
#   - FR-8.4 manifest updated to the new content hashes.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-3.4 real force overwrite"

HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR"' EXIT
OUT="$(mktemp)"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
TARGET="$HOME_DIR/.agents/skills/documentation-standard/SKILL.md"
SRC="$SYNC_REAL_OPENCODE/skills/documentation-standard/SKILL.md"

# Run 1: full install.
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"
assert_exists "documentation-standard installed" "$TARGET"

# Locally modify the installed file.
printf '\n# local operator edit\n' >> "$TARGET"
assert_neq "local edit changed the file" \
  "$(sync_sha256 "$TARGET")" "$(sync_sha256 "$SRC")"

# Run 2 with --force: overwrite from source.
sync_capture "$OUT" "$SYNC_REAL_SCRIPT" "$HOME_DIR" --force
assert_exit_zero "run 2 --force exit 0" "$SYNC_RC"
assert_file_contains_str "force: [FORCE overwrite] notice" "$OUT" "[FORCE overwrite]"

# AC-5.1: installed file now matches source exactly.
assert_eq "force: installed == source" \
  "$(sync_sha256 "$TARGET")" "$(sync_sha256 "$SRC")"
# FR-8.4: manifest hash reflects source.
assert_eq "force: manifest hash == source" \
  "$(sync_manifest_file_hash "$MANIFEST" documentation-standard ".opencode/skills/documentation-standard/SKILL.md")" \
  "$(sync_sha256 "$SRC")"

rm -f "$OUT"
sync_done
