#!/usr/bin/env bash
#
# test_sync_int_local_modification.sh — SPEC-002 TEST-2.5: local modification
# preservation (default run, no --force).
#
# Traceability:
#   - FR-5.1 a managed file whose current hash differs from the manifest hash
#     is locally modified.
#   - FR-6.1c default run preserves it, emits WARNING to stderr, leaves no
#     partially-modified state.
#   - FR-6.2 exit code 0 even when modifications were skipped with warnings.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.5 local modification preservation"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha original\n'
sync_write_skill "$FIX" "beta"  $'---\nname: beta\ndescription: b\n---\n\nbeta\n'

# Run 1: install.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"

# Locally modify the installed alpha (simulated operator edit).
printf 'alpha LOCAL EDIT\n' > "$HOME_DIR/.agents/skills/alpha/SKILL.md"
LOCAL_HASH="$(sync_sha256 "$HOME_DIR/.agents/skills/alpha/SKILL.md")"

# Run 2 (default, no --force): alpha preserved + WARNING, beta NOOP, exit 0.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 2 default exit 0 (FR-6.2)" "$SYNC_RC"
assert_file_contains_str "run 2: alpha SKIP modified" "$OUT" "[SKIP modified]"
assert_file_contains_str "run 2: WARNING emitted" "$OUT" "Locally modified managed file preserved"
assert_count               "run 2: beta NOOP" "$OUT" "[NOOP]" 1

# Content unchanged (preserved).
assert_eq "alpha preserved (local edit kept)" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/alpha/SKILL.md")" "$LOCAL_HASH"
assert_file_contains_str "alpha local edit still present" \
  "$HOME_DIR/.agents/skills/alpha/SKILL.md" "LOCAL EDIT"

rm -f "$OUT"
sync_done
